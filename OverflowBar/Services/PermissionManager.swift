import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class PermissionManager: ObservableObject {
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
        // Permission state can be stale when a local build replaces the
        // release identity. Calling CGRequestScreenCaptureAccess repeatedly
        // in that state reopens the macOS authorization sheet even when
        // System Settings still shows OverflowBar as allowed. A permission
        // button must only open the settings pane; capture itself remains
        // gated by the read-only preflight check in MenuBarCaptureService.
        refresh()
        guard !screenRecordingGranted else { return }
        openScreenRecordingSettings()
    }

    func openAccessibilitySettings() { open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") }
    func openScreenRecordingSettings() { open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") }

    private func open(_ url: String) { guard let url = URL(string: url) else { return }; NSWorkspace.shared.open(url) }
}
