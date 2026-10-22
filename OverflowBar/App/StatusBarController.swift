import AppKit

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var dividerItem: NSStatusItem
    private let store: MenuBarItemStore
    private let panelController: OverflowPanelController
    private let showSettings: () -> Void
    private var compactDividerFrame: CGRect?
    private var hoverTimer: Timer?
    private var hoverRevealState = MenuBarHoverRevealState()
    private var screenObserver: NSObjectProtocol?

    init(store: MenuBarItemStore, showSettings: @escaping () -> Void) {
        self.store = store
        self.showSettings = showSettings
        // Build SwiftUI first so status-host configuration remains contiguous.
        panelController = OverflowPanelController(store: store)
        let defaults = UserDefaults.standard
        let controlKey = "NSStatusItem Preferred Position OverflowBarControlItem"
        let dividerKey = "NSStatusItem Preferred Position OverflowBarHiddenSection"
        let control = defaults.object(forKey: controlKey) as? Double
        let divider = defaults.object(forKey: dividerKey) as? Double
        if control == nil || divider == nil || !control!.isFinite || !divider!.isFinite || control! < 0 || divider! <= control! || divider! > 4000 {
            defaults.set(0.0, forKey: controlKey)
            defaults.set(1.0, forKey: dividerKey)
        }
        for name in ["OverflowBarControlItem", "OverflowBarHiddenSection"] {
            defaults.set(true, forKey: "NSStatusItem Visible \(name)")
            defaults.set(true, forKey: "NSStatusItem VisibleCC \(name)")
        }
        statusItem = NSStatusBar.system.statusItem(withLength: max(NSStatusBar.system.thickness, 18))
        statusItem.autosaveName = "OverflowBarControlItem"
        statusItem.button?.image = Self.symbol("chevron.down", label: "Show OverflowBar")
        statusItem.button?.setAccessibilityIdentifier("OverflowBarControlItem")
        dividerItem = NSStatusBar.system.statusItem(withLength: 20)
        dividerItem.autosaveName = "OverflowBarHiddenSection"
        dividerItem.button?.image = Self.symbol("line.3.vertical", label: "Hide or reveal the grouped icons")
        dividerItem.button?.setAccessibilityIdentifier("OverflowBarHiddenSection")
        super.init()

        configureControlActions()
        store.onControlsRecoveryRequested = { [weak self] in self?.recoverControls() }
        store.onShowPanelRequested = { [weak self] in self?.showPanel() }
        store.onLayoutStateChanged = { [weak self] in self?.updateDivider() }
        panelController.onVisibilityChanged = { [weak self] visible in
            self?.statusItem.button?.image = Self.symbol(visible ? "chevron.up" : "chevron.down", label: visible ? "Hide OverflowBar" : "Show OverflowBar")
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in DispatchQueue.main.async {
            self?.compactDividerFrame = nil
            self?.updateDivider()
            self?.publishStatusItemWindowIDs()
        } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.updateDivider()
            if !self.controlWindowsExist { self.recoverControls() }
            self.publishStatusItemWindowIDs()
            if ProcessInfo.processInfo.arguments.contains("--show-panel"), let button = self.statusItem.button {
                self.panelController.show(relativeTo: button)
            }
        }
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateHoverReveal() }
        }
    }

    private func configureControlActions() {
        statusItem.isVisible = true; dividerItem.isVisible = true
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.setAccessibilityLabel("Show OverflowBar")
        statusItem.button?.setAccessibilityIdentifier("OverflowBarControlItem")
        dividerItem.button?.target = self
        dividerItem.button?.action = #selector(toggleGroup)
        dividerItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        dividerItem.button?.setAccessibilityLabel("Hide or reveal grouped menu bar icons")
        dividerItem.button?.setAccessibilityIdentifier("OverflowBarHiddenSection")

    }

    private var controlWindowsExist: Bool {
        let rows = NativeWindowBridge.statusWindows()
        return ["OverflowBarControlItem", "OverflowBarHiddenSection"].allSatisfy { name in
            rows.contains { row in
                guard row[kCGWindowName as String] as? String == name, let frame = NativeWindowBridge.bounds(row) else { return false }
                return frame.width > 0 && frame.height > 0 && frame.height <= 40
            }
        }
    }

    private func recoverControls() {
        // A missing host has no sane realized placement to preserve. Dispose it before clearing its autosave slot.
        NSStatusBar.system.removeStatusItem(statusItem)
        NSStatusBar.system.removeStatusItem(dividerItem)
        for name in ["OverflowBarControlItem", "OverflowBarHiddenSection"] {
            UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position \(name)")
            UserDefaults.standard.set(true, forKey: "NSStatusItem Visible \(name)")
            UserDefaults.standard.set(true, forKey: "NSStatusItem VisibleCC \(name)")
        }
        statusItem = NSStatusBar.system.statusItem(withLength: 1)
        statusItem.autosaveName = "OverflowBarControlItem"
        statusItem.button?.image = Self.symbol("chevron.down", label: "Show OverflowBar")
        statusItem.button?.setAccessibilityIdentifier("OverflowBarControlItem")
        statusItem.length = max(NSStatusBar.system.thickness, 18)
        dividerItem = NSStatusBar.system.statusItem(withLength: 1)
        dividerItem.autosaveName = "OverflowBarHiddenSection"
        dividerItem.button?.image = Self.symbol("line.3.vertical", label: "Hide or reveal the grouped icons")
        dividerItem.button?.setAccessibilityIdentifier("OverflowBarHiddenSection")
        dividerItem.length = 20
        configureControlActions()
        compactDividerFrame = nil
        store.cancelOperation()
        publishStatusItemWindowIDs()
    }

    func prepareForTermination() { hoverTimer?.invalidate(); hoverTimer = nil; store.prepareForTermination {}; dividerItem.length = 20 }

    func showPanel() { if let button = statusItem.button { panelController.show(relativeTo: button) } }

    @objc private func togglePanel() {
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true { store.revealOriginals(); return }
        if NSApp.currentEvent?.type == .rightMouseUp { showSettings(); return }
        guard let button = statusItem.button else { return }
        panelController.toggle(relativeTo: button)
        if store.preferencesExplanationPending { store.showManualGroupingExplanation() }
    }

    @objc private func toggleGroup() { store.setLayoutManagementEnabled(!store.groupHidden) }

    private func updateDivider() {
        let osMajorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        if !MenuBarGroupGeometry.supportsHiding(osMajorVersion: osMajorVersion) {
            store.setLayoutManagementEnabled(false)
        }
        dividerItem.length = store.groupHidden ? 10_000 : 20
        if !store.groupHidden {
            compactDividerFrame = store.nativeControlFrame("OverflowBarHiddenSection")
            store.updateDividerFrame(compactDividerFrame)
        }
    }

    private func publishStatusItemWindowIDs() { store.refresh() }

    private func updateHoverReveal() {
        let mouseLocation = NSEvent.mouseLocation
        let pointerInMenuBar = NSScreen.screens.contains { screen in
            screen.frame.contains(mouseLocation) && mouseLocation.y >= screen.frame.maxY - NSStatusBar.system.thickness - 2
        }
        guard hoverRevealState.shouldReveal(
                enabled: UserDefaults.standard.bool(forKey: "hoverRevealEnabled"),
                pointerInMenuBar: pointerInMenuBar,
                operationInProgress: store.nativeOperationInProgress
              ),
              let button = statusItem.button else { return }
        panelController.show(relativeTo: button, takeKeyboardFocus: false)
    }

    private static func symbol(_ name: String, label: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label)
        image?.isTemplate = true
        return image
    }

    deinit {
        hoverTimer?.invalidate()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }
}

