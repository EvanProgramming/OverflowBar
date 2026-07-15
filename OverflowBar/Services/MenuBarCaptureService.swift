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
        guard hasScreenCapturePermission() else {
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
                    result[snapshot.itemID] = NSImage(
                        cgImage: image,
                        size: CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
                    )
                } catch {
                    logger.info("ScreenCaptureKit could not capture status window \(snapshot.windowID, privacy: .public); switching to compatibility capture")
                    break
                }
            }
            return result
        } catch {
            logger.error("Unable to enumerate shareable content: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    private func hasScreenCapturePermission() -> Bool {
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        if windows.contains(where: {
            ($0[kCGWindowLayer as String] as? Int) == 25 &&
                ($0[kCGWindowOwnerPID as String] as? Int) != Int(getpid()) &&
                !(($0[kCGWindowName as String] as? String) ?? "").isEmpty
        }) {
            return true
        }
        return CGPreflightScreenCaptureAccess()
    }

    private nonisolated static func captureWithWindowList(_ snapshots: [WindowSnapshot]) -> [String: NSImage] {
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        let frames: [CGWindowID: CGRect] = windows.reduce(into: [:]) { result, info in
            guard let number = info[kCGWindowNumber as String] as? Int,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return }
            result[CGWindowID(number)] = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
        }
        let available = snapshots.compactMap { snapshot -> (WindowSnapshot, CGRect)? in
            frames[snapshot.windowID].map { (snapshot, $0) }
        }
        guard !available.isEmpty else { return [:] }

        let union = available.reduce(CGRect.null) { $0.union($1.1) }
        guard !union.isNull,
              let composite = legacyWindowImage(ids: available.map { $0.0.windowID }) else { return [:] }

        let scale = max(1, CGFloat(composite.width) / union.width)
        let imageBounds = CGRect(x: 0, y: 0, width: composite.width, height: composite.height)
        var result: [String: NSImage] = [:]

        for (snapshot, frame) in available {
            let crop = CGRect(
                x: (frame.minX - union.minX) * scale,
                y: (frame.minY - union.minY) * scale,
                width: frame.width * scale,
                height: frame.height * scale
            ).integral.intersection(imageBounds)
            guard !crop.isNull, crop.width > 0, crop.height > 0,
                  let image = composite.cropping(to: crop) else { continue }
            result[snapshot.itemID] = NSImage(
                cgImage: image,
                size: CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
            )
        }
        return result
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
