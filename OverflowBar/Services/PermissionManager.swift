import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit
import OSLog

@MainActor
final class PermissionManager: ObservableObject {
    private let logger = Logger(subsystem: "com.overflowbar.app", category: "permissions")
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var screenRecordingGranted = false

    init() { refresh() }

    func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    func requestAccessibility() {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        refresh()
    }

    func requestScreenRecording() {
        Task {
            // Enumerating shareable content is the supported macOS 15+ request
            // path and also registers this app in Privacy settings.
            _ = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            refresh()
            logger.info("Screen recording granted after request: \(self.screenRecordingGranted, privacy: .public)")
        }
    }

    func openAccessibilitySettings() { open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") }
    func openScreenRecordingSettings() { open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") }

    private func open(_ url: String) { guard let url = URL(string: url) else { return }; NSWorkspace.shared.open(url) }
}
