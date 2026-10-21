import AppKit
import Carbon
import ApplicationServices
import OSLog
import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = MenuBarItemStore()
    private let permissions = PermissionManager()
    private let preferences = PreferencesStore()
    private var statusBarController: StatusBarController?
    private var settingsWindowController: NSWindowController?
    private var onboardingWindowController: NSWindowController?
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger(subsystem: "com.overflowbar.app", category: "startup").info("Accessibility trusted: \(AXIsProcessTrusted(), privacy: .public)")
        let testing = NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !testing { updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil) }
        NSApp.setActivationPolicy(.accessory)
        // Hosted tests must not register controls under the installed app's autosave identities.
        if testing { return }
        statusBarController = StatusBarController(store: store, showSettings: { [weak self] in self?.showSettings() })
        store.startMonitoring()
        if preferences.hasCompletedOnboarding {
            store.refresh()
            let loginLaunch = NSAppleEventManager.shared().currentAppleEvent?.paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem)) != nil
            if !loginLaunch { DispatchQueue.main.async { [weak self] in self?.showSettings() } }
        } else {
            DispatchQueue.main.async { [weak self] in self?.showOnboarding() }
        }
        if ProcessInfo.processInfo.arguments.contains("--show-settings") {
            DispatchQueue.main.async { [weak self] in self?.showSettings() }
        } else if ProcessInfo.processInfo.arguments.contains("--show-onboarding") {
            DispatchQueue.main.async { [weak self] in self?.showOnboarding() }
        }
    }

    func showSettings() {
        if let settingsWindowController { settingsWindowController.showWindow(nil) }
        else {
            let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 680, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "OverflowBar Settings"
            window.contentView = NSHostingView(rootView: SettingsView(store: store, showOnboarding: { [weak self] in
                self?.showOnboarding()
            }, checkForUpdates: { [weak self] in
                self?.checkForUpdates()
            }))
            window.center()
            let controller = NSWindowController(window: window)
            settingsWindowController = controller
            controller.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
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
                onComplete: { [weak self] hideSelectedIcons in self?.completeOnboarding(hideSelectedIcons: hideSelectedIcons) }
            ))
            window.center()
            let controller = NSWindowController(window: window)
            onboardingWindowController = controller
            controller.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func completeOnboarding(hideSelectedIcons: Bool) {
        preferences.hasCompletedOnboarding = true
        store.refresh()
        store.setLayoutManagementEnabled(false)
        showSettings()
        onboardingWindowController?.close()
        onboardingWindowController = nil
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        statusBarController?.prepareForTermination()
        return .terminateNow
    }
}
