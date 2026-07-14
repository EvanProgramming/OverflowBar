import AppKit
import Combine

@MainActor
final class MenuBarItemStore: ObservableObject {
    @Published private(set) var items: [MenuBarItem] = []
    @Published var lastActivationError: String?
    private let preferences = PreferencesStore()
    private let scanner = MenuBarScanner()
    private let captureService = MenuBarCaptureService()
    private let activator = MenuBarItemActivator()

    var selectedItems: [MenuBarItem] { items.filter(\.isSelected) }

    func refresh() {
        let selected = Set(items.filter(\.isSelected).map(\.id)).union(preferences.selectedIDs)
        items = scanner.scan(selectedIDs: selected)
        refreshImages(for: items)
    }

    func setSelected(_ item: MenuBarItem, selected: Bool) {
        item.isSelected = selected
        objectWillChange.send()
        preferences.saveSelected(Set(items.filter(\.isSelected).map(\.id)))
    }

    func selectAll(_ selected: Bool) { for item in items { item.isSelected = selected }; preferences.saveSelected(Set(items.filter(\.isSelected).map(\.id))); objectWillChange.send() }

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

    func activate(_ item: MenuBarItem) { if !activator.activate(item) { lastActivationError = "Unable to activate \(item.tooltip)." } }
}
