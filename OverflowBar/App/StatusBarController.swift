import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let hiddenSectionItem: NSStatusItem
    private let store: MenuBarItemStore
    private let panelController: OverflowPanelController
    private let showSettings: () -> Void
    private var hoverMonitor: Any?
    private var pointerIsAtMenuBar = false

    init(store: MenuBarItemStore, showSettings: @escaping () -> Void) {
        let defaults = UserDefaults.standard
        let arrowName = "OverflowBarControlItem"
        let hiddenName = "OverflowBarHiddenSection"
        // Migrate any positions left by earlier builds. Position 0 is the
        // right-most app-owned slot; the expanding hidden delimiter is slot 1.
        defaults.set(0.0, forKey: "NSStatusItem Preferred Position \(arrowName)")
        defaults.set(1.0, forKey: "NSStatusItem Preferred Position \(hiddenName)")
        defaults.set(true, forKey: "NSStatusItem Visible \(arrowName)")
        defaults.set(true, forKey: "NSStatusItem Visible \(hiddenName)")
        statusItem = NSStatusBar.system.statusItem(withLength: 0)
        statusItem.autosaveName = arrowName
        hiddenSectionItem = NSStatusBar.system.statusItem(withLength: 0)
        hiddenSectionItem.autosaveName = hiddenName
        self.store = store
        self.showSettings = showSettings
        panelController = OverflowPanelController(store: store)
        super.init()
        store.onImagesReady = { [weak self] in
            guard let self else { return }
            self.updateHiddenSectionLength()
            // Do not synthesize Command-drag events during startup. Those
            // events alter WindowServer's global pointer state even when the
            // user has not interacted with OverflowBar. Layout is applied by
            // an explicit user action (or when onboarding is completed).
        }
        store.onLayoutStateChanged = { [weak self] in self?.updateHiddenSectionLength() }
        let button = statusItem.button
        statusItem.length = NSStatusItem.squareLength
        button?.image = Self.statusBarImage(isExpanded: false)
        button?.target = self
        button?.action = #selector(togglePanel)
        button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        hiddenSectionItem.button?.image = nil
        hiddenSectionItem.button?.cell?.isEnabled = false
        updateHiddenSectionLength()
        panelController.onVisibilityChanged = { [weak self] isVisible in
            self?.statusItem.button?.image = Self.statusBarImage(isExpanded: isVisible)
        }
        // Observe mouse movement without consuming or synthesizing events.
        // This removes the old 250ms polling interval plus 120ms debounce, so
        // the panel starts its animation on the first movement into the menu
        // bar while remaining passive for all other applications.
        hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.handleHoverPointer() }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            self.storeControlItemFrame(for: button)
            if ProcessInfo.processInfo.arguments.contains("--show-panel") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.panelController.show(relativeTo: button)
                }
            }
        }
    }

    deinit {
        if let hoverMonitor { NSEvent.removeMonitor(hoverMonitor) }
    }

    private func handleHoverPointer() {
        guard hoverRevealEnabled,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) else {
            pointerIsAtMenuBar = false
            return
        }
        let atMenuBar = NSEvent.mouseLocation.y >= screen.frame.maxY - NSStatusBar.system.thickness - 2
        guard atMenuBar != pointerIsAtMenuBar else { return }
        pointerIsAtMenuBar = atMenuBar
        guard atMenuBar, let button = statusItem.button else { return }
        storeControlItemFrame(for: button)
        panelController.show(relativeTo: button)
    }

    func prepareForTermination() { hiddenSectionItem.length = 0 }

    @objc private func togglePanel() {
        if NSApp.currentEvent?.type == .rightMouseUp { showSettings(); return }
        guard let button = statusItem.button else { return }
        storeControlItemFrame(for: button)
        panelController.toggle(relativeTo: button)
    }

    private func storeControlItemFrame(for button: NSStatusBarButton) {
        if let frame = button.overflowBarScreenFrame { store.updateControlItemFrame(frame) }
    }

    private func updateHiddenSectionLength() {
        guard store.isReadyForManagedLayout,
              store.layoutManagementEnabled,
              !store.selectedItems.isEmpty else {
            hiddenSectionItem.length = 0
            return
        }
        // Keep a bounded target window available for explicit layout actions.
        // The old 10,000pt surface was unnecessarily large and could dominate
        // menu-bar hit testing; 2,000pt is enough for current displays while
        // still giving WindowServer a stable off-screen destination.
        hiddenSectionItem.length = 2_000
    }

    private var hoverRevealEnabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "hoverRevealEnabled") == nil || defaults.bool(forKey: "hoverRevealEnabled")
    }

    private static func statusBarImage(isExpanded: Bool) -> NSImage? {
        guard let image = NSImage(
            systemSymbolName: isExpanded ? "chevron.up" : "chevron.down",
            accessibilityDescription: isExpanded ? "Hide OverflowBar" : "Show OverflowBar"
        ) else { return nil }
        image.isTemplate = true
        return image
    }
}

extension NSStatusBarButton {
    var overflowBarScreenFrame: CGRect? {
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        if let bounds = windows.first(where: {
            ($0[kCGWindowLayer as String] as? Int) == 25 &&
            ($0[kCGWindowName as String] as? String) == "OverflowBarControlItem"
        })?[kCGWindowBounds as String] as? [String: CGFloat] {
            let coreGraphicsFrame = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            let screen = NSScreen.screens.first(where: { $0.frame.minX <= coreGraphicsFrame.midX && $0.frame.maxX >= coreGraphicsFrame.midX }) ?? NSScreen.main
            if let screen {
                return CGRect(
                    x: coreGraphicsFrame.minX,
                    y: screen.frame.maxY - coreGraphicsFrame.maxY,
                    width: coreGraphicsFrame.width,
                    height: coreGraphicsFrame.height
                )
            }
        }
        guard let window else { return nil }
        return window.convertToScreen(convert(bounds, to: nil))
    }
}
