import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = MenuBarItemStore()
    private let permissions = PermissionManager()
    private var statusBarController: StatusBarController?
    private var settingsWindowController: NSWindowController?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(store: store, showSettings: { [weak self] in self?.showSettings() })
        store.refresh()
        if !permissions.accessibilityGranted {
            permissions.requestAccessibility()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                Task { @MainActor in
                    guard let self else { timer.invalidate(); return }
                    self.permissions.refresh()
                    guard self.permissions.accessibilityGranted else { return }
                    timer.invalidate()
                    self.permissionTimer = nil
                    self.store.refresh()
                    self.store.applyLayout()
                }
            }
        }
    }

    private func showSettings() {
        if let settingsWindowController { settingsWindowController.showWindow(nil) }
        else {
            let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 680, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "OverflowBar Settings"
            window.contentView = NSHostingView(rootView: SettingsView(store: store))
            window.center()
            let controller = NSWindowController(window: window)
            settingsWindowController = controller
            controller.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
