import XCTest
@testable import OverflowBar

final class PreferenceMigrationTests: XCTestCase {
    func testMigrationRevealsGroupAndPreservesPlacementAndUserSettings() {
        let suite = "OverflowBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "hasCompletedOnboarding.1.0.19")
        defaults.set(true, forKey: "layoutManagementEnabled")
        defaults.set(["old-selected-icon"], forKey: "selectedMenuBarItems")
        defaults.set(42.0, forKey: "NSStatusItem Preferred Position OverflowBarControlItem")
        defaults.set(false, forKey: "hoverRevealEnabled")
        defaults.set(true, forKey: "SUAutomaticallyUpdate")
        defaults.set(true, forKey: "SMLoginItemEnabled")

        let store = PreferencesStore(defaults: defaults)
        store.migrateToManualGrouping()

        XCTAssertFalse(store.layoutManagementEnabled)
        XCTAssertNil(defaults.object(forKey: "selectedMenuBarItems"))
        XCTAssertTrue(store.needsManualGroupingExplanation)
        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertEqual(defaults.double(forKey: "NSStatusItem Preferred Position OverflowBarControlItem"), 42)
        XCTAssertFalse(defaults.bool(forKey: "hoverRevealEnabled"))
        XCTAssertTrue(defaults.bool(forKey: "SUAutomaticallyUpdate"))
        XCTAssertTrue(defaults.bool(forKey: "SMLoginItemEnabled"))
    }
}
