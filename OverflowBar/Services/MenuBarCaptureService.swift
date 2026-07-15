import AppKit
import CoreGraphics
import OSLog
import ScreenCaptureKit

/// Captures managed status-item windows with the public ScreenCaptureKit
/// screenshot API. Desktop-independent window filters continue to work for
/// status items that OverflowBar has moved outside the visible menu bar.
final class MenuBarCaptureService {
    private let logger = Logger(subsystem: "com.overflowbar.app", category: "capture")

    func capture(_ items: [MenuBarItem]) async -> [String: NSImage] {
        guard CGPreflightScreenCaptureAccess() else {
            logger.info("Screen capture permission is not granted")
            return [:]
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            let windowsByID = Dictionary(uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) })
            var result: [String: NSImage] = [:]

            for item in items {
                guard !Task.isCancelled,
                      let windowID = item.windowID,
                      let window = windowsByID[windowID] else { continue }
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
                    result[item.id] = NSImage(
                        cgImage: image,
                        size: CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
                    )
                } catch {
                    logger.error("Unable to capture window \(windowID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            return result
        } catch {
            logger.error("Unable to enumerate shareable content: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }
}
