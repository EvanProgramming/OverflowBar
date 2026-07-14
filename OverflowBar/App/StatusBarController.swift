import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panelController: OverflowPanelController
    private let showSettings: () -> Void

    init(store: MenuBarItemStore, showSettings: @escaping () -> Void) {
        self.showSettings = showSettings
        panelController = OverflowPanelController(store: store)
        super.init()
        let button = statusItem.button
        button?.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Show OverflowBar")
        button?.target = self
        button?.action = #selector(togglePanel)
        button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        panelController.onVisibilityChanged = { [weak self] isVisible in
            self?.statusItem.button?.image = NSImage(systemSymbolName: isVisible ? "chevron.up" : "chevron.down", accessibilityDescription: isVisible ? "Hide OverflowBar" : "Show OverflowBar")
        }
    }

    @objc private func togglePanel() {
        if NSApp.currentEvent?.type == .rightMouseUp { showSettings(); return }
        guard let button = statusItem.button else { return }
        panelController.toggle(relativeTo: button)
    }
}
