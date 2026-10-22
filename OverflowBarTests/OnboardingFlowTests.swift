import XCTest
@testable import OverflowBar

final class OnboardingFlowTests: XCTestCase {
    func testFlowMovesForwardAndBackAcrossThreeSteps() {
        var flow = OnboardingFlowState(selectedIDs: [])

        XCTAssertEqual(flow.step, .welcome)
        flow.advance()
        XCTAssertEqual(flow.step, .permissions)
        flow.advance()
        XCTAssertEqual(flow.step, .chooseIcons)
        flow.goBack()
        XCTAssertEqual(flow.step, .permissions)
    }

    func testDraftRetainsExistingOrderAndAddsNewSelection() {
        var flow = OnboardingFlowState(selectedIDs: ["first", "second"])
        flow.setSelected("third", selected: true)
        flow.setSelected("second", selected: false)

        XCTAssertEqual(flow.selectedIDs, ["first", "third"])
        XCTAssertEqual(flow.completion(accessibilityGranted: true), .finish(selectedIDs: ["first", "third"], hideSelectedIcons: true))
    }

    func testExistingSelectionCannotBeFinishedWithoutAccessibility() {
        let flow = OnboardingFlowState(selectedIDs: ["previously-hidden"])

        XCTAssertNil(flow.completion(accessibilityGranted: false))
        XCTAssertEqual(flow.setUpLater(), .setUpLater)
        XCTAssertEqual(flow.selectedIDs, ["previously-hidden"])
    }

    func testNoSelectionCanFinishWithoutHidingIcons() {
        let flow = OnboardingFlowState(selectedIDs: [])

        XCTAssertEqual(flow.completion(accessibilityGranted: false), .finish(selectedIDs: [], hideSelectedIcons: false))
    }

    @MainActor
    func testFinishSavesSelectionWithoutEnablingHiding() {
        let suite = "OverflowBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        let store = MenuBarItemStore(preferences: preferences)

        OnboardingCompletion.finish(selectedIDs: ["menu-item-1", "menu-item-2"], hideSelectedIcons: false).apply(to: store)

        XCTAssertEqual(preferences.selectedNativeItems, ["menu-item-1", "menu-item-2"])
        XCTAssertFalse(preferences.layoutManagementEnabled)
        XCTAssertFalse(store.layoutManagementEnabled)
    }

    @MainActor
    func testSetUpLaterLeavesSavedSelectionAndVisibilityUnchanged() {
        let suite = "OverflowBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        preferences.selectedNativeItems = ["previously-hidden"]
        preferences.layoutManagementEnabled = true
        let store = MenuBarItemStore(preferences: preferences)

        OnboardingCompletion.setUpLater.apply(to: store)

        XCTAssertEqual(preferences.selectedNativeItems, ["previously-hidden"])
        XCTAssertTrue(preferences.layoutManagementEnabled)
        XCTAssertTrue(store.layoutManagementEnabled)
    }
}
