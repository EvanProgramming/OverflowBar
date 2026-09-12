import AppKit
import OSLog

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let hiddenSectionItem: NSStatusItem
    private let store: MenuBarItemStore
    private let panelController: OverflowPanelController
    private let showSettings: () -> Void
    private let logger = Logger(subsystem: "com.overflowbar.app", category: "status")
    private var hoverMonitor: Any?
    private var pointerIsAtMenuBar = false
    private var hoverRevealSuppressedUntilPointerLeaves = false
    private var hiddenSectionReflowWorkItem: DispatchWorkItem?
    private var requestedHiddenSectionLength: CGFloat?

    init(store: MenuBarItemStore, showSettings: @escaping () -> Void) {
        let defaults = UserDefaults.standard
        let arrowName = "OverflowBarControlItem"
        let hiddenName = "OverflowBarHiddenSection"
        // Keep the registration sequence used by the working 1.0.17 build.
        // macOS 26 creates the Control Center host during statusItem(withLength:);
        // registering a second item before the first host is attached makes
        // the whole client enter Control Center's blocked list.
        defaults.set(0.0, forKey: "NSStatusItem Preferred Position \(arrowName)")
        defaults.set(1.0, forKey: "NSStatusItem Preferred Position \(hiddenName)")
        defaults.set(true, forKey: "NSStatusItem Visible \(arrowName)")
        defaults.set(true, forKey: "NSStatusItem Visible \(hiddenName)")
        let visibleLength = max(NSStatusBar.system.thickness, 18)
        let hiddenLength: CGFloat = {
            if #available(macOS 27.0, *) { return 0 }
            return 2_000
        }()
        statusItem = NSStatusBar.system.statusItem(withLength: visibleLength)
        statusItem.autosaveName = arrowName
        hiddenSectionItem = NSStatusBar.system.statusItem(withLength: hiddenLength)
        hiddenSectionItem.autosaveName = hiddenName
        self.store = store
        self.showSettings = showSettings
        panelController = OverflowPanelController(store: store)
        super.init()
        configureHiddenSectionItem()
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
        statusItem.length = visibleLength
        statusItem.isVisible = true
        if #unavailable(macOS 27.0) {
            hiddenSectionItem.isVisible = true
        }
        button?.image = Self.statusBarImage(isExpanded: false)
        button?.target = self
        button?.action = #selector(togglePanel)
        button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateHiddenSectionLength()
        panelController.onVisibilityChanged = { [weak self] isVisible in
            self?.statusItem.button?.image = Self.statusBarImage(isExpanded: isVisible)
        }
        panelController.onItemActivation = { [weak self] in
            // The activation path posts a real session click at a temporary
            // menu-bar position. Some macOS versions emit a synthetic
            // mouseMoved for that event; keep the hover revealer dormant
            // until the pointer has actually left the menu bar, otherwise
            // the panel can reopen on top of the menu just opened.
            self?.hoverRevealSuppressedUntilPointerLeaves = true
            self?.pointerIsAtMenuBar = true
        }
        // Observe mouse movement without consuming or synthesizing events.
        // This removes the old 250ms polling interval plus 120ms debounce, so
        // the panel starts its animation on the first movement into the menu
        // bar while remaining passive for all other applications.
        hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.handleHoverPointer() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            self.statusHostsReady = true
            self.updateHiddenSectionLength()
            self.publishStatusItemWindowIDs()
            self.storeControlItemFrame(for: button)
            if ProcessInfo.processInfo.arguments.contains("--show-panel") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.panelController.show(relativeTo: button)
                }
            }
        }
        // Control Center publishes the hosted window title/ID asynchronously;
        // retry the read while the scene settles so layout never captures a
        // transient zero ID.
        // A new ad-hoc client can take longer than eight seconds to receive
        // its Control Center scene after a stale registration is discarded.
        // Keep publishing until that bounded startup window has elapsed so
        // layout does not permanently retain a zero target ID.
        for delay in [2.0, 4.0, 8.0, 12.0, 16.0, 24.0, 32.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.statusHostsReady = true
                self.updateHiddenSectionLength()
                self.publishStatusItemWindowIDs()
            }
        }
    }

    private var statusHostsReady = false
    private func configureHiddenSectionItem() {
        hiddenSectionItem.button?.image = nil
        // Control Center rejects Command-drag drops into a disabled hosted
        // status item, even though the WindowServer target still exists.
        hiddenSectionItem.button?.cell?.isEnabled = true
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
        if !atMenuBar {
            pointerIsAtMenuBar = false
            hoverRevealSuppressedUntilPointerLeaves = false
            return
        }
        guard !hoverRevealSuppressedUntilPointerLeaves else { return }
        guard atMenuBar != pointerIsAtMenuBar else { return }
        pointerIsAtMenuBar = atMenuBar
        guard atMenuBar, let button = statusItem.button else { return }
        storeControlItemFrame(for: button)
        panelController.show(relativeTo: button)
    }

    func prepareForTermination() {
        hiddenSectionReflowWorkItem?.cancel()
        hiddenSectionReflowWorkItem = nil
        requestedHiddenSectionLength = 0
        hiddenSectionItem.isVisible = false
        hiddenSectionItem.length = 0
    }

    @objc private func togglePanel() {
        if NSApp.currentEvent?.type == .rightMouseUp { showSettings(); return }
        guard let button = statusItem.button else { return }
        storeControlItemFrame(for: button)
        panelController.toggle(relativeTo: button)
    }

    private func storeControlItemFrame(for button: NSStatusBarButton) {
        publishStatusItemWindowIDs()
        if let frame = button.overflowBarScreenFrame { store.updateControlItemFrame(frame) }
    }

    private func publishStatusItemWindowIDs() {
        let controlWindowID = statusWindowID(for: statusItem)
        let hiddenWindowID = statusWindowID(for: hiddenSectionItem)
        logger.info("Published status item windows control=\(controlWindowID ?? 0, privacy: .public) hidden=\(hiddenWindowID ?? 0, privacy: .public)")
        if let button = statusItem.button {
            let appKitFrame = button.window.map { $0.convertToScreen(button.convert(button.bounds, to: nil)) } ?? .zero
            let axFrame = button.accessibilityFrame()
            logger.info("Status item diagnostics visible=\(self.statusItem.isVisible, privacy: .public) length=\(self.statusItem.length, privacy: .public) hidden=\(button.isHidden, privacy: .public) alpha=\(button.alphaValue, privacy: .public) buttonFrame=\(String(describing: button.frame), privacy: .public) window=\(button.window?.windowNumber ?? 0, privacy: .public) windowFrame=\(String(describing: button.window?.frame ?? .zero), privacy: .public) windowVisible=\(button.window?.isVisible ?? false, privacy: .public) appKitFrame=\(String(describing: appKitFrame), privacy: .public) axFrame=\(String(describing: axFrame), privacy: .public) image=\(button.image != nil, privacy: .public)")
        }
        store.updateStatusItemWindowIDs(control: controlWindowID, hidden: hiddenWindowID)
    }

    private func statusWindowID(for item: NSStatusItem) -> CGWindowID? {
        let hidden = item === hiddenSectionItem
        let exactTitle = hidden ? "OverflowBarHiddenSection" : "OverflowBarControlItem"
        let expectedTitle = hidden ? "Item-1" : "Item-0"
        let windows = MenuBarWindowServer.windowInfo()
        if let exact = windows.compactMap({ info -> (id: CGWindowID, width: CGFloat)? in
            guard MenuBarWindowServer.isStatusItemLayer(info),
                  (info[kCGWindowOwnerName as String] as? String) == "Control Center",
                  (info[kCGWindowName as String] as? String) == exactTitle,
                  let rawID = MenuBarWindowServer.integer(kCGWindowNumber as String, in: info),
                  rawID > 0,
                  rawID <= Int(CGWindowID.max),
                  let bounds = MenuBarWindowServer.bounds(in: info) else { return nil }
            return (CGWindowID(rawID), bounds.width)
        }).max(by: { $0.id < $1.id }) {
            return exact.id
        }
        let candidates = windows.compactMap { info -> (id: CGWindowID, width: CGFloat)? in
            guard MenuBarWindowServer.isStatusItemLayer(info),
                  (info[kCGWindowOwnerName as String] as? String) == "Control Center",
                  (info[kCGWindowName as String] as? String) == expectedTitle,
                  let rawID = MenuBarWindowServer.integer(kCGWindowNumber as String, in: info),
                  rawID > 0,
                  rawID <= Int(CGWindowID.max),
                  let bounds = MenuBarWindowServer.bounds(in: info) else { return nil }
            return (CGWindowID(rawID), bounds.width)
        }
        guard !candidates.isEmpty else { return nil }
        if hidden {
            return candidates.filter { $0.width > 1_000 }.max { $0.id < $1.id }?.id
                ?? candidates.max { $0.id < $1.id }?.id
        }
        return candidates.filter { $0.width >= 25 && $0.width <= 100 }.max { $0.id < $1.id }?.id
    }

    private func updateHiddenSectionLength() {
        if #available(macOS 27.0, *) {
            // macOS 27 owns the overflow slot and renders the menu bar as a
            // composite host. Keeping a staging item would compete with it.
            hiddenSectionItem.length = 0
            hiddenSectionItem.isVisible = false
            requestedHiddenSectionLength = 0
            return
        }
        if #available(macOS 26.0, *) {
            // Control Center fixes a hosted status item's width when it is
            // registered. Resizing it to zero or a square staging slot leaves
            // a permanent 38pt host on macOS 26, so keep the launch-time
            // 2,000pt hidden lane stable.
            return
        }
        let desiredLength: CGFloat = store.isReadyForManagedLayout &&
            store.layoutManagementEnabled && !store.selectedItems.isEmpty
            ? 2_000
            : 0
        guard statusHostsReady else { return }
        let item = hiddenSectionItem
        guard requestedHiddenSectionLength != desiredLength else { return }
        requestedHiddenSectionLength = desiredLength
        hiddenSectionReflowWorkItem?.cancel()

        if desiredLength == 0 {
            item.isVisible = false
            item.length = 0
            publishStatusItemWindowIDs()
            return
        }

        // A hosted status item that has already been expanded is often left
        // off-screen by Control Center when it is merely resized smaller.
        // Hide it completely, let Control Center discard that placement, then
        // show a compact staging slot before sending any Command-drag.
        item.isVisible = false
        item.length = 0
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.requestedHiddenSectionLength == desiredLength else { return }
            item.isVisible = true
            item.length = desiredLength
            self.hiddenSectionReflowWorkItem = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard self?.requestedHiddenSectionLength == desiredLength else { return }
                self?.publishStatusItemWindowIDs()
            }
        }
        hiddenSectionReflowWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
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
        let matchedWindow = windows.first(where: {
            guard MenuBarWindowServer.isStatusItemLayer($0) else { return false }
            if let windowNumber = window?.windowNumber, windowNumber > 0,
               MenuBarWindowServer.integer(kCGWindowNumber as String, in: $0) == windowNumber {
                return true
            }
            return ($0[kCGWindowName as String] as? String) == "OverflowBarControlItem"
        })
        if let matchedWindow, let coreGraphicsFrame = MenuBarWindowServer.bounds(in: matchedWindow) {
            let screen = NSScreen.screens.first(where: { $0.frame.minX <= coreGraphicsFrame.midX && $0.frame.maxX >= coreGraphicsFrame.midX }) ?? NSScreen.main
            if let screen,
               coreGraphicsFrame.width > 0,
               coreGraphicsFrame.height > 0,
               coreGraphicsFrame.minY <= NSStatusBar.system.thickness + 8 {
                return CGRect(
                    x: coreGraphicsFrame.minX,
                    y: screen.frame.maxY - coreGraphicsFrame.maxY,
                    width: coreGraphicsFrame.width,
                    height: coreGraphicsFrame.height
                )
            }
        }
        if let window {
            let frame = window.convertToScreen(convert(bounds, to: nil))
            if let screen = NSScreen.screens.first(where: {
                $0.frame.insetBy(dx: -2, dy: -2).contains(CGPoint(x: frame.midX, y: frame.midY))
            }),
               frame.width > 0,
               frame.height > 0,
               frame.midY >= screen.frame.maxY - NSStatusBar.system.thickness - 8 {
                return frame
            }
        }

        // Hosted status items can report a zero-origin AppKit window while
        // still exposing their real screen rectangle through Accessibility.
        let axFrame = self.accessibilityFrame()
        if axFrame.width > 0,
           axFrame.height > 0,
           let screen = NSScreen.screens.first(where: {
               $0.frame.insetBy(dx: -2, dy: -2).contains(CGPoint(x: axFrame.midX, y: axFrame.midY))
           }),
           axFrame.maxY >= screen.frame.maxY - NSStatusBar.system.thickness - 8 {
            return axFrame
        }

        // macOS 26 may host an NSStatusItem inside Control Center without
        // publishing a dedicated layer-25 window for its autosave name. In
        // that case AppKit can return a zero-origin frame. While the pointer
        // is in the menu bar it is the only reliable on-screen anchor; never
        // pass the invalid frame through to panel positioning.
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }),
              mouse.y >= screen.frame.maxY - NSStatusBar.system.thickness - 8 else {
            return nil
        }
        return CGRect(
            x: mouse.x - 1,
            y: screen.frame.maxY - NSStatusBar.system.thickness,
            width: 2,
            height: NSStatusBar.system.thickness
        )
    }
}
