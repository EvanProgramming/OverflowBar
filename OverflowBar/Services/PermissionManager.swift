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
            // Explicitly ask WindowServer/TCC to register this bundle. Merely
            // enumerating SCShareableContent can return an empty result without
            // adding the app to the Screen Recording list on macOS 26.
            if !CGPreflightScreenCaptureAccess() {
                _ = CGRequestScreenCaptureAccess()
            }
            _ = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            refresh()
            logger.info("Screen recording granted after request: \(self.screenRecordingGranted, privacy: .public)")
        }
    }

    func openAccessibilitySettings() { open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") }
    func openScreenRecordingSettings() { open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") }

    private func open(_ url: String) { guard let url = URL(string: url) else { return }; NSWorkspace.shared.open(url) }
}
