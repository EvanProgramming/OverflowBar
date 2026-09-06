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

    init(store: MenuBarItemStore, showSettings: @escaping () -> Void) {
        let arrowName = "OverflowBarControlItem"
        let hiddenName = "OverflowBarHiddenSection"
        let defaults = UserDefaults.standard
        defaults.set(0.0, forKey: "NSStatusItem Preferred Position \(arrowName)")
        defaults.set(1.0, forKey: "NSStatusItem Preferred Position \(hiddenName)")
        if #unavailable(macOS 27.0) {
            defaults.set(true, forKey: "NSStatusItem Visible \(arrowName)")
            defaults.set(true, forKey: "NSStatusItem Visible \(hiddenName)")
        }
        // macOS 26 creates the Control Center host during this call. Give the
        // visible item its final width up front; changing a zero-width hosted
        // scene after registration can leave the scene connected but blank.
        let visibleLength = max(NSStatusBar.system.thickness, 18)
        let createdStatusItem = NSStatusBar.system.statusItem(withLength: visibleLength)
        // Control Center fixes a hosted item's width when it is registered.
        // Keep the staging lane registered from launch; changing a zero-width
        // item later cannot recreate its WindowServer target on macOS 26.
        let hiddenLength: CGFloat
        if #available(macOS 27.0, *) {
            hiddenLength = 0
        } else if #available(macOS 26.0, *) {
            hiddenLength = 2_000
        } else {
            hiddenLength = 0
        }
        let createdHiddenSectionItem = NSStatusBar.system.statusItem(withLength: hiddenLength)
        createdStatusItem.autosaveName = arrowName
        createdHiddenSectionItem.autosaveName = hiddenName
        statusItem = createdStatusItem
        hiddenSectionItem = createdHiddenSectionItem
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
        statusItem.length = visibleLength
        statusItem.isVisible = true
        if #unavailable(macOS 27.0) {
            hiddenSectionItem.isVisible = true
        }
        button?.image = Self.statusBarImage(isExpanded: false)
        button?.target = self
        button?.action = #selector(togglePanel)
        button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        hiddenSectionItem.button?.image = nil
        // Keep the staging host a valid status-item drop target on macOS 26.
        // A disabled host still gets a WindowServer window, but Control Center
        // rejects Command-drag drops into it.
        hiddenSectionItem.button?.cell?.isEnabled = true
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
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            self.publishStatusItemWindowIDs()
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
            guard (info[kCGWindowLayer as String] as? Int) == 25,
                  (info[kCGWindowOwnerName as String] as? String) == "Control Center",
                  (info[kCGWindowName as String] as? String) == exactTitle,
                  let rawID = info[kCGWindowNumber as String] as? Int,
                  rawID > 0,
                  rawID <= Int(CGWindowID.max),
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            return (CGWindowID(rawID), bounds["Width"] ?? 0)
        }).max(by: { $0.id < $1.id }) {
            return exact.id
        }
        let candidates = windows.compactMap { info -> (id: CGWindowID, width: CGFloat)? in
            guard (info[kCGWindowLayer as String] as? Int) == 25,
                  (info[kCGWindowOwnerName as String] as? String) == "Control Center",
                  (info[kCGWindowName as String] as? String) == expectedTitle,
                  let rawID = info[kCGWindowNumber as String] as? Int,
                  rawID > 0,
                  rawID <= Int(CGWindowID.max),
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            return (CGWindowID(rawID), bounds["Width"] ?? 0)
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
            return
        }
        if #available(macOS 26.0, *) {
            // Hosted status items keep the width they received at registration.
            // The 2,000pt lane is intentionally always present and extends
            // off the active display, providing a stable drag destination.
            return
        }
        let desiredLength: CGFloat = store.isReadyForManagedLayout &&
            store.layoutManagementEnabled && !store.selectedItems.isEmpty ? 2_000 : 0
        guard hiddenSectionItem.length != desiredLength else { return }
        hiddenSectionItem.isVisible = desiredLength > 0
        hiddenSectionItem.length = desiredLength
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.publishStatusItemWindowIDs()
        }
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
            guard ($0[kCGWindowLayer as String] as? Int) == 25 else { return false }
            if let windowNumber = window?.windowNumber, windowNumber > 0,
               ($0[kCGWindowNumber as String] as? Int) == windowNumber {
                return true
            }
            return ($0[kCGWindowName as String] as? String) == "OverflowBarControlItem"
        })?[kCGWindowBounds as String] as? [String: CGFloat] {
            let coreGraphicsFrame = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
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
