import AppKit
import Combine
import OSLog

@MainActor
final class MenuBarItemStore: ObservableObject {
    @Published private(set) var items: [MenuBarItem] = []
    @Published var lastActivationError: String?
    @Published private(set) var activatingItemID: String?
    @Published private(set) var layoutManagementEnabled = false
    @Published private(set) var layoutOperationMessage: String?
    @Published private(set) var iconCaptureMessage: String?
    @Published private(set) var isReadyForManagedLayout = false

    private let logger = Logger(subsystem: "com.overflowbar.app", category: "items")
    private let preferences = PreferencesStore()
    private let scanner = MenuBarScanner()
    private let captureService = MenuBarCaptureService()
    private let activator = MenuBarItemActivator()
    private let layoutManager: MenuBarLayoutManager
    private var controlItemFrame: CGRect?
    private var rehideWorkItem: DispatchWorkItem?
    private var menuTrackingBeginObserver: NSObjectProtocol?
    private var menuTrackingEndObserver: NSObjectProtocol?
    private var menuDismissMonitor: Any?
    private var transientDismissCheck: DispatchWorkItem?
    private var pendingRehideItem: MenuBarItem?
    // NSMenu can nest tracking sessions (for example, a submenu opened from
    // a status-item menu). Keep a depth instead of a Boolean so an inner
    // didEndTracking notification cannot make us rehide while the parent
    // menu is still interactive.
    private var menuTrackingDepth = 0
    private var layoutWorkItem: DispatchWorkItem?
    private var automaticLayoutWorkItem: DispatchWorkItem?
    private var refreshWorkItem: DispatchWorkItem?
    private var captureTask: Task<Void, Never>?
    private var monitorTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lastWindowSignature = Set<String>()
    private var captureGeneration = 0
    private var isRefreshing = false
    private var isCapturing = false
    private var refreshAgain = false
    private var isApplyingLayout = false
    private var shouldApplyLayoutAgain = false
    private var layoutRepairAttempts = 0
    var onImagesReady: (() -> Void)?
    var onLayoutStateChanged: (() -> Void)?

