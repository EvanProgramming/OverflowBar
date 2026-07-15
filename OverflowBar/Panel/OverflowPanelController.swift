import AppKit
import SwiftUI

@MainActor
final class OverflowPanelController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let store: MenuBarItemStore
    private let presentation = OverflowPanelPresentationState()
    private var globalEventMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var closeWorkItem: DispatchWorkItem?
    private weak var anchorButton: NSStatusBarButton?
    var onVisibilityChanged: ((Bool) -> Void)?

    init(store: MenuBarItemStore) {
        self.store = store
        panel = NSPanel(contentRect: .init(x: 0, y: 0, width: 260, height: OverflowPanelView.preferredHeight), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = if #available(macOS 26.0, *) { false } else { true }
        panel.animationBehavior = .none
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: OverflowPanelView(store: store, presentation: presentation, onActivate: { [weak self] item in
            self?.close()
            self?.store.activate(item)
        }))
        panel.orderOut(nil)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.panel.isVisible, let button = self.anchorButton else { return }
                _ = self.positionPanel(relativeTo: button)
            }
        }
    }

    func toggle(relativeTo button: NSStatusBarButton) { panel.isVisible ? close() : show(relativeTo: button) }
    func show(relativeTo button: NSStatusBarButton) {
        guard !panel.isVisible else { return }
        closeWorkItem?.cancel()
        closeWorkItem = nil
        anchorButton = button
        store.refreshImages()
        guard positionPanel(relativeTo: button) else { return }
        presentation.isPresented = false
        panel.orderFrontRegardless()
        onVisibilityChanged?(true)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            withAnimation(self.reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.3, dampingFraction: 0.82)) {
                self.presentation.isPresented = true
            }
        }
        if let globalEventMonitor { NSEvent.removeMonitor(globalEventMonitor) }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.close() }
        }
    }

    func close() {
        guard panel.isVisible else { return }
        if let globalEventMonitor { NSEvent.removeMonitor(globalEventMonitor); self.globalEventMonitor = nil }
        onVisibilityChanged?(false)
        withAnimation(reduceMotion ? .easeOut(duration: 0.08) : .easeInOut(duration: 0.14)) {
            presentation.isPresented = false
        }
        let workItem = DispatchWorkItem { [weak self] in
            self?.panel.orderOut(nil)
            self?.closeWorkItem = nil
        }
        closeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.08 : 0.15), execute: workItem)
    }

    func windowDidResignKey(_ notification: Notification) { close() }

    deinit {
        if let globalEventMonitor { NSEvent.removeMonitor(globalEventMonitor) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        closeWorkItem?.cancel()
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private func positionPanel(relativeTo button: NSStatusBarButton) -> Bool {
        guard let buttonFrame = button.overflowBarScreenFrame,
              let screen = screen(containing: CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)) else { return false }
        let usableFrame = usableFrame(for: screen)
        guard !usableFrame.isNull, usableFrame.width > 0, usableFrame.height > 0 else { return false }

        let desiredWidth = max(CGFloat(store.selectedItems.count) * OverflowPanelView.itemSlotWidth + 16, 104)
        let maximumWidth = max(96, min(720, usableFrame.width - 16))
        let width = min(desiredWidth, maximumWidth)
        let height = OverflowPanelView.preferredHeight
        panel.setContentSize(.init(width: width, height: height))

        let minimumX = usableFrame.minX + 8
        let maximumX = usableFrame.maxX - width - 8
        let x = maximumX >= minimumX
            ? min(max(buttonFrame.midX - width / 2, minimumX), maximumX)
            : usableFrame.midX - width / 2
        let proposedY = buttonFrame.minY - height - 5
        let minimumY = usableFrame.minY + 6
        let maximumY = usableFrame.maxY - height - 5
        let y = maximumY >= minimumY ? min(max(proposedY, minimumY), maximumY) : usableFrame.midY - height / 2
        panel.setFrameOrigin(.init(x: x.rounded(.toNearestOrAwayFromZero), y: y.rounded(.toNearestOrAwayFromZero)))
        return true
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }) ?? NSScreen.main
    }

    private func usableFrame(for screen: NSScreen) -> CGRect {
        let insets = screen.safeAreaInsets
        let safeFrame = CGRect(
            x: screen.frame.minX + insets.left,
            y: screen.frame.minY + insets.bottom,
            width: max(0, screen.frame.width - insets.left - insets.right),
            height: max(0, screen.frame.height - insets.top - insets.bottom)
        )
        let intersection = screen.visibleFrame.intersection(safeFrame)
        return intersection.isNull ? screen.visibleFrame : intersection
    }
}
