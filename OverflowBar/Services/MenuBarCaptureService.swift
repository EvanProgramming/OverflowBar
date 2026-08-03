import AppKit
import CoreGraphics
import OSLog
import ScreenCaptureKit

/// Captures status-item windows using ScreenCaptureKit when possible, with a
/// narrowly scoped Core Graphics compatibility path for offscreen menu items.
@MainActor
final class MenuBarCaptureService {
    private struct WindowSnapshot: Sendable {
        let itemID: String
        let windowID: CGWindowID
    }

    private let logger = Logger(subsystem: "com.overflowbar.app", category: "capture")

    func capture(_ items: [MenuBarItem]) async -> [String: NSImage] {
        guard CGPreflightScreenCaptureAccess() else {
            logger.info("Screen capture permission is not granted")
            return [:]
        }

        let snapshots = items.compactMap { item in
            item.windowID.map { WindowSnapshot(itemID: item.id, windowID: $0) }
        }
        guard !snapshots.isEmpty else { return [:] }

        var images = await captureWithScreenCaptureKit(snapshots)
        let missing = snapshots.filter { images[$0.itemID] == nil }

        if !missing.isEmpty {
            // ScreenCaptureKit currently rejects offscreen layer-25 status item
            // windows on macOS 26. The SDK-declared legacy window-list capture
            // remains the only working compatibility path for those windows.
            logger.info("Using offscreen compatibility capture for \(missing.count, privacy: .public) items")
            let fallback = await Task.detached(priority: .utility) {
                Self.captureWithWindowList(missing)
            }.value
            images.merge(fallback) { _, new in new }
        }

        logger.info("Captured \(images.count, privacy: .public) of \(snapshots.count, privacy: .public) menu bar icons")
        return images
    }

    private func captureWithScreenCaptureKit(_ snapshots: [WindowSnapshot]) async -> [String: NSImage] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            let windowsByID = Dictionary(uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) })
            var result: [String: NSImage] = [:]

            for snapshot in snapshots {
                guard !Task.isCancelled, let window = windowsByID[snapshot.windowID] else { continue }
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let scale = max(CGFloat(filter.pointPixelScale), 1)
                let contentRect = filter.contentRect
                guard contentRect.width > 0, contentRect.height > 0 else { continue }

                let configuration = SCStreamConfiguration()
                configuration.width = max(1, Int((contentRect.width * scale).rounded(.up)))
                configuration.height = max(1, Int((contentRect.height * scale).rounded(.up)))
                configuration.showsCursor = false
                configuration.ignoreShadowsSingleWindow = true

                do {
                    let image = try await SCScreenshotManager.captureImage(
                        contentFilter: filter,
                        configuration: configuration
                    )
                    if Self.hasVisibleContent(image) {
                        result[snapshot.itemID] = NSImage(
                            cgImage: image,
                            size: CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
                        )
                    } else {
                        logger.info("Captured a blank status window \(snapshot.windowID, privacy: .public); trying compatibility capture")
                    }
                } catch {
                    logger.info("ScreenCaptureKit could not capture status window \(snapshot.windowID, privacy: .public); switching to compatibility capture")
                    continue
                }
            }
            return result
        } catch {
            logger.error("Unable to enumerate shareable content: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    private nonisolated static func captureWithWindowList(_ snapshots: [WindowSnapshot]) -> [String: NSImage] {
        var result: [String: NSImage] = [:]
        for snapshot in snapshots {
            guard let image = legacyWindowImage(ids: [snapshot.windowID]), hasVisibleContent(image) else { continue }
            result[snapshot.itemID] = NSImage(
                cgImage: image,
                size: CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
            )
        }
        return result
    }

    /// Rejects fully transparent or uniform captures, which ScreenCaptureKit
    /// can transiently return while login items are still creating their
    /// status windows.
    private nonisolated static func hasVisibleContent(_ image: CGImage) -> Bool {
        let width = 16
        let height = 16
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minimumAlpha = UInt8.max
        var maximumAlpha = UInt8.min
        var minimumLuma = UInt8.max
        var maximumLuma = UInt8.min
        var brightOpaquePixels = 0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            let alpha = pixels[offset + 3]
            let luma = UInt8((red * 54 + green * 183 + blue * 19) / 256)
            minimumAlpha = min(minimumAlpha, alpha)
            maximumAlpha = max(maximumAlpha, alpha)
            minimumLuma = min(minimumLuma, luma)
            maximumLuma = max(maximumLuma, luma)
            if alpha > 220 && luma > 245 { brightOpaquePixels += 1 }
        }
        return maximumAlpha > 8 &&
            brightOpaquePixels < (width * height * 85 / 100) &&
            (Int(maximumAlpha) - Int(minimumAlpha) > 6 || Int(maximumLuma) - Int(minimumLuma) > 6)
    }

    private nonisolated static func legacyWindowImage(ids: [CGWindowID]) -> CGImage? {
        var pointers = ids.map { UnsafeRawPointer(bitPattern: UInt($0)) }
        return pointers.withUnsafeMutableBufferPointer { buffer in
            guard let array = CFArrayCreate(kCFAllocatorDefault, buffer.baseAddress, buffer.count, nil) else { return nil }
            return OverflowBarCreateWindowListImage(
                .null,
                array,
                [.boundsIgnoreFraming, .bestResolution]
            )?.takeRetainedValue()
        }
    }
}

/// The public SDK declaration was marked unavailable in macOS 15 even though
/// WindowServer still exports it. Keeping the compatibility shim in one place
/// lets the main capture path remain on ScreenCaptureKit.
@_silgen_name("CGWindowListCreateImageFromArray")
private func OverflowBarCreateWindowListImage(
    _ bounds: CGRect,
    _ windows: CFArray,
    _ options: CGWindowImageOption
) -> Unmanaged<CGImage>?
