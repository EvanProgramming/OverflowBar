import Foundation

final class PreferencesStore {
    private let selectedKeys = "selectedMenuBarItems"
    private let layoutManagementKey = "layoutManagementEnabled"
    private let defaultLayoutKey = "didApplyDefaultLayoutV4"
    // V1 was stored in UserDefaults, which survives replacing the app bundle.
    // Use a new completion marker so installations of this build present setup
    // instead of inheriting a stale completion state from an older copy.
    private let onboardingCompletedKey = "hasCompletedOnboardingV2"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func isSelected(_ id: String) -> Bool { Set(defaults.stringArray(forKey: selectedKeys) ?? []).contains(id) }

    var selectedIDs: Set<String> { Set(defaults.stringArray(forKey: selectedKeys) ?? []) }
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
}