struct MenuBarHoverRevealState {
    private var pointerWasInMenuBar = false

    mutating func shouldReveal(enabled: Bool, pointerInMenuBar: Bool, operationInProgress: Bool) -> Bool {
        guard enabled else { pointerWasInMenuBar = false; return false }
        let enteredMenuBar = pointerInMenuBar && !pointerWasInMenuBar
        pointerWasInMenuBar = pointerInMenuBar
        return enteredMenuBar && !operationInProgress
    }
}

extension NSStatusBarButton {
    var overflowBarScreenFrame: CGRect? { overflowBarScreenFrame(title: "OverflowBarControlItem") }

    func overflowBarScreenFrame(title: String) -> CGRect? {
        if let window {
            let frame = window.convertToScreen(convert(bounds, to: nil))
            if frame.width > 0, frame.height > 0,
               NSScreen.screens.contains(where: { $0.frame.insetBy(dx: -2, dy: -2).contains(CGPoint(x: frame.maxX - 1, y: frame.midY)) }) { return frame }
        }
        let axFrame = accessibilityFrame()
        if axFrame.width > 0, axFrame.height > 0,
           NSScreen.screens.contains(where: { $0.frame.insetBy(dx: -2, dy: -2).contains(CGPoint(x: axFrame.maxX - 1, y: axFrame.midY)) }) { return axFrame }
        return nil
    }
}
