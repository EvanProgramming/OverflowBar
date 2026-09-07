import Foundation
import CoreGraphics

final class PreferencesStore {
    private let selectedKeys = "selectedMenuBarItems"
    private let knownItemsKey = "knownMenuBarItemsV1"
    private let knownWindowIDsKey = "knownMenuBarWindowIDsV1"
    private let deselectedItemsKey = "deselectedMenuBarItemsV1"
    private let layoutManagementKey = "layoutManagementEnabled"
    private let defaultLayoutKey = "didApplyDefaultLayoutV4"
    private let migrationKey = "didMigrateLegacyPreferencesV1"
    private let legacyBundleIdentifiers = ["com.overflowbar.app", "com.overflowbar.mac26", "com.overflowbar.mac26.compat", "com.overflowbar.mac26.v2", "com.overflowbar.mac26.v3", "com.overflowbar.mac26.v4", "com.overflowbar.mac26.v5"]
    // UserDefaults survives replacing the application bundle. Keep completion
    // per release so a newly installed version presents its welcome/setup flow
    // instead of inheriting an unrelated older build's marker.
    private var onboardingCompletedKey: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        return "hasCompletedOnboarding.\(version)"
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // A bundle-identifier change is required to escape macOS 26's stale
        // Control Center blocked-host cache. Only user-owned choices are
        // migrated into the compatibility identity; WindowServer window IDs
        // and NSStatusItem placement keys are deliberately left behind.
        if defaults === UserDefaults.standard { migrateLegacyPreferencesIfNeeded() }
    }

    func isSelected(_ id: String) -> Bool { Set(defaults.stringArray(forKey: selectedKeys) ?? []).contains(id) }

    var selectedIDs: Set<String> { Set(defaults.stringArray(forKey: selectedKeys) ?? []) }
    var knownItemIDs: Set<String> { Set(defaults.stringArray(forKey: knownItemsKey) ?? []) }
    var knownWindowIDs: Set<CGWindowID> {
        Set((defaults.array(forKey: knownWindowIDsKey) as? [NSNumber] ?? []).map { CGWindowID($0.uint32Value) })
    }
    var deselectedItemIDs: Set<String> { Set(defaults.stringArray(forKey: deselectedItemsKey) ?? []) }
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
    func saveKnownWindowIDs(_ ids: Set<CGWindowID>) {
        defaults.set(ids.map { NSNumber(value: $0) }, forKey: knownWindowIDsKey)
    }
    func saveDeselectedItems(_ ids: Set<String>) { defaults.set(Array(ids), forKey: deselectedItemsKey) }

    private func migrateLegacyPreferencesIfNeeded() {
        guard defaults.object(forKey: migrationKey) == nil,
              let currentBundleIdentifier = Bundle.main.bundleIdentifier,
              !legacyBundleIdentifiers.contains(currentBundleIdentifier) else { return }

        var selected = selectedIDs
        var deselected = deselectedItemIDs
        var didApplyDefaultLayout = defaults.object(forKey: defaultLayoutKey) != nil
            ? self.didApplyDefaultLayout
            : false
        var layoutManagementEnabled = defaults.object(forKey: layoutManagementKey) != nil
            ? self.layoutManagementEnabled
            : false
        var completedOnboarding = defaults.object(forKey: onboardingCompletedKey) != nil
            ? hasCompletedOnboarding
            : false

        for identifier in legacyBundleIdentifiers {
            guard let legacy = UserDefaults(suiteName: identifier) else { continue }
            selected.formUnion(legacy.stringArray(forKey: selectedKeys) ?? [])
            deselected.formUnion(legacy.stringArray(forKey: deselectedItemsKey) ?? [])
            if let value = legacy.object(forKey: defaultLayoutKey) as? Bool { didApplyDefaultLayout = value }
            if let value = legacy.object(forKey: layoutManagementKey) as? Bool { layoutManagementEnabled = value }
            if legacy.dictionaryRepresentation().contains(where: { key, value in
                key.hasPrefix("hasCompletedOnboarding.") && (value as? Bool) == true
            }) {
                completedOnboarding = true
            }
        }

        if !selected.isEmpty { saveSelected(selected) }
        if !deselected.isEmpty { saveDeselectedItems(deselected) }
        defaults.set(didApplyDefaultLayout, forKey: defaultLayoutKey)
        defaults.set(layoutManagementEnabled, forKey: layoutManagementKey)
        if completedOnboarding { hasCompletedOnboarding = true }
        defaults.set(true, forKey: migrationKey)
    }

    /// Clears layout discovery state left by an older build or a diagnostic
    /// run while keeping permissions, login behavior, and onboarding intact.
    func resetLayoutState() {
        defaults.removeObject(forKey: selectedKeys)
        defaults.removeObject(forKey: knownItemsKey)
        defaults.removeObject(forKey: knownWindowIDsKey)
        defaults.removeObject(forKey: deselectedItemsKey)
        for name in ["OverflowBarControlItem", "OverflowBarHiddenSection"] {
            defaults.removeObject(forKey: "NSStatusItem Preferred Position \(name)")
            defaults.removeObject(forKey: "NSStatusItem Visible \(name)")
            defaults.removeObject(forKey: "NSStatusItem Preferred Position \(name)Mac26")
            defaults.removeObject(forKey: "NSStatusItem Visible \(name)Mac26")
        }
        defaults.set(false, forKey: layoutManagementKey)
        // Treat the clean, visible state as an already-established default so
        // the next scan does not select every discovered item again.
        defaults.set(true, forKey: defaultLayoutKey)
    }
}
