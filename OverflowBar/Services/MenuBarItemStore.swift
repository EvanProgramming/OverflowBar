import AppKit
import Combine

@MainActor
final class MenuBarItemStore: ObservableObject {
    @Published private(set) var items: [MenuBarItem] = []
    @Published var lastActivationError: String?
    @Published private(set) var layoutManagementEnabled = false
    @Published private(set) var layoutOperationMessage: String?
    @Published private(set) var iconCaptureMessage: String?
    @Published private(set) var isReadyForManagedLayout = false
    private let preferences = PreferencesStore()
    private let scanner = MenuBarScanner()
    private let captureService = MenuBarCaptureService()
    private let activator = MenuBarItemActivator()
    private let layoutManager: MenuBarLayoutManager
    private var controlItemFrame: CGRect?
    private var rehideMonitor: Any?
    private var rehideWorkItem: DispatchWorkItem?
    var onImagesReady: (() -> Void)?
    var onLayoutStateChanged: (() -> Void)?
    private var captureGeneration = 0

    init() {
        layoutManager = MenuBarLayoutManager(preferences: preferences)
        layoutManagementEnabled = layoutManager.isEnabled
    }

    var selectedItems: [MenuBarItem] { items.filter { $0.isSelected && !$0.isProtectedSystemItem } }

    func refresh() {
        let isRescan = !items.isEmpty
        let previousImages = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.windowID.flatMap { windowID in item.iconImage.map { (windowID, $0) } }
        })
        let selectedWindowIDs = Set(items.filter(\.isSelected).compactMap(\.windowID))
        let selected = isRescan
            ? Set(items.filter { $0.isSelected && $0.windowID == nil }.map(\.id))
            : preferences.selectedIDs
        let scanned = scanner.scan(selectedIDs: selected)
        for item in scanned {
            item.iconImage = item.windowID.flatMap { previousImages[$0] }
        }
        if isRescan {
            for item in scanned where item.windowID != nil {
                item.isSelected = item.windowID.map(selectedWindowIDs.contains) == true
            }
        }
        items = scanned
        if !preferences.didApplyDefaultLayout, !items.isEmpty {
            items.forEach { $0.isSelected = !$0.isProtectedSystemItem }
            preferences.saveSelected(Set(items.filter { !$0.isProtectedSystemItem }.map(\.id)))
            layoutManager.isEnabled = false
            layoutManagementEnabled = false
            preferences.didApplyDefaultLayout = true
        }
        onLayoutStateChanged?()
        refreshImages(for: items) { [weak self] in
            guard let self else { return }
            self.onLayoutStateChanged?()
            self.onImagesReady?()
        }
    }

    func setSelected(_ item: MenuBarItem, selected: Bool) {
        guard !item.isProtectedSystemItem else { return }
        item.isSelected = selected
        objectWillChange.send()
        preferences.saveSelected(Set(items.filter(\.isSelected).map(\.id)))
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
            self.iconCaptureMessage = candidates.isEmpty
                ? nil
                : "Captured \(images.count) of \(candidates.count) menu bar icons."
            self.isReadyForManagedLayout = self.selectedItems.allSatisfy { $0.iconImage != nil }
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
            layoutOperationMessage = "Hidden layout paused until every selected icon can be captured."
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
        cancelPendingRehide()
        if activator.canActivateDirectly(item) {
            activator.activateDirectly(item) { [weak self] success in
                guard let self else { return }
                if !success { self.activateByTemporarilyRevealing(item) }
            }
            return
        }
        activateByTemporarilyRevealing(item)
    }

    private func activateByTemporarilyRevealing(_ item: MenuBarItem) {
        layoutManager.reveal(item) { [weak self] moved in
            guard let self else { return }
            guard moved else {
                self.lastActivationError = "Unable to temporarily show \(item.tooltip)."
                return
            }
            self.activator.activateMovedItem(item) { [weak self] success in
                guard let self else { return }
                guard success else {
                    self.layoutManager.rehide(item)
                    self.lastActivationError = "Unable to activate \(item.tooltip)."
                    return
                }
                self.rehideAfterNextUserClick(item)
            }
        }
    }

    private func rehideAfterNextUserClick(_ item: MenuBarItem) {
        // Rehiding sends a short synthetic menu-bar drag. Waiting until the
        // user's click has finished keeps that synthetic input out of a window
        // drag that was started immediately after activating an item.
        rehideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp, .otherMouseUp]) { [weak self] event in
            let cursorLocation = event.cgEvent?.location
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.finishTemporaryItem(item, restoreCursorLocation: cursorLocation) }
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
