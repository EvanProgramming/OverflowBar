import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Captures a small, infrequently refreshed image for a menu bar item.
final class MenuBarCaptureService {
    func capture(_ item: MenuBarItem) async -> NSImage? {
        guard CGPreflightScreenCaptureAccess(),
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(item.frame) }),
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }
        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return nil }
            let scale = screen.backingScaleFactor
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = CGRect(x: (item.frame.minX - screen.frame.minX) * scale,
                                              y: (screen.frame.maxY - item.frame.maxY) * scale,
                                              width: item.frame.width * scale,
                                              height: item.frame.height * scale).integral
            configuration.width = Int(configuration.sourceRect.width)
            configuration.height = Int(configuration.sourceRect.height)
            configuration.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(display: display, excludingWindows: []), configuration: configuration)
            return NSImage(cgImage: image, size: item.frame.size)
        } catch { return nil }
    }
}
