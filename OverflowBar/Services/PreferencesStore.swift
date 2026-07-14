import Foundation

final class PreferencesStore {
    private let selectedKeys = "selectedMenuBarItems"
    private let layoutManagementKey = "layoutManagementEnabled"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func isSelected(_ id: String) -> Bool { Set(defaults.stringArray(forKey: selectedKeys) ?? []).contains(id) }

    var selectedIDs: Set<String> { Set(defaults.stringArray(forKey: selectedKeys) ?? []) }
    var layoutManagementEnabled: Bool {
        get { defaults.bool(forKey: layoutManagementKey) }
        set { defaults.set(newValue, forKey: layoutManagementKey) }
    }

    func saveSelected(_ ids: Set<String>) { defaults.set(Array(ids), forKey: selectedKeys) }
}
