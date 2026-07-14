import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let store: MenuBarItemStore
    private let panelController: OverflowPanelController
    private let showSettings: () -> Void

    init(store: MenuBarItemStore, showSettings: @escaping () -> Void) {
        self.store = store
        self.showSettings = showSettings
        panelController = OverflowPanelController(store: store)
        super.init()
        let button = statusItem.button
        statusItem.autosaveName = "OverflowBarControlItem"
        button?.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Show OverflowBar")
        button?.target = self
        button?.action = #selector(togglePanel)
        button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        panelController.onVisibilityChanged = { [weak self] isVisible in
            self?.statusItem.button?.image = NSImage(systemSymbolName: isVisible ? "chevron.up" : "chevron.down", accessibilityDescription: isVisible ? "Hide OverflowBar" : "Show OverflowBar")
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            self.storeControlItemFrame(for: button)
        }
    }

    @objc private func togglePanel() {
        if NSApp.currentEvent?.type == .rightMouseUp { showSettings(); return }
        guard let button = statusItem.button else { return }
        storeControlItemFrame(for: button)
        panelController.toggle(relativeTo: button)
    }

    private func storeControlItemFrame(for button: NSStatusBarButton) {
        guard let window = button.window else { return }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        store.updateControlItemFrame(frame)
    }
}
