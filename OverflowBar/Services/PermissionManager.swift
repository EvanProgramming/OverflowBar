import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

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
        refresh()
        guard !screenRecordingGranted else { return }
        SCShareableContent.getWithCompletionHandler { _, _ in
            Task { @MainActor in self.refresh() }
        }
    }

    func openAccessibilitySettings() { open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") }
    func openScreenRecordingSettings() { open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") }

    private func open(_ url: String) { guard let url = URL(string: url) else { return }; NSWorkspace.shared.open(url) }
}
