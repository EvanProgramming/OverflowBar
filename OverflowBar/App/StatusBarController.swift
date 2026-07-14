import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panelController: OverflowPanelController

    init(store: MenuBarItemStore) {
        panelController = OverflowPanelController(store: store)
        super.init()
        let button = statusItem.button
        button?.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Show OverflowBar")
        button?.target = self
        button?.action = #selector(togglePanel)
        panelController.onVisibilityChanged = { [weak self] isVisible in
            self?.statusItem.button?.image = NSImage(systemSymbolName: isVisible ? "chevron.up" : "chevron.down", accessibilityDescription: isVisible ? "Hide OverflowBar" : "Show OverflowBar")
        }
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        panelController.toggle(relativeTo: button)
    }
}
