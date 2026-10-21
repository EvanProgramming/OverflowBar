import XCTest
@testable import OverflowBar

final class MenuBarGroupGeometryTests: XCTestCase {
    func testCollapsedLengthIsBoundedByDisplayWidth() {
        XCTAssertEqual(MenuBarGroupGeometry.collapsedLength(screenWidths: [1_440, 2_560]), 5_120)
        XCTAssertEqual(MenuBarGroupGeometry.collapsedLength(screenWidths: [12_000]), 10_000)
        XCTAssertEqual(MenuBarGroupGeometry.collapsedLength(screenWidths: [200]), 500)
        XCTAssertEqual(MenuBarGroupGeometry.collapsedLength(screenWidths: []), 3_456)
    }

    func testDividerSwitchesBetweenArrangementAndHiddenLengths() {
        XCTAssertEqual(MenuBarGroupGeometry.dividerLength(groupHidden: false, osMajorVersion: 26, screenWidths: [1_440]), 20)
        XCTAssertEqual(MenuBarGroupGeometry.dividerLength(groupHidden: true, osMajorVersion: 26, screenWidths: [1_440]), 2_880)
        XCTAssertEqual(MenuBarGroupGeometry.dividerLength(groupHidden: true, osMajorVersion: 27, screenWidths: [1_440]), 20)
    }

    func testMembershipRequiresIconToBeWhollyLeftOfDivider() {
        let frames = [
            "left": CGRect(x: 20, y: 0, width: 40, height: 22),
            "overlap": CGRect(x: 80, y: 0, width: 30, height: 22),
            "right": CGRect(x: 140, y: 0, width: 20, height: 22)
        ]
        XCTAssertEqual(MenuBarGroupGeometry.hiddenItemIDs(itemFrames: frames, dividerFrame: CGRect(x: 100, y: 0, width: 20, height: 22)), ["left"])
    }

    func testMembershipSupportsNegativeDisplayCoordinatesAndIgnoresOtherRows() {
        let frames = [
            "negative-display": CGRect(x: -180, y: 1_080, width: 30, height: 22),
            "other-row": CGRect(x: -180, y: 920, width: 30, height: 22)
        ]
        XCTAssertEqual(MenuBarGroupGeometry.hiddenItemIDs(itemFrames: frames, dividerFrame: CGRect(x: -100, y: 1_080, width: 20, height: 22)), ["negative-display"])
    }

    func testExpandedDividerKeepsCompactPlacementForMembership() {
        let compact = CGRect(x: 100, y: 0, width: 20, height: 22)
        let expanded = CGRect(x: -2_856, y: 0, width: 2_956, height: 22)
        let frames = ["grouped": CGRect(x: 40, y: 0, width: 40, height: 22)]

        let membershipFrame = MenuBarGroupGeometry.membershipFrame(compactFrame: compact, currentFrame: expanded)

        XCTAssertEqual(membershipFrame, compact)
        XCTAssertEqual(MenuBarGroupGeometry.hiddenItemIDs(itemFrames: frames, dividerFrame: membershipFrame!), ["grouped"])
    }

    func testPanelAnchorFallsBackWhenStatusItemFrameIsUnavailable() {
        let fallback = CGRect(x: 1_200, y: 20, width: 20, height: 24)
        XCTAssertEqual(MenuBarGroupGeometry.panelAnchorFrame(buttonFrame: nil, fallbackFrame: fallback), fallback)
        XCTAssertEqual(MenuBarGroupGeometry.panelAnchorFrame(buttonFrame: CGRect.zero, fallbackFrame: fallback), fallback)
    }

    func testHidingCompatibilityBoundary() {
        XCTAssertFalse(MenuBarGroupGeometry.supportsHiding(osMajorVersion: 14))
        XCTAssertTrue(MenuBarGroupGeometry.supportsHiding(osMajorVersion: 15))
        XCTAssertTrue(MenuBarGroupGeometry.supportsHiding(osMajorVersion: 26))
        XCTAssertFalse(MenuBarGroupGeometry.supportsHiding(osMajorVersion: 27))
    }
}
