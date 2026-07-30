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
    private var rehideMonitor: Any?
    private var rehideWorkItem: DispatchWorkItem?
    private var refreshWorkItem: DispatchWorkItem?
    private var monitorTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lastWindowSignature = Set<String>()
    private var captureGeneration = 0
    private var isRefreshing = false
    private var refreshAgain = false
    var onImagesReady: (() -> Void)?
    var onLayoutStateChanged: (() -> Void)?

    init() {
        layoutManager = MenuBarLayoutManager(preferences: preferences)
        layoutManagementEnabled = layoutManager.isEnabled
    }

    deinit {
        monitorTimer?.invalidate()
        refreshWorkItem?.cancel()
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
                self?.scheduleRefresh(after: 0, reason: "startup retry")
            }
        }
    }

    func refresh() {
        guard !isRefreshing else { refreshAgain = true; return }
        isRefreshing = true
        let previousByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let previousByWindowID = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.windowID.map { ($0, item) }
        })
        let knownBefore = preferences.knownItemIDs
        let selectedBefore = preferences.selectedIDs
        let scanned = scanner.scan(selectedIDs: selectedBefore)
        let currentIDs = Set(scanned.filter { !$0.isProtectedSystemItem }.map(\.id))

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
            for item in scanned where newIDs.contains(item.id) { item.isSelected = true }
            if !newIDs.isEmpty {
                logger.info("Discovered and selected \(newIDs.count, privacy: .public) new menu bar item(s)")
            }
        }

        items = scanned
        preferences.saveKnownItems(knownBefore.union(currentIDs))
        let selectedNow = Set(scanned.filter(\.isSelected).map(\.id))
        preferences.saveSelected(selectedBefore.subtracting(currentIDs).union(selectedNow))
        lastWindowSignature = scanner.windowSignature()
        isRefreshing = false
        onLayoutStateChanged?()

        refreshImages(for: items) { [weak self] in
            guard let self else { return }
            self.onLayoutStateChanged?()
            self.onImagesReady?()
            if self.refreshAgain {
                self.refreshAgain = false
                self.scheduleRefresh(after: 0.2, reason: "coalesced refresh")
            }
        }
    }

    func refreshIfWindowSetChanged() {
        let signature = scanner.windowSignature()
        guard signature != lastWindowSignature else { return }
        lastWindowSignature = signature
        scheduleRefresh(after: 0.4, reason: "menu bar window set changed")
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
        let currentIDs = Set(items.map(\.id))
        let retainedMissing = preferences.selectedIDs.subtracting(currentIDs)
        preferences.saveSelected(retainedMissing.union(items.filter(\.isSelected).map(\.id)))
        if selected { applyLayout() } else { layoutManager.show(item) }
        onLayoutStateChanged?()
    }

    func selectAll(_ selected: Bool) {
        for item in items where !item.isProtectedSystemItem { item.isSelected = selected }
        preferences.saveSelected(Set(items.filter(\.isSelected).map(\.id)))
        objectWillChange.send()
        if selected { applyLayout() } else { restoreLayout() }
        onLayoutStateChanged?()
    }

    func refreshImages(for target: [MenuBarItem]? = nil, completion: (() -> Void)? = nil) {
        captureGeneration += 1
        let generation = captureGeneration
        let candidates = target ?? selectedItems
        Task { [weak self] in
            guard let self else { return }
            let images = await self.captureService.capture(candidates)
            guard generation == self.captureGeneration else { return }
            for (id, image) in images {
                self.items.first(where: { $0.id == id })?.iconImage = image
            }
            let availableCount = candidates.filter { candidate in
                self.items.first(where: { $0.id == candidate.id })?.displayImage != nil
            }.count
            self.iconCaptureMessage = candidates.isEmpty
                ? nil
                : "Loaded \(availableCount) of \(candidates.count) menu bar icons."
            self.isReadyForManagedLayout = self.selectedItems.allSatisfy { $0.displayImage != nil }
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
        layoutOperationMessage = "Applying hidden layout…"
        layoutManager.hide(selectedItems, relativeTo: controlItemFrame ?? .zero) { [weak self] count in
            self?.layoutOperationMessage = count > 0 ? "Hidden layout updated (\(count) moved)." : "No menu bar items needed moving."
        }
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
        if activateUsingFreshAccessibility(item) {
            finishActivation()
            return
        }
        activateByTemporarilyRevealing(item)
    }

    private func activateUsingFreshAccessibility(_ item: MenuBarItem) -> Bool {
        guard let fresh = scanner.refreshAccessibility(for: item), fresh.supportsPress else { return false }
        item.axElement = fresh.element
        item.supportsPressAction = true
        return activator.activateDirectly(item)
    }

    private func activateByTemporarilyRevealing(_ item: MenuBarItem) {
        layoutManager.reveal(item) { [weak self] moved in
            guard let self else { return }
            guard moved else {
                self.lastActivationError = "Unable to temporarily show \(item.tooltip)."
                self.finishActivation()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self else { return }
                if self.activateUsingFreshAccessibility(item) {
                    self.rehideAfterNextUserClick(item)
                    self.finishActivation()
                    return
                }
                self.activator.activateMovedItem(item) { [weak self] success in
                    guard let self else { return }
                    guard success else {
                        self.layoutManager.rehide(item)
                        self.lastActivationError = "Unable to activate \(item.tooltip)."
                        self.finishActivation()
                        return
                    }
                    self.rehideAfterNextUserClick(item)
                    self.finishActivation()
                }
            }
        }
    }

    private func finishActivation() { activatingItemID = nil }

    private func rehideAfterNextUserClick(_ item: MenuBarItem) {
        rehideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp, .otherMouseUp]) { [weak self] event in
            let cursorLocation = event.cgEvent?.location
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.finishTemporaryItem(item, restoreCursorLocation: cursorLocation)
            }
        }
        let workItem = DispatchWorkItem { [weak self] in self?.finishTemporaryItem(item) }
        rehideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: workItem)
    }

    private func finishTemporaryItem(_ item: MenuBarItem, restoreCursorLocation: CGPoint? = nil) {
        cancelPendingRehide()
        layoutManager.rehide(item, restoreCursorLocation: restoreCursorLocation)
    }

    private func cancelPendingRehide() {
        if let rehideMonitor { NSEvent.removeMonitor(rehideMonitor); self.rehideMonitor = nil }
        rehideWorkItem?.cancel()
        rehideWorkItem = nil
    }
}
