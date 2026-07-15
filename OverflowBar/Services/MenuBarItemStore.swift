import AppKit
import Combine

@MainActor
final class MenuBarItemStore: ObservableObject {
    @Published private(set) var items: [MenuBarItem] = []
    @Published var lastActivationError: String?
    @Published private(set) var layoutManagementEnabled = false
    private let preferences = PreferencesStore()
    private let scanner = MenuBarScanner()
    private let captureService = MenuBarCaptureService()
    private let activator = MenuBarItemActivator()
    private let layoutManager: MenuBarLayoutManager
    private var controlItemFrame: CGRect?
    private var rehideMonitor: Any?
    private var rehideWorkItem: DispatchWorkItem?
    var onImagesReady: (() -> Void)?

    init() {
        layoutManager = MenuBarLayoutManager(preferences: preferences)
        layoutManagementEnabled = layoutManager.isEnabled
    }

    var selectedItems: [MenuBarItem] { items.filter(\.isSelected) }

    func refresh() {
        let isRescan = !items.isEmpty
        let selectedWindowIDs = Set(items.filter(\.isSelected).compactMap(\.windowID))
        let selected = isRescan
            ? Set(items.filter { $0.isSelected && $0.windowID == nil }.map(\.id))
            : preferences.selectedIDs
        let scanned = scanner.scan(selectedIDs: selected)
        if isRescan {
            for item in scanned where item.windowID != nil {
                item.isSelected = item.windowID.map(selectedWindowIDs.contains) == true
            }
        }
        items = scanned
        if !preferences.didApplyDefaultLayout, !items.isEmpty {
            items.forEach { $0.isSelected = true }
            preferences.saveSelected(Set(items.map(\.id)))
            layoutManager.isEnabled = true
            layoutManagementEnabled = true
            preferences.didApplyDefaultLayout = true
        }
        refreshImages(for: items) { [weak self] in self?.onImagesReady?() }
    }

    func setSelected(_ item: MenuBarItem, selected: Bool) {
        item.isSelected = selected
        objectWillChange.send()
        preferences.saveSelected(Set(items.filter(\.isSelected).map(\.id)))
        if selected { applyLayout() } else { layoutManager.show(item) }
    }

    func selectAll(_ selected: Bool) {
        for item in items { item.isSelected = selected }
        preferences.saveSelected(Set(items.filter(\.isSelected).map(\.id)))
        objectWillChange.send()
        if selected { applyLayout() } else { restoreLayout() }
    }

    func refreshImages(for target: [MenuBarItem]? = nil, completion: (() -> Void)? = nil) {
        let candidates = target ?? selectedItems
        Task { [weak self] in
            guard let self else { return }
            let images = await self.captureService.capture(candidates)
            for (id, image) in images {
                self.items.first(where: { $0.id == id })?.iconImage = image
            }
            self.objectWillChange.send()
            completion?()
        }
    }

    func updateControlItemFrame(_ frame: CGRect) { controlItemFrame = frame }

    func setLayoutManagementEnabled(_ enabled: Bool) {
        layoutManager.isEnabled = enabled
        layoutManagementEnabled = enabled
        if enabled { applyLayout() } else { restoreLayout() }
    }

    func applyLayout() {
        layoutManager.hide(selectedItems, relativeTo: controlItemFrame ?? .zero)
    }

    func restoreLayout() {
        guard let controlItemFrame else { return }
        layoutManager.restore(selectedItems, relativeTo: controlItemFrame)
    }

    func restoreProtectedSystemItems() {
        layoutManager.restoreProtectedSystemItems()
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
        rehideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.finishTemporaryItem(item) }
        }
        let workItem = DispatchWorkItem { [weak self] in self?.finishTemporaryItem(item) }
        rehideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: workItem)
    }

    private func finishTemporaryItem(_ item: MenuBarItem) {
        cancelPendingRehide()
        layoutManager.rehide(item)
    }

    private func cancelPendingRehide() {
        if let rehideMonitor { NSEvent.removeMonitor(rehideMonitor); self.rehideMonitor = nil }
        rehideWorkItem?.cancel()
        rehideWorkItem = nil
    }
}
