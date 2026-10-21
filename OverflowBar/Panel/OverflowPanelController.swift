import AppKit
import SwiftUI

@MainActor
final class OverflowPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

@MainActor
final class OverflowPanelController: NSObject, NSWindowDelegate {
    private let panel: OverflowPanel
    private let store: MenuBarItemStore
    private let presentation = OverflowPanelPresentationState()
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var previewTimer: Timer?
    private var closeWorkItem: DispatchWorkItem?
    private weak var anchorButton: NSStatusBarButton?
    var onVisibilityChanged: ((Bool) -> Void)?

    init(store: MenuBarItemStore) {
        self.store = store
        panel = OverflowPanel(contentRect: .init(x: 0, y: 0, width: 260, height: OverflowPanelView.preferredHeight), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.title = "OverflowBar Panel"
        panel.setAccessibilityLabel("OverflowBar Panel")
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.onCancel = { [weak self] in self?.close() }
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = if #available(macOS 26.0, *) { false } else { true }
        panel.animationBehavior = .none
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: OverflowPanelView(store: store, presentation: presentation, onActivate: { [weak self] item in
            self?.store.activate(item) { [weak self] result in
                if result == .activated || result == .itemChanged { self?.close() }
            }
        }, onRightActivate: { [weak self] item in
            self?.store.activate(item, mouseButton: .right) { [weak self] result in
                if result == .activated || result == .itemChanged { self?.close() }
            }
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
    func show(relativeTo button: NSStatusBarButton, takeKeyboardFocus: Bool = true) {
        let wasClosing = closeWorkItem != nil
        closeWorkItem?.cancel()
        closeWorkItem = nil
        guard !panel.isVisible || wasClosing else {
            if takeKeyboardFocus { panel.makeKey() }
            return
        }
        anchorButton = button
        guard positionPanel(relativeTo: button) else { return }
        presentation.isPresented = false
        panel.orderFrontRegardless()
        if takeKeyboardFocus { panel.makeKey() }
        onVisibilityChanged?(true)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            withAnimation(self.reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.3, dampingFraction: 0.82)) {
                self.presentation.isPresented = true
            }
        }
        // Discovery and icon capture may involve WindowServer or
        // ScreenCaptureKit. Keep them behind the first visible frame so hover
        // animation is never held up by a refresh.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.store.refreshIfWindowSetChanged(immediate: false)
            self.store.refreshImages()
        }
        previewTimer?.invalidate()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in Task { @MainActor in self?.store.refreshImages() } }
        if let globalEventMonitor { NSEvent.removeMonitor(globalEventMonitor) }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.close() }
        }
        if let localEventMonitor { NSEvent.removeMonitor(localEventMonitor) }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, event.window === self.panel,
               let content = self.panel.contentView,
               content.bounds.contains(content.convert(event.locationInWindow, from: nil)) {
                return event
            }
            DispatchQueue.main.async { self?.close() }
            return event
        }
    }

    func close() {
        guard panel.isVisible else { return }
        previewTimer?.invalidate(); previewTimer = nil
        store.cancelPendingCapture()
        if let globalEventMonitor { NSEvent.removeMonitor(globalEventMonitor); self.globalEventMonitor = nil }
        if let localEventMonitor { NSEvent.removeMonitor(localEventMonitor); self.localEventMonitor = nil }
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

    deinit {
        previewTimer?.invalidate()
        if let globalEventMonitor { NSEvent.removeMonitor(globalEventMonitor) }
        if let localEventMonitor { NSEvent.removeMonitor(localEventMonitor) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        closeWorkItem?.cancel()
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private func positionPanel(relativeTo button: NSStatusBarButton) -> Bool {
        let fallbackFrame = (NSScreen.main ?? NSScreen.screens.first).map { screen in
            let size = NSStatusBar.system.thickness
            return CGRect(x: screen.visibleFrame.maxX - size - 8, y: screen.visibleFrame.maxY, width: size, height: size)
        }
        guard let buttonFrame = MenuBarGroupGeometry.panelAnchorFrame(
                buttonFrame: store.nativeControlFrame("OverflowBarControlItem") ?? button.overflowBarScreenFrame,
                fallbackFrame: fallbackFrame
              ),
              let screen = screen(containing: CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)) else { return false }
        let usableFrame = usableFrame(for: screen)
        guard !usableFrame.isNull, usableFrame.width > 0, usableFrame.height > 0 else { return false }

        let desiredWidth = max(CGFloat(store.overflowItems.count) * OverflowPanelView.itemSlotWidth + 16, 104)
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