    init() {
        layoutManager = MenuBarLayoutManager(preferences: preferences)
        layoutManagementEnabled = layoutManager.isEnabled
        menuTrackingBeginObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.menuTrackingDepth += 1 }
        }
        menuTrackingEndObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.menuTrackingDepth = max(0, self.menuTrackingDepth - 1)
                guard self.menuTrackingDepth == 0 else { return }
                if let item = self.pendingRehideItem,
                   self.hasVisibleTransientWindow(for: item) {
                    self.scheduleTransientDismissCheck(for: item)
                } else {
                    self.rehidePendingItem()
                }
            }
        }
    }

    deinit {
        monitorTimer?.invalidate()
        refreshWorkItem?.cancel()
        layoutWorkItem?.cancel()
        automaticLayoutWorkItem?.cancel()
        captureTask?.cancel()
        transientDismissCheck?.cancel()
        if let menuTrackingBeginObserver { NotificationCenter.default.removeObserver(menuTrackingBeginObserver) }
        if let menuTrackingEndObserver { NotificationCenter.default.removeObserver(menuTrackingEndObserver) }
        if let menuDismissMonitor { NSEvent.removeMonitor(menuDismissMonitor) }
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
    }

    /// Items the user selected to move out of the original menu bar. System
    /// controls are recognized separately for safety, but their visibility is
    /// still user-configurable in Settings.
    var selectedItems: [MenuBarItem] {
        items.filter { $0.isSelected && !$0.isAlwaysVisibleSystemItem }
    }

    /// Items currently in OverflowBar's off-screen staging area but absent
    /// from the persisted selection set. This recovers protected macOS
    /// controls left there by an older build, including generic Control
    /// Center windows whose accessibility description is only "status menu"
    /// (for example Bluetooth on macOS 26).
    var overflowItems: [MenuBarItem] {
        let selectedIDs = Set(selectedItems.map(\.id))
        return items
            .filter { selectedIDs.contains($0.id) || isOffscreen($0) }
            .sorted { $0.frame.minX < $1.frame.minX }
    }

    private func isOffscreen(_ item: MenuBarItem) -> Bool {
        guard item.windowID != nil else { return false }
        return item.frame.maxX <= 0 && item.frame.minY >= 0 && item.frame.maxY <= 40
    }

    /// Starts resilient discovery. Polling is intentional: NSWorkspace launch
    /// notifications omit LSUIElement/background applications, and status
    /// items can be created or replaced without their process launching.
    func startMonitoring() {
        guard monitorTimer == nil else { return }
        lastWindowSignature = scanner.windowSignature()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didWakeNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.scheduleRefresh(after: 0.35, reason: "workspace change") }
            })
        }
        // Menu-bar changes are intentionally sampled at a low duty cycle.
        // Launch/terminate notifications and explicit panel refreshes still
        // provide immediate discovery; this timer is only the safety net for
        // background status-item processes that emit no notifications.
        let timer = Timer(timeInterval: 8, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshIfWindowSetChanged() }
        }
        RunLoop.main.add(timer, forMode: .common)
        monitorTimer = timer

        // Login items do not become ready at the same time. These bounded
        // rescans fill in late windows/icons without requiring user action.
        for delay in [0.8, 2.0, 5.0, 10.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.items.isEmpty || !self.isReadyForManagedLayout else { return }
                self.scheduleRefresh(after: 0, reason: "startup retry")
            }
        }
    }

    func refresh() {
        guard !isRefreshing, !isCapturing else { refreshAgain = true; return }
        isRefreshing = true
        let previousByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let previousByWindowID = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.windowID.map { ($0, item) }
        })
        let knownBefore = preferences.knownItemIDs
        let knownWindowIDsBefore = preferences.knownWindowIDs
        let deselectedBefore = preferences.deselectedItemIDs
        let selectedBefore = preferences.selectedIDs
        let scanned = scanner.scan(selectedIDs: selectedBefore)
        let currentIDs = Set(scanned.map(\.id))
        let selectableCurrentIDs = Set(scanned.filter { !$0.isProtectedSystemItem }.map(\.id))
        let currentWindowIDs = Set(scanned.compactMap(\.windowID))
        let newWindowIDs = currentWindowIDs.subtracting(knownWindowIDsBefore)

        for item in scanned {
            let previous = previousByID[item.id] ?? item.windowID.flatMap { previousByWindowID[$0] }
            item.iconImage = previous?.iconImage
            // System-item selection is derived from the current WindowServer
            // frame (or an explicit persisted selection), not from a stale
            // pre-1.0.15 object that may have treated every system item as
            // permanently unselected.
            if let previous, !item.isProtectedSystemItem { item.isSelected = previous.isSelected }
            // An explicit user deselection wins over the frame-based stale
            // hidden-state recovery used for system controls.
            if item.isProtectedSystemItem && deselectedBefore.contains(item.id) {
                item.isSelected = false
            }
            if item.isAlwaysVisibleSystemItem {
                item.isSelected = false
            }
        }

        if !preferences.didApplyDefaultLayout, !scanned.isEmpty {
            // Keep the scanner's off-screen state for system controls so a
            // previous build's hidden icons can be restored from Settings;
            // visible system controls remain unselected by default.
            scanned.forEach { if !$0.isProtectedSystemItem { $0.isSelected = true } }
            preferences.didApplyDefaultLayout = true
            layoutManager.isEnabled = false
            layoutManagementEnabled = false
        } else if !knownBefore.isEmpty, layoutManagementEnabled {
            let newIDs = selectableCurrentIDs.subtracting(knownBefore)
            let newWindowItems = scanned.filter { item in
                !item.isProtectedSystemItem && item.windowID.map(newWindowIDs.contains) == true &&
                    !deselectedBefore.contains(item.id)
            }
            for item in scanned where newIDs.contains(item.id) || newWindowItems.contains(where: { $0.id == item.id }) {
                if !deselectedBefore.contains(item.id) { item.isSelected = true }
            }
            if !newIDs.isEmpty || !newWindowItems.isEmpty {
                logger.info("Discovered and selected \(max(newIDs.count, newWindowItems.count), privacy: .public) new menu bar item(s)")
            }
        }

        // Once managed layout is enabled, every newly discovered item is
        // selected unless the user explicitly deselected its persisted ID.
        // WindowServer can replace a status-item window while keeping the
        // same icon; in that case occurrence-based IDs are not stable enough
        // to decide whether the replacement should be hidden. Preserving an
        // explicit deselection while defaulting new items to selected keeps
        // ordinary third-party icons out of the menu bar after a refresh.
        if layoutManagementEnabled {
            for item in scanned where !item.isProtectedSystemItem && !deselectedBefore.contains(item.id) {
                let previous = previousByID[item.id] ?? item.windowID.flatMap { previousByWindowID[$0] }
                if previous == nil { item.isSelected = true }
            }
        }

        items = scanned
        preferences.saveKnownItems(knownBefore.union(currentIDs))
        preferences.saveKnownWindowIDs(knownWindowIDsBefore.union(currentWindowIDs))
        let selectedNow = Set(scanned.filter(\.isSelected).map(\.id))
        preferences.saveSelected(selectedBefore.subtracting(currentIDs).union(selectedNow))
        lastWindowSignature = scanner.windowSignature()
        isRefreshing = false
        onLayoutStateChanged?()
        isReadyForManagedLayout = selectedItems.allSatisfy(\.hasUsableDisplayIcon)
        onImagesReady?()
        // Reconcile selected items that are still visible after a WindowServer
        // refresh. This is delayed until capture completes and guarded by the
        // same real-button check as explicit layout actions, so new status
        // items do not remain beside OverflowBar while avoiding a drag during
        // an active user click.

        let captureCandidates = preferences.hasCompletedOnboarding ? overflowItems : items
        refreshImages(for: captureCandidates) { [weak self] in
            guard let self else { return }
            self.onLayoutStateChanged?()
            self.onImagesReady?()
            self.scheduleAutomaticLayoutIfNeeded()
            if self.refreshAgain {
                self.refreshAgain = false
                self.scheduleRefresh(after: 0.2, reason: "coalesced refresh")
            }
        }
    }

    func refreshIfWindowSetChanged(immediate: Bool = false) {
        let signature = scanner.windowSignature()
        guard signature != lastWindowSignature else { return }
        lastWindowSignature = signature
        if immediate {
            refresh()
        } else {
            scheduleRefresh(after: 0.4, reason: "menu bar window set changed")
        }
    }

    private func scheduleRefresh(after delay: TimeInterval, reason: String) {
        refreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.logger.debug("Refreshing after \(reason, privacy: .public)")
            self?.refresh()
        }
        refreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func setSelected(_ item: MenuBarItem, selected: Bool) {
        guard !item.isAlwaysVisibleSystemItem else { return }
        item.isSelected = selected
        objectWillChange.send()
        var deselected = preferences.deselectedItemIDs
        if selected { deselected.remove(item.id) } else { deselected.insert(item.id) }
        preferences.saveDeselectedItems(deselected)
        let currentIDs = Set(items.map(\.id))
        let retainedMissing = preferences.selectedIDs.subtracting(currentIDs)
        preferences.saveSelected(retainedMissing.union(items.filter(\.isSelected).map(\.id)))
        if selected { applyLayout() } else { layoutManager.show(item) }
        onLayoutStateChanged?()
    }

    func selectAll(_ selected: Bool) {
        let previouslySelected = items.filter(\.isSelected)
        for item in items { item.isSelected = selected && !item.isAlwaysVisibleSystemItem }
        if selected {
            preferences.saveDeselectedItems([])
        } else {
            preferences.saveDeselectedItems(Set(items.map(\.id)))
        }
        preferences.saveSelected(Set(items.filter(\.isSelected).map(\.id)))
        objectWillChange.send()
        if selected {
            applyLayout()
        } else if let controlItemFrame {
            layoutOperationMessage = "Restoring menu bar items…"
            layoutManager.restore(previouslySelected, relativeTo: controlItemFrame) { [weak self] count in
                self?.layoutOperationMessage = count > 0 ? "Restored \(count) menu bar items." : "Menu bar items are already visible."
            }
        }
        onLayoutStateChanged?()
    }

    func refreshImages(for target: [MenuBarItem]? = nil, completion: (() -> Void)? = nil) {
        // A panel open can arrive while the startup refresh is still
        // capturing. Do not launch a second ScreenCaptureKit enumeration;
        // overlapping captures were a major source of memory spikes and
        // apparent hangs.
        guard !isCapturing else { return }
        captureGeneration += 1
        let generation = captureGeneration
        let candidates = target ?? overflowItems
        isCapturing = true
        captureTask?.cancel()
        captureTask = Task { [weak self] in
            guard let self else { return }
            let images = await self.captureService.capture(candidates)
            guard generation == self.captureGeneration else { return }
            self.captureTask = nil
            self.isCapturing = false
            for (id, image) in images {
                self.items.first(where: { $0.id == id })?.iconImage = image
            }
            let availableCount = candidates.filter { candidate in
                self.items.first(where: { $0.id == candidate.id })?.displayImage != nil
            }.count
            self.iconCaptureMessage = candidates.isEmpty
                ? nil
                : "Loaded \(availableCount) of \(candidates.count) menu bar icons."
            self.isReadyForManagedLayout = self.selectedItems.allSatisfy(\.hasUsableDisplayIcon)
            self.objectWillChange.send()
            completion?()
        }
    }

    func updateControlItemFrame(_ frame: CGRect) { controlItemFrame = frame }

    func setLayoutManagementEnabled(_ enabled: Bool) {
        layoutManager.isEnabled = enabled
        layoutManagementEnabled = enabled
        onLayoutStateChanged?()
        if enabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in self?.applyLayout() }
        } else {
            automaticLayoutWorkItem?.cancel()
            restoreLayout()
        }
    }

    private func scheduleAutomaticLayoutIfNeeded() {
        guard preferences.hasCompletedOnboarding,
              layoutManagementEnabled,
              !selectedItems.isEmpty,
              isReadyForManagedLayout,
              selectedItems.contains(where: layoutManager.isVisible) else { return }
        automaticLayoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.automaticLayoutWorkItem = nil
            self.applyLayout()
        }
        automaticLayoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    func applyLayout() {
        guard layoutManagementEnabled, !selectedItems.isEmpty else { return }
        guard isReadyForManagedLayout else {
            layoutOperationMessage = "Hidden layout paused until selected icons are available."
            return
        }
        if isApplyingLayout {
            shouldApplyLayoutAgain = true
            return
        }
        // Never begin a WindowServer status-item move while the user is in the
        // middle of a real click or drag.
        if CGEventSource.buttonState(.combinedSessionState, button: .left) ||
            CGEventSource.buttonState(.combinedSessionState, button: .right) {
            scheduleLayoutRetry(after: 0.2)
            return
        }
        isApplyingLayout = true
        layoutOperationMessage = "Applying hidden layout…"
        layoutManager.hide(selectedItems, relativeTo: controlItemFrame ?? .zero) { [weak self] count in
            guard let self else { return }
            self.isApplyingLayout = false
            let remaining = self.selectedItems.filter(self.layoutManager.needsHiding)
            if remaining.isEmpty {
                self.layoutRepairAttempts = 0
                self.layoutOperationMessage = count > 0 ? "Hidden layout updated (\(count) moved)." : "No menu bar items needed moving."
            } else if self.layoutRepairAttempts < 2 {
                self.layoutRepairAttempts += 1
                self.layoutOperationMessage = "Repairing hidden layout (\(remaining.count) remaining)…"
                self.scheduleLayoutRetry(after: 0.4)
            } else {
                self.layoutOperationMessage = "Hidden layout incomplete (\(remaining.count) still visible). Try Apply Hidden Layout again."
            }
            if self.shouldApplyLayoutAgain {
                self.shouldApplyLayoutAgain = false
                self.scheduleLayoutRetry(after: 0.2)
            }
        }
    }

    private func scheduleLayoutRetry(after delay: TimeInterval) {
        layoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.applyLayout() }
        layoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func restoreLayout(completion: @escaping () -> Void = {}) {
        guard let controlItemFrame else { completion(); return }
        layoutOperationMessage = "Restoring menu bar items…"
        layoutManager.restore(selectedItems, relativeTo: controlItemFrame) { [weak self] count in
            self?.layoutOperationMessage = count > 0 ? "Restored \(count) menu bar items." : "Menu bar items are already visible."
            completion()
        }
    }

    func restoreAllAndDisable() {
        layoutManager.isEnabled = false
        layoutManagementEnabled = false
        onLayoutStateChanged?()
        restoreLayout { [weak self] in self?.restoreProtectedSystemItems() }
    }

    func prepareForTermination(completion: @escaping () -> Void) {
        captureGeneration += 1
        captureTask?.cancel()
        captureTask = nil
        isCapturing = false
        restoreLayout(completion: completion)
    }

    func restoreProtectedSystemItems(completion: @escaping () -> Void = {}) {
        layoutManager.restoreProtectedSystemItems { _ in completion() }
    }

    func activate(_ item: MenuBarItem, mouseButton: CGMouseButton = .left, retryCount: Int = 0) {
        guard activatingItemID == nil else { return }
        cancelPendingRehide()
        activatingItemID = item.id
        lastActivationError = nil
        if mouseButton == .left, activator.activateDirectly(item) {
            finishActivation()
            return
        }
        // WindowServer-backed items can be clicked directly without a global
        // Accessibility hit-test. This avoids an unbounded AX IPC call and
        // removes the extra round trip from the common visible-item path.
        if mouseButton == .left,
           item.windowID != nil,
           layoutManager.isVisible(item) {
            activator.activateMovedItem(item, mouseButton: .left) { [weak self] success in
                guard let self else { return }
                guard success else {
                    self.retryActivation(item, mouseButton: .left, retryCount: retryCount, message: "Unable to activate \(item.tooltip).")
                    return
                }
                self.rehideAfterNextUserClick(item)
                self.finishActivation()
            }
            return
        }
        // An AX element can go stale after a status-item rebuild. Refresh it
        // only when we already had an AX-backed item; window-backed items skip
        // this expensive full-tree walk and use the direct per-process path
        // after their short reveal.
        if mouseButton == .left, item.axElement != nil, activateUsingFreshAccessibility(item) {
            finishActivation()
            return
        }
        if mouseButton == .left,
           item.windowID == nil,
           activator.activateViaAccessibilityHitTest(item) {
            finishActivation()
            return
        }
        if mouseButton == .right, layoutManager.isVisible(item) {
            let pointer = layoutManager.currentPointerLocation()
            activator.activateRightClick(item) { [weak self] success in
                guard let self else { return }
                self.layoutManager.restorePointerLocation(pointer)
                guard success else {
                    self.retryActivation(item, mouseButton: mouseButton, retryCount: retryCount, message: "Unable to open the context menu for \(item.tooltip).")
                    return
                }
                self.finishActivation()
            }
            return
        }
        // Preserve the real pointer across the complete reveal → click →
        // rehide transaction. Each synthetic event can otherwise overwrite
        // WindowServer's logical location before the next phase starts.
        activateByTemporarilyRevealing(item, mouseButton: mouseButton, restoreCursorLocation: layoutManager.currentPointerLocation(), retryCount: retryCount)
    }

    private func activateUsingFreshAccessibility(_ item: MenuBarItem) -> Bool {
        guard let fresh = scanner.refreshAccessibility(for: item), fresh.supportsPress else { return false }
        item.axElement = fresh.element
        item.supportsPressAction = true
        return activator.activateDirectly(item)
    }

    private func activateByTemporarilyRevealing(_ item: MenuBarItem, mouseButton: CGMouseButton, restoreCursorLocation: CGPoint?, retryCount: Int) {
        layoutManager.reveal(item, restoreCursorLocation: restoreCursorLocation) { [weak self] moved in
            guard let self else { return }
            guard moved else {
                self.retryActivation(item, mouseButton: mouseButton, retryCount: retryCount, message: "Unable to temporarily show \(item.tooltip).")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self else { return }
                // Once the item is visible again, resolve the current
                // WindowServer element instead of relying on the stale AX
                // reference captured during scanning. This is both faster
                // and safer than injecting a mouse event into Control Center.
                if mouseButton == .left,
                   self.itemUsesAccessibility(item),
                   self.activator.activateDirectly(item)
                    || self.activator.activateViaAccessibilityHitTest(item) {
                    self.rehideAfterNextUserClick(item)
                    self.finishActivation()
                    return
                }
                self.activator.activateMovedItem(item, mouseButton: mouseButton) { [weak self] success in
                    guard let self else { return }
                    self.layoutManager.restorePointerLocation(restoreCursorLocation)
                    guard success else {
                        self.layoutManager.rehide(item, restoreCursorLocation: restoreCursorLocation)
                        self.retryActivation(item, mouseButton: mouseButton, retryCount: retryCount, message: "Unable to activate \(item.tooltip).")
                        return
                    }
                    self.rehideAfterNextUserClick(item)
                    self.finishActivation()
                }
            }
        }
    }

    private func retryActivation(_ item: MenuBarItem, mouseButton: CGMouseButton, retryCount: Int, message: String) {
        guard retryCount < 1 else {
            lastActivationError = message
            finishActivation()
            return
        }
        finishActivation()
        // Control Center can replace a status-item window between the scan
        // and the click. A single fresh pass handles that race without
        // returning to the old multi-second activation transaction.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.activate(item, mouseButton: mouseButton, retryCount: retryCount + 1)
        }
    }

    private func finishActivation() { activatingItemID = nil }

    private func itemUsesAccessibility(_ item: MenuBarItem) -> Bool {
        item.windowID == nil
    }

    private func rehideAfterNextUserClick(_ item: MenuBarItem) {
        pendingRehideItem = item

        // Popovers do not emit NSMenu tracking notifications. Install this
        // monitor after the originating click has completed. While an NSMenu
        // is tracking, menu-item clicks must be allowed to reach that menu;
        // the persistent didEndTracking observer above performs the rehide
        // after the menu has actually closed. Foreign-process menus are
        // handled by the bounded window-presence check below.
        if let menuDismissMonitor { NSEvent.removeMonitor(menuDismissMonitor) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, self.pendingRehideItem != nil else { return }
            self.menuDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in
                    guard let self,
                          let item = self.pendingRehideItem,
                          self.menuTrackingDepth == 0 else { return }
                    // Check after the click has had time to open or dismiss a
                    // foreign-process menu. Never use the stale hardware
                    // pointer location as the deciding signal: synthetic
                    // activation events can leave it behind the menu item.
                    self.scheduleTransientDismissCheck(for: item)
                }
            }
        }

        // Some Control Center modules use a popover instead of NSMenu and do
        // not emit didEndTracking. Keep the item visible long enough for the
        // popover to open, then use a bounded fallback to restore the layout.
        rehideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let item = self.pendingRehideItem else { return }
            if self.hasVisibleTransientWindow(for: item) {
                self.scheduleTransientDismissCheck(for: item)
            } else {
                self.rehidePendingItem()
            }
        }
        rehideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
    }

    private func rehidePendingItem() {
        guard let item = pendingRehideItem else { return }
        pendingRehideItem = nil
        rehideWorkItem?.cancel()
        rehideWorkItem = nil
        transientDismissCheck?.cancel()
        transientDismissCheck = nil
        if let menuDismissMonitor {
            NSEvent.removeMonitor(menuDismissMonitor)
            self.menuDismissMonitor = nil
        }
        // Capture the pointer inside the actual menu/popover interaction. The
        // original panel position is stale by this point and restoring it
        // would reopen hover UI or leave other apps with a false hit target.
        layoutManager.rehide(item, restoreCursorLocation: nil)
    }

    private func cancelPendingRehide() {
        rehideWorkItem?.cancel()
        rehideWorkItem = nil
        transientDismissCheck?.cancel()
        transientDismissCheck = nil
        if let menuDismissMonitor {
            NSEvent.removeMonitor(menuDismissMonitor)
            self.menuDismissMonitor = nil
        }
        pendingRehideItem = nil
    }

    /// Control Center's menus are foreign-process windows and never produce
    /// our NSMenu tracking notifications. Poll only after a user click rather
    /// than while idle, so a menu item click is never followed by an immediate
    /// rehide that dismisses the menu itself.
    private func hasVisibleTransientWindow(for item: MenuBarItem) -> Bool {
        guard let ownerPID = item.ownerPID else { return false }
        let protectedOwner = item.bundleIdentifier == "Control Center" ||
            NSRunningApplication(processIdentifier: ownerPID)?.bundleIdentifier == "com.apple.controlcenter"
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { info in
            guard let windowPID = info[kCGWindowOwnerPID as String] as? Int,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
            let windowOwner = (info[kCGWindowOwnerName as String] as? String) ?? ""
            let sameOwner = pid_t(windowPID) == ownerPID || (protectedOwner && windowOwner == "Control Center")
            guard sameOwner else { return false }
            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0
            guard layer > 25 || (layer == 25 && height > 40) else { return false }
            return width > 4 && height > 4
        }
    }

    private func scheduleTransientDismissCheck(for item: MenuBarItem, attempt: Int = 0) {
        guard pendingRehideItem?.id == item.id else { return }
        transientDismissCheck?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.pendingRehideItem?.id == item.id else { return }
            if self.hasVisibleTransientWindow(for: item) {
                // Keep a low-duty check alive for menus that remain open
                // beyond the normal eight-second safety window.
                self.scheduleTransientDismissCheck(for: item, attempt: min(attempt + 1, 80))
            } else {
                self.rehidePendingItem()
            }
        }
        transientDismissCheck = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
}
