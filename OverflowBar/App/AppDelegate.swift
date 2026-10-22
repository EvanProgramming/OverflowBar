import AppKit
import Carbon
import ApplicationServices
import OSLog
import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = MenuBarItemStore()
    let permissions = PermissionManager()
    private let preferences = PreferencesStore()
    let settingsNavigation = SettingsNavigation()
    private var statusBarController: StatusBarController?
    private var settingsWindowController: NSWindowController?
    private var onboardingWindowController: NSWindowController?
    private var updaterController: SPUStandardUpdaterController?
    private var activationObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger(subsystem: "com.overflowbar.app", category: "startup").info("Accessibility trusted: \(AXIsProcessTrusted(), privacy: .public)")
        let testing = NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !testing { updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil) }
        activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.permissions.refresh() }
        }
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

    func showSettings(section: SettingsSection = .menuBar) {
        settingsNavigation.selection = section
        if let settingsWindowController { settingsWindowController.showWindow(nil) }
        else {
            let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 820, height: 580), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "OverflowBar Settings"
            window.contentView = NSHostingView(rootView: SettingsView(store: store, permissions: permissions, navigation: settingsNavigation, showOnboarding: { [weak self] in
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
            window.contentMinSize = .init(width: 760, height: 540)
            window.contentView = NSHostingView(rootView: OnboardingView(
                store: store,
                permissions: permissions,
                onComplete: { [weak self] completion in self?.completeOnboarding(completion) }
            ))
            window.center()
            let controller = NSWindowController(window: window)
            onboardingWindowController = controller
            controller.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func completeOnboarding(_ completion: OnboardingCompletion) {
        completion.apply(to: store)
        preferences.hasCompletedOnboarding = true
        store.refresh()
        showSettings()
        onboardingWindowController?.close()
        onboardingWindowController = nil
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        statusBarController?.prepareForTermination()
        return .terminateNow
    }

    deinit {
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
    }
}
