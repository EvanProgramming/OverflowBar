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
    private var layoutWorkItem: DispatchWorkItem?
    private var refreshWorkItem: DispatchWorkItem?
    private var monitorTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lastWindowSignature = Set<String>()
    private var captureGeneration = 0
    private var isRefreshing = false
    private var isCapturing = false
    private var refreshAgain = false
    private var isApplyingLayout = false
    private var shouldApplyLayoutAgain = false
    var onImagesReady: (() -> Void)?
    var onLayoutStateChanged: (() -> Void)?

    init() {
        layoutManager = MenuBarLayoutManager(preferences: preferences)
        layoutManagementEnabled = layoutManager.isEnabled
    }

    deinit {
        monitorTimer?.invalidate()
        refreshWorkItem?.cancel()
        layoutWorkItem?.cancel()
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
    }

    var selectedItems: [MenuBarItem] { items.filter { $0.isSelected && !$0.isProtectedSystemItem } }

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
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
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
        let currentIDs = Set(scanned.filter { !$0.isProtectedSystemItem }.map(\.id))
        let currentWindowIDs = Set(scanned.compactMap(\.windowID))
        let newWindowIDs = currentWindowIDs.subtracting(knownWindowIDsBefore)

        for item in scanned {
            let previous = previousByID[item.id] ?? item.windowID.flatMap { previousByWindowID[$0] }
            item.iconImage = previous?.iconImage
            if let previous { item.isSelected = previous.isSelected }
        }

        if !preferences.didApplyDefaultLayout, !scanned.isEmpty {
            scanned.forEach { $0.isSelected = !$0.isProtectedSystemItem }
            preferences.didApplyDefaultLayout = true
            layoutManager.isEnabled = false
            layoutManagementEnabled = false
        } else if !knownBefore.isEmpty, layoutManagementEnabled {
            let newIDs = currentIDs.subtracting(knownBefore)
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
        // Newly discovered items are selected and shown in the panel, but we
        // intentionally do not auto-run synthetic Command-drag layout here.
        // The user can apply the layout explicitly after confirming the list.

        let captureCandidates = preferences.hasCompletedOnboarding ? selectedItems : items
        refreshImages(for: captureCandidates) { [weak self] in
            guard let self else { return }
            self.onLayoutStateChanged?()
            self.onImagesReady?()
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
        guard !item.isProtectedSystemItem else { return }
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
        for item in items where !item.isProtectedSystemItem { item.isSelected = selected }
        if selected {
            preferences.saveDeselectedItems([])
        } else {
            preferences.saveDeselectedItems(Set(items.filter { !$0.isProtectedSystemItem }.map(\.id)))
        }
        preferences.saveSelected(Set(items.filter(\.isSelected).map(\.id)))
        objectWillChange.send()
        if selected { applyLayout() } else { restoreLayout() }
        onLayoutStateChanged?()
    }

    func refreshImages(for target: [MenuBarItem]? = nil, completion: (() -> Void)? = nil) {
        captureGeneration += 1
        let generation = captureGeneration
        let candidates = target ?? selectedItems
        isCapturing = true
        Task { [weak self] in
            guard let self else { return }
            let images = await self.captureService.capture(candidates)
            guard generation == self.captureGeneration else { return }
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
            restoreLayout()
        }
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
            scheduleLayoutRetry()
            return
        }
        isApplyingLayout = true
        layoutOperationMessage = "Applying hidden layout…"
        layoutManager.hide(selectedItems, relativeTo: controlItemFrame ?? .zero) { [weak self] count in
            guard let self else { return }
            self.isApplyingLayout = false
            self.layoutOperationMessage = count > 0 ? "Hidden layout updated (\(count) moved)." : "No menu bar items needed moving."
            if self.shouldApplyLayoutAgain {
                self.shouldApplyLayoutAgain = false
                self.scheduleLayoutRetry()
            }
        }
    }

    private func scheduleLayoutRetry() {
        layoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.applyLayout() }
        layoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
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
        restoreLayout(completion: completion)
    }

    func restoreProtectedSystemItems(completion: @escaping () -> Void = {}) {
        layoutManager.restoreProtectedSystemItems { _ in completion() }
    }

    func activate(_ item: MenuBarItem) {
        guard activatingItemID == nil else { return }
        cancelPendingRehide()
        activatingItemID = item.id
        lastActivationError = nil
        if activator.activateDirectly(item) {
            finishActivation()
            return
        }
        // An AX element can go stale after a status-item rebuild. Refresh it
        // only when we already had an AX-backed item; window-backed items skip
        // this expensive full-tree walk and use the direct per-process path
        // after their short reveal.
        if item.axElement != nil, activateUsingFreshAccessibility(item) {
            finishActivation()
            return
        }
        if activator.activateViaAccessibilityHitTest(item) {
            finishActivation()
            return
        }
        // Preserve the real pointer across the complete reveal → click →
        // rehide transaction. Each synthetic event can otherwise overwrite
        // WindowServer's logical location before the next phase starts.
        activateByTemporarilyRevealing(item, restoreCursorLocation: layoutManager.currentPointerLocation())
    }

    private func activateUsingFreshAccessibility(_ item: MenuBarItem) -> Bool {
        guard let fresh = scanner.refreshAccessibility(for: item), fresh.supportsPress else { return false }
        item.axElement = fresh.element
        item.supportsPressAction = true
        return activator.activateDirectly(item)
    }

    private func activateByTemporarilyRevealing(_ item: MenuBarItem, restoreCursorLocation: CGPoint?) {
        layoutManager.reveal(item, restoreCursorLocation: restoreCursorLocation) { [weak self] moved in
            guard let self else { return }
            guard moved else {
                self.lastActivationError = "Unable to temporarily show \(item.tooltip)."
                self.finishActivation()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self else { return }
                if self.activator.activateDirectly(item) {
                    self.rehideAfterNextUserClick(item, restoreCursorLocation: restoreCursorLocation)
                    self.finishActivation()
                    return
                }
                self.activator.activateMovedItem(item) { [weak self] success in
                    guard let self else { return }
                    self.layoutManager.restorePointerLocation(restoreCursorLocation)
                    guard success else {
                        self.layoutManager.rehide(item, restoreCursorLocation: restoreCursorLocation)
                        self.lastActivationError = "Unable to activate \(item.tooltip)."
                        self.finishActivation()
                        return
                    }
                    self.rehideAfterNextUserClick(item, restoreCursorLocation: restoreCursorLocation)
                    self.finishActivation()
                }
            }
        }
    }

    private func finishActivation() { activatingItemID = nil }

    private func rehideAfterNextUserClick(_ item: MenuBarItem, restoreCursorLocation: CGPoint?) {
        scheduleRehide(item, attempt: 0, restoreCursorLocation: restoreCursorLocation)
    }

    private func scheduleRehide(_ item: MenuBarItem, attempt: Int, restoreCursorLocation: CGPoint?) {
        rehideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.rehideWorkItem = nil
            self.layoutManager.rehide(item, restoreCursorLocation: restoreCursorLocation)
        }
        rehideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 0.08 : 0.08), execute: workItem)
    }

    private func cancelPendingRehide() {
        rehideWorkItem?.cancel()
        rehideWorkItem = nil
    }
}
