import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let store: MenuBarItemStore
    private let panelController: OverflowPanelController
    private let showSettings: () -> Void
    private var mouseMonitor: Any?

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
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self, let screen = NSScreen.screens.first(where: { $0.frame.contains(event.locationInWindow) }),
                  event.locationInWindow.y >= screen.frame.maxY - NSStatusBar.system.thickness - 2,
                  let button = self.statusItem.button else { return }
            self.panelController.show(relativeTo: button)
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

    deinit { if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) } }

    @objc private func togglePanel() {
        if NSApp.currentEvent?.type == .rightMouseUp { showSettings(); return }
        guard let button = statusItem.button else { return }
        storeControlItemFrame(for: button)
        panelController.toggle(relativeTo: button)
    }

    private func storeControlItemFrame(for button: NSStatusBarButton) {
        if let frame = button.overflowBarScreenFrame { store.updateControlItemFrame(frame) }
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
