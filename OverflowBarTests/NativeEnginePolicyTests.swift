import XCTest
@testable import OverflowBar

final class NativeEnginePolicyTests: XCTestCase {
    func testCheckboxSelectionOrderDoesNotReorderAnAlreadyHiddenGroup() {
        let current = ["toggle", "vanishing", "popover", "menu", "divider", "arrow"]
        let desired = NativeLayoutPolicy.desiredOrder(current: current, selected: ["vanishing", "toggle", "popover", "menu"], divider: "divider")
        XCTAssertEqual(desired, current)
        XCTAssertTrue(NativeLayoutPolicy.moves(current: current, desired: desired).isEmpty)
    }
    func testIdentityMatchingRejectsAmbiguousAndCrossRowCandidates() {
        let window = CGRect(x: 120, y: 0, width: 22, height: 24)
        XCTAssertEqual(EngineIdentity.uniqueMatch(window: window, candidates: [window]), 0)
        XCTAssertNil(EngineIdentity.uniqueMatch(window: window, candidates: [window, window]))
        XCTAssertNil(EngineIdentity.uniqueMatch(window: window, candidates: [CGRect(x: 120, y: 900, width: 22, height: 24)]))
    }
    func testLayoutKeepsUnselectedOrderAndMovesOnlyOutOfPlaceItems() {
        let desired = NativeLayoutPolicy.desiredOrder(current: ["divider", "a", "b", "c"], selected: ["b"], divider: "divider")
        XCTAssertEqual(desired, ["b", "divider", "a", "c"])
        XCTAssertEqual(NativeLayoutPolicy.moves(current: ["divider", "a", "b", "c"], desired: desired).map(\.item), ["b"])
        XCTAssertTrue(NativeLayoutPolicy.moves(current: desired, desired: desired).isEmpty)
    }
    func testHiddenWindowRetainsDisplayAcrossSideBySideScreens() {
        let screens: [(UInt32, CGRect)] = [(1, CGRect(x: -1000, y: 0, width: 1000, height: 800)), (2, CGRect(x: 0, y: 0, width: 1000, height: 800))]
        XCTAssertEqual(EngineDisplayIdentity.resolve(frame: CGRect(x: -50, y: 0, width: 20, height: 24), displays: screens, cached: 2), 2)
        XCTAssertNil(EngineDisplayIdentity.resolve(frame: CGRect(x: -1200, y: 0, width: 20, height: 24), displays: screens, cached: nil))
        XCTAssertNil(EngineDisplayIdentity.resolve(frame: CGRect(x: 10, y: 0, width: 20, height: 24), displays: [screens[1], (3, screens[1].1)], cached: nil))
    }
    func testUnresolvedVisibleAnchorIsNeverPlannedAsMover() {
        let current = ["divider", "unknown", "selected", "arrow"]
        let desired = NativeLayoutPolicy.desiredOrder(current: current, selected: ["selected"], divider: "divider")
        XCTAssertEqual(NativeLayoutPolicy.moves(current: current, desired: desired).map(\.item), ["selected"])
    }
    func testAutomaticReapplyWaitsForResolvedSelectionAndBothControls() {
        XCTAssertFalse(NativeLayoutPolicy.isReadyToReapply(selected: ["fixture"], resolved: [], hasDivider: true, hasArrow: true))
        XCTAssertFalse(NativeLayoutPolicy.isReadyToReapply(selected: ["fixture"], resolved: ["fixture"], hasDivider: true, hasArrow: false))
        XCTAssertTrue(NativeLayoutPolicy.isReadyToReapply(selected: ["fixture"], resolved: ["fixture", "other"], hasDivider: true, hasArrow: true))
        XCTAssertTrue(NativeLayoutPolicy.isReadyToReapply(selected: ["stale-fixture", "snapzy"], resolved: ["snapzy"], hasDivider: true, hasArrow: true))
    }
    func testPlacementVerificationWaitsForEveryIconToReachItsSection() {
        let divider = CGRect(x: 100, y: 0, width: 20, height: 24)
        let selected: Set<String> = ["hidden"]
        XCTAssertFalse(NativeLayoutPolicy.placementIsVerified(items: [("hidden", CGRect(x: 90, y: 0, width: 20, height: 24)), ("visible", CGRect(x: 80, y: 0, width: 20, height: 24))], divider: divider, selected: selected))
        XCTAssertTrue(NativeLayoutPolicy.placementIsVerified(items: [("hidden", CGRect(x: 60, y: 0, width: 20, height: 24)), ("visible", CGRect(x: 125, y: 0, width: 20, height: 24))], divider: divider, selected: selected))
    }
    func testWakeKeepsAnAlreadyVerifiedHiddenLayoutAndReappliesAfterDrift() {
        let divider = CGRect(x: 100, y: 0, width: 20, height: 24)
        let selected: Set<String> = ["hidden"]
        let arranged = [(id: "hidden", frame: CGRect(x: 60, y: 0, width: 20, height: 24)), (id: "visible", frame: CGRect(x: 125, y: 0, width: 20, height: 24))]
        let drifted = [(id: "hidden", frame: CGRect(x: 125, y: 0, width: 20, height: 24)), (id: "visible", frame: CGRect(x: 150, y: 0, width: 20, height: 24))]
        XCTAssertTrue(NativeLayoutPolicy.hiddenPlacementIsVerified(groupHidden: true, items: arranged, divider: divider, selected: selected))
        XCTAssertFalse(NativeLayoutPolicy.hiddenPlacementIsVerified(groupHidden: true, items: drifted, divider: divider, selected: selected))
        XCTAssertFalse(NativeLayoutPolicy.hiddenPlacementIsVerified(groupHidden: false, items: arranged, divider: divider, selected: selected))
    }
    func testHostPaddingDoesNotDiscardAnUnambiguousAXCenter() {
        let hosted = CGRect(x: 900, y: 0, width: 38, height: 33)
        let ax = CGRect(x: 907, y: 4.5, width: 24, height: 24)
        XCTAssertEqual(EngineIdentity.uniqueMatch(window: hosted, candidates: [ax]), 0)
        XCTAssertNil(EngineIdentity.uniqueMatch(window: hosted, candidates: [ax, ax]))
    }
    func testHostedItemMatchesAnUnambiguousAXCandidateOffsetByEightPoints() {
        let hosted = CGRect(x: 100, y: 0, width: 38, height: 33)
        let ax = CGRect(x: 115, y: 4.5, width: 24, height: 24)
        XCTAssertEqual(EngineIdentity.uniqueMatch(window: hosted, candidates: [ax]), 0)
    }
    func testHostedItemRejectsMultipleAXCandidatesWithinTheOffsetRange() {
        let hosted = CGRect(x: 100, y: 0, width: 38, height: 33)
        let exact = CGRect(x: 107, y: 4.5, width: 24, height: 24)
        let offset = CGRect(x: 115, y: 4.5, width: 24, height: 24)
        XCTAssertNil(EngineIdentity.uniqueMatch(window: hosted, candidates: [exact, offset]))
    }
    func testOwnControlMatchesItsPaddedHostAfterTransientReflow() {
        let hosted = CGRect(x: 985, y: 0, width: 36, height: 33)
        let staleAX = CGRect(x: 939, y: 4.5, width: 22, height: 24)
        let otherControl = CGRect(x: 1261, y: 4.5, width: 24, height: 24)
        XCTAssertEqual(EngineIdentity.uniqueNearbyMatch(window: hosted, candidates: [staleAX, otherControl]), 0)
        XCTAssertNil(EngineIdentity.uniqueNearbyMatch(window: hosted, candidates: [staleAX, staleAX.offsetBy(dx: 106, dy: 0)]))
    }
    func testCaptureScaleComesFromActualPixels() {
        XCTAssertEqual(EngineCaptureFrame.actualScale(pixelWidth: 300, boundsWidth: 150), 2)
        XCTAssertNil(EngineCaptureFrame.actualScale(pixelWidth: 0, boundsWidth: 0))
    }
    func testCapturePayloadIsBounded() {
        XCTAssertFalse(EngineCaptureFrame.isValid(width: 4000, height: 4000, bytesPerRow: 16000, count: 64000000))
        XCTAssertTrue(EngineCaptureFrame.isValid(width: 40, height: 40, bytesPerRow: 160, count: 6400))
    }
    func testMonochromeCaptureCanBeRenderedAsATemplate() {
        XCTAssertTrue(EngineCaptureFrame.isMonochrome(Data([240, 240, 240, 255, 30, 30, 30, 255])))
        XCTAssertFalse(EngineCaptureFrame.isMonochrome(Data([240, 240, 240, 255, 20, 80, 240, 255])))
        XCTAssertFalse(EngineCaptureFrame.isMonochrome(Data([0, 0, 0, 0])))
    }
    func testDeadlineDoesNotGiveRetriesFreshBudgets() throws {
        let elapsed: Duration = .seconds(14)
        let budget = EngineMoveBudget(limit: .seconds(15), elapsed: { elapsed })
        XCTAssertEqual(try budget.timeout(for: .seconds(3)), .seconds(1))
        let exhausted = EngineMoveBudget(limit: .seconds(15), elapsed: { .seconds(15) })
        XCTAssertThrowsError(try exhausted.remaining())
    }
    @MainActor func testNormalTerminationDoesNotEraseRequestedHiddenState() {
        let name = "OverflowBarTests.NativeEngine.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let prefs = PreferencesStore(defaults: defaults)
        prefs.layoutManagementEnabled = true
        prefs.migrateToNativeEngine()
        XCTAssertFalse(prefs.layoutManagementEnabled)
        prefs.layoutManagementEnabled = true
        prefs.migrateToNativeEngine()
        XCTAssertTrue(prefs.layoutManagementEnabled)
    }
}
