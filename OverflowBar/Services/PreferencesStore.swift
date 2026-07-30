import Foundation

final class PreferencesStore {
    private let selectedKeys = "selectedMenuBarItems"
    private let knownItemsKey = "knownMenuBarItemsV1"
    private let layoutManagementKey = "layoutManagementEnabled"
    private let defaultLayoutKey = "didApplyDefaultLayoutV4"
    // UserDefaults survives replacing the application bundle. Keep completion
    // per release so a newly installed version presents its welcome/setup flow
    // instead of inheriting an unrelated older build's marker.
    private var onboardingCompletedKey: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        return "hasCompletedOnboarding.\(version)"
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func isSelected(_ id: String) -> Bool { Set(defaults.stringArray(forKey: selectedKeys) ?? []).contains(id) }

    var selectedIDs: Set<String> { Set(defaults.stringArray(forKey: selectedKeys) ?? []) }
    var knownItemIDs: Set<String> { Set(defaults.stringArray(forKey: knownItemsKey) ?? []) }
    var layoutManagementEnabled: Bool {
        get { defaults.bool(forKey: layoutManagementKey) }
        set { defaults.set(newValue, forKey: layoutManagementKey) }
    }
    var didApplyDefaultLayout: Bool {
        get { defaults.bool(forKey: defaultLayoutKey) }
        set { defaults.set(newValue, forKey: defaultLayoutKey) }
    }
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: onboardingCompletedKey) }
        set { defaults.set(newValue, forKey: onboardingCompletedKey) }
    }

    func saveSelected(_ ids: Set<String>) { defaults.set(Array(ids), forKey: selectedKeys) }
    func saveKnownItems(_ ids: Set<String>) { defaults.set(Array(ids), forKey: knownItemsKey) }
}
