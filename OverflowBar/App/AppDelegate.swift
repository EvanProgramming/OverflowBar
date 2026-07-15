import AppKit
import ApplicationServices
import OSLog
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = MenuBarItemStore()
    private let permissions = PermissionManager()
    private let preferences = PreferencesStore()
    private var statusBarController: StatusBarController?
    private var settingsWindowController: NSWindowController?
    private var onboardingWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger(subsystem: "com.overflowbar.app", category: "startup").info("Accessibility trusted: \(AXIsProcessTrusted(), privacy: .public)")
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(store: store, showSettings: { [weak self] in self?.showSettings() })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.store.restoreProtectedSystemItems()
        }
        if preferences.hasCompletedOnboarding {
            store.refresh()
        } else {
            DispatchQueue.main.async { [weak self] in self?.showOnboarding() }
        }
    }

    private func showSettings() {
        if let settingsWindowController { settingsWindowController.showWindow(nil) }
        else {
            let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 680, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "OverflowBar Settings"
            window.contentView = NSHostingView(rootView: SettingsView(store: store, showOnboarding: { [weak self] in
                self?.showOnboarding()
            }))
            window.center()
            let controller = NSWindowController(window: window)
            settingsWindowController = controller
            controller.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func showOnboarding() {
        if let onboardingWindowController {
            onboardingWindowController.showWindow(nil)
        } else {
            let window = NSWindow(
                contentRect: .init(x: 0, y: 0, width: 760, height: 560),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to OverflowBar"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.contentMinSize = .init(width: 680, height: 500)
            window.contentView = NSHostingView(rootView: OnboardingView(
                store: store,
                permissions: permissions,
                onComplete: { [weak self] in self?.completeOnboarding() }
            ))
            window.center()
            let controller = NSWindowController(window: window)
            onboardingWindowController = controller
            controller.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func completeOnboarding() {
        preferences.hasCompletedOnboarding = true
        store.refresh()
        onboardingWindowController?.close()
        onboardingWindowController = nil
    }
}
