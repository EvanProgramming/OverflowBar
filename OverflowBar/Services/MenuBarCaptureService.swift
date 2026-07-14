import AppKit
import CoreGraphics
import Darwin
import OSLog

/// Captures all managed status-item windows in one WindowServer image, then
/// splits that image by each live window ID. This mirrors Ice's image cache and
/// remains correct when items have been moved offscreen.
final class MenuBarCaptureService {
    private let logger = Logger(subsystem: "com.overflowbar.app", category: "capture")

    func capture(_ items: [MenuBarItem]) async -> [String: NSImage] {
        guard Self.hasScreenCapturePermission() else {
            logger.info("Screen capture permission is not granted")
            return [:]
        }
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2 }
        let statusBarThickness = await MainActor.run { NSStatusBar.system.thickness }

        return await Task.detached(priority: .utility) {
            let currentFrames = Self.currentFrames()
            let capturedItems = items.compactMap { item -> (String, CGWindowID, CGRect)? in
                guard let windowID = item.windowID, let frame = currentFrames[windowID] else { return nil }
                return (item.id, windowID, frame)
            }
            guard !capturedItems.isEmpty else { return [:] }

            let unionFrame = capturedItems.reduce(CGRect.null) { $0.union($1.2) }
            guard let composite = Self.captureWindows(capturedItems.map(\.1)) else { return [:] }
            let compositeBounds = CGRect(x: 0, y: 0, width: composite.width, height: composite.height)

            var result: [String: NSImage] = [:]
            for (id, _, frame) in capturedItems {
                let crop = CGRect(
                    x: (frame.minX - unionFrame.minX) * scale,
                    y: (frame.minY - unionFrame.minY) * scale,
                    width: frame.width * scale,
                    height: frame.height * scale
                ).integral.intersection(compositeBounds)
                guard !crop.isNull, let itemImage = composite.cropping(to: crop) else { continue }
                let desiredHeight = min(CGFloat(itemImage.height), statusBarThickness * scale)
                let centeredCrop = CGRect(
                    x: 0,
                    y: (CGFloat(itemImage.height) - desiredHeight) / 2,
                    width: CGFloat(itemImage.width),
                    height: desiredHeight
                ).integral
                guard let cropped = itemImage.cropping(to: centeredCrop) else { continue }
                result[id] = NSImage(
                    cgImage: cropped,
                    size: CGSize(width: CGFloat(cropped.width) / scale, height: CGFloat(cropped.height) / scale)
                )
            }
            return result
        }.value
    }

    private static func hasScreenCapturePermission() -> Bool {
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

    private static func currentFrames() -> [CGWindowID: CGRect] {
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.reduce(into: [:]) { result, info in
            guard let id = info[kCGWindowNumber as String] as? Int,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return }
            result[CGWindowID(id)] = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
        }
    }

    private static func captureWindows(_ windowIDs: [CGWindowID]) -> CGImage? {
        var rawWindows = windowIDs.map { UnsafeRawPointer(bitPattern: UInt($0)) }
        let windowArray = rawWindows.withUnsafeMutableBufferPointer { buffer in
            CFArrayCreate(kCFAllocatorDefault, buffer.baseAddress, buffer.count, nil)
        }
        guard let windowArray else { return nil }

        typealias CaptureFunction = @convention(c) (CGRect, CFArray, UInt32) -> Unmanaged<CGImage>?
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImageFromArray") else { return nil }
        let capture = unsafeBitCast(symbol, to: CaptureFunction.self)
        let options: CGWindowImageOption = [.boundsIgnoreFraming, .bestResolution]
        return capture(.null, windowArray, options.rawValue)?.takeRetainedValue()
    }
}
