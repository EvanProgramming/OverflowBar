import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let hiddenSectionItem: NSStatusItem
    private let store: MenuBarItemStore
    private let panelController: OverflowPanelController
    private let showSettings: () -> Void
    private var mouseMonitor: Any?
    private var hoverWorkItem: DispatchWorkItem?
    private var didApplyInitialLayout = false

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
            if !self.didApplyInitialLayout {
                self.didApplyInitialLayout = true
                if self.store.layoutManagementEnabled { self.store.applyLayout() }
            }
        }
        store.onLayoutStateChanged = { [weak self] in self?.updateHiddenSectionLength() }
        let button = statusItem.button
        statusItem.length = NSStatusItem.squareLength
        button?.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Show OverflowBar")
        button?.target = self
        button?.action = #selector(togglePanel)
        button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        hiddenSectionItem.button?.image = nil
        hiddenSectionItem.button?.cell?.isEnabled = false
        updateHiddenSectionLength()
        panelController.onVisibilityChanged = { [weak self] isVisible in
            self?.statusItem.button?.image = NSImage(systemSymbolName: isVisible ? "chevron.up" : "chevron.down", accessibilityDescription: isVisible ? "Hide OverflowBar" : "Show OverflowBar")
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self else { return }
            guard self.hoverRevealEnabled,
                  let screen = NSScreen.screens.first(where: { $0.frame.contains(event.locationInWindow) }),
                  event.locationInWindow.y >= screen.frame.maxY - NSStatusBar.system.thickness - 2,
                  let button = self.statusItem.button else {
                self.hoverWorkItem?.cancel()
                self.hoverWorkItem = nil
                return
            }
            guard self.hoverWorkItem == nil else { return }
            let workItem = DispatchWorkItem { [weak self, weak button] in
                guard let self, let button else { return }
                self.hoverWorkItem = nil
                self.storeControlItemFrame(for: button)
                self.panelController.show(relativeTo: button)
            }
            self.hoverWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
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
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        hoverWorkItem?.cancel()
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
        hiddenSectionItem.length = store.isReadyForManagedLayout && store.layoutManagementEnabled && !store.selectedItems.isEmpty ? 10_000 : 0
    }

    private var hoverRevealEnabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "hoverRevealEnabled") == nil || defaults.bool(forKey: "hoverRevealEnabled")
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
