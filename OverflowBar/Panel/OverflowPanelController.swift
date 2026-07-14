import AppKit
import SwiftUI

@MainActor
final class OverflowPanelController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let store: MenuBarItemStore
    private var globalEventMonitor: Any?
    var onVisibilityChanged: ((Bool) -> Void)?

    init(store: MenuBarItemStore) {
        self.store = store
        panel = NSPanel(contentRect: .init(x: 0, y: 0, width: 260, height: 54), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: OverflowPanelView(store: store, onActivate: { [weak self] item in self?.store.activate(item) }))
        panel.orderOut(nil)
    }

    func toggle(relativeTo button: NSStatusBarButton) { panel.isVisible ? close() : show(relativeTo: button) }
    func show(relativeTo button: NSStatusBarButton) {
        guard !panel.isVisible else { return }
        let width = min(max(CGFloat(store.selectedItems.count) * 48 + 24, 120), 640)
        panel.setContentSize(.init(width: width, height: 54))
        guard let buttonFrame = button.overflowBarScreenFrame else { return }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)) }) ?? NSScreen.main
        guard let screen else { return }
        let x = min(max(buttonFrame.midX - width / 2, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - width - 8)
        panel.setFrameOrigin(.init(x: x, y: buttonFrame.minY - panel.frame.height - 2))
        panel.orderFrontRegardless()
        onVisibilityChanged?(true)
        if let globalEventMonitor { NSEvent.removeMonitor(globalEventMonitor) }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.close() }
    }

    func close() {
        guard panel.isVisible else { return }
        if let globalEventMonitor { NSEvent.removeMonitor(globalEventMonitor); self.globalEventMonitor = nil }
        panel.orderOut(nil)
        onVisibilityChanged?(false)
    }
    func windowDidResignKey(_ notification: Notification) { close() }
}
