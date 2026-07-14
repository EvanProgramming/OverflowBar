import AppKit
import CoreGraphics
import ScreenCaptureKit
import OSLog

/// Captures a small, infrequently refreshed image for a menu bar item.
final class MenuBarCaptureService {
    private let logger = Logger(subsystem: "com.overflowbar.app", category: "capture")
    func capture(_ item: MenuBarItem) async -> NSImage? {
        guard CGPreflightScreenCaptureAccess() else {
            logger.info("Screen capture permission is not granted")
            return nil
        }
        guard
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(item.frame) }),
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }
        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return nil }
            let scale = screen.backingScaleFactor
            let configuration = SCStreamConfiguration()
            // CGWindow bounds and ScreenCaptureKit display source rectangles both
            // use a top-left origin and point units. Only output dimensions are pixels.
            configuration.sourceRect = CGRect(x: item.frame.minX - screen.frame.minX,
                                              y: item.frame.minY,
                                              width: item.frame.width,
                                              height: item.frame.height).integral
            configuration.width = max(1, Int(item.frame.width * scale))
            configuration.height = max(1, Int(item.frame.height * scale))
            configuration.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(display: display, excludingWindows: []), configuration: configuration)
            return NSImage(cgImage: image, size: item.frame.size)
        } catch {
            logger.error("Capture failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
