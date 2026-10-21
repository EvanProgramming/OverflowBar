import Foundation

final class PreferencesStore {
    private let layoutManagementKey = "layoutManagementEnabled"
    private let migrationKey = "didMigrateLegacyPreferencesV1"
    private let v15MigrationKey = "didMigrateManualGroupingV15"
    private let explanationKey = "showManualGroupingExplanationV15"
    private let legacyBundleIdentifiers = ["com.overflowbar.app", "com.overflowbar.mac26", "com.overflowbar.mac26.compat", "com.overflowbar.mac26.v2", "com.overflowbar.mac26.v3", "com.overflowbar.mac26.v4", "com.overflowbar.mac26.v5"]
    private let defaults: UserDefaults

    private var onboardingCompletedKey: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        return "hasCompletedOnboarding.\(version)"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults === UserDefaults.standard {
            migrateLegacyOnboarding()
            migrateToNativeEngine()
        }
    }

    var layoutManagementEnabled: Bool {
        get { defaults.bool(forKey: layoutManagementKey) }
        set { defaults.set(newValue, forKey: layoutManagementKey) }
    }

    var needsManualGroupingExplanation: Bool {
        get { defaults.bool(forKey: explanationKey) }
        set { defaults.set(newValue, forKey: explanationKey) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: onboardingCompletedKey) }
        set { defaults.set(newValue, forKey: onboardingCompletedKey) }
    }

    private func migrateLegacyOnboarding() {
        guard defaults.object(forKey: migrationKey) == nil,
              let bundleIdentifier = Bundle.main.bundleIdentifier,
              !legacyBundleIdentifiers.contains(bundleIdentifier) else { return }
        for identifier in legacyBundleIdentifiers {
            guard let legacy = UserDefaults(suiteName: identifier),
                  legacy.dictionaryRepresentation().contains(where: { key, value in
                      key.hasPrefix("hasCompletedOnboarding.") && (value as? Bool) == true
                  }) else { continue }
            hasCompletedOnboarding = true
            break
        }
        defaults.set(true, forKey: migrationKey)
    }

    func migrateToManualGrouping() {
        guard !defaults.bool(forKey: v15MigrationKey) else { return }
        let obsoleteKeys = ["selectedMenuBarItems", "knownMenuBarItemsV1", "knownMenuBarWindowIDsV1", "deselectedMenuBarItemsV1", "didApplyDefaultLayoutV4"]
        let hadPriorSetup = defaults.dictionaryRepresentation().contains { key, value in
            key.hasPrefix("hasCompletedOnboarding.") && (value as? Bool) == true
        }
        obsoleteKeys.forEach(defaults.removeObject(forKey:))
        defaults.set(false, forKey: layoutManagementKey)
        defaults.set(true, forKey: v15MigrationKey)
        if hadPriorSetup {
            hasCompletedOnboarding = true
            needsManualGroupingExplanation = true
        }
    }

    var selectedNativeItems: [String] {
        get { defaults.stringArray(forKey: "selectedNativeItemsV15") ?? [] }
        set { defaults.set(newValue, forKey: "selectedNativeItemsV15") }
    }
    var verifiedNativeOrder: [String] {
        get { defaults.stringArray(forKey: "verifiedNativeOrderV15") ?? [] }
        set { defaults.set(newValue, forKey: "verifiedNativeOrderV15") }
    }
    var nativeSelectionMigrationPending: Bool { !defaults.bool(forKey: "didResolveNativeSelectionV15") }
    func importNativeSelection(resolvedIDs: Set<String>, observedGroup: [String]) {
        guard nativeSelectionMigrationPending, selectedNativeItems.isEmpty else { return }
        let legacy = defaults.stringArray(forKey: "selectedMenuBarItems")
        selectedNativeItems = (legacy ?? observedGroup).filter { resolvedIDs.contains($0) }
        defaults.set(true, forKey: "didResolveNativeSelectionV15")
    }
    func migrateToNativeEngine() {
        guard !defaults.bool(forKey: "didMigrateNativeEngineV15") else { return }
        defaults.set(false, forKey: layoutManagementKey)
        defaults.set(true, forKey: "didMigrateNativeEngineV15")
        defaults.set(false, forKey: explanationKey)
        defaults.set(false, forKey: onboardingCompletedKey)
    }

    func resetLayoutState() {
        ["selectedMenuBarItems", "knownMenuBarItemsV1", "knownMenuBarWindowIDsV1", "deselectedMenuBarItemsV1"].forEach(defaults.removeObject(forKey:))
        defaults.set(false, forKey: layoutManagementKey)
    }
}
