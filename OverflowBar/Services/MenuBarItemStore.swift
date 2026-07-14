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

    init() {
        layoutManager = MenuBarLayoutManager(preferences: preferences)
        layoutManagementEnabled = layoutManager.isEnabled
    }

    var selectedItems: [MenuBarItem] { items.filter(\.isSelected) }

    func refresh() {
        let selected = Set(items.filter(\.isSelected).map(\.id)).union(preferences.selectedIDs)
        items = scanner.scan(selectedIDs: selected)
        if !preferences.didApplyDefaultLayout, !items.isEmpty {
            items.forEach { $0.isSelected = true }
            preferences.saveSelected(Set(items.map(\.id)))
            layoutManager.isEnabled = true
            layoutManagementEnabled = true
            preferences.didApplyDefaultLayout = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.applyLayout() }
        }
        refreshImages(for: items)
    }

    func setSelected(_ item: MenuBarItem, selected: Bool) {
        item.isSelected = selected
        objectWillChange.send()
        preferences.saveSelected(Set(items.filter(\.isSelected).map(\.id)))
        applyLayout()
    }

    func selectAll(_ selected: Bool) { for item in items { item.isSelected = selected }; preferences.saveSelected(Set(items.filter(\.isSelected).map(\.id))); objectWillChange.send(); applyLayout() }

    func refreshImages(for target: [MenuBarItem]? = nil) {
        let candidates = target ?? selectedItems
        Task { [weak self] in
            guard let self else { return }
            for item in candidates {
                let image = await self.captureService.capture(item)
                self.items.first(where: { $0.id == item.id })?.iconImage = image
            }
            self.objectWillChange.send()
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

    func activate(_ item: MenuBarItem) {
        if let controlItemFrame { layoutManager.reveal(item, relativeTo: controlItemFrame) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, !self.activator.activate(item) else { return }
            self.lastActivationError = "Unable to activate \(item.tooltip)."
        }
    }
}
