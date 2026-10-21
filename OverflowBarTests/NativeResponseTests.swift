import XCTest
@testable import OverflowBar

final class NativeResponseTests: XCTestCase {
    func testManualFallbackRestoresPreviouslyVerifiedHiddenLayout() {
        XCTAssertTrue(NativeActivationPolicy.shouldRestoreAfterMenu(verifiedHiddenLayout: true, moved: false))
        XCTAssertFalse(NativeActivationPolicy.shouldRestoreAfterMenu(verifiedHiddenLayout: false, moved: false))
        XCTAssertTrue(NativeActivationPolicy.shouldRestoreAfterMenu(verifiedHiddenLayout: false, moved: true))
    }

    func testOneRowNativeMenuIsObserved() {
        let menu = NativeInterfaceWindow(id: 9, pid: 5, layer: Int(CGWindowLevelForKey(.popUpMenuWindow)), frame: CGRect(x: 10, y: 33, width: 150, height: 24))
        XCTAssertEqual(NativeResponseVerifier.observe(before: [], windows: [menu], pids: [5], original: .zero, current: .zero), .openedInterface(9))
    }
    func testFreshTitleChangeIsObservableWithoutInventingAMenu() {
        let frame = CGRect(x: 10, y: 0, width: 55, height: 33)
        XCTAssertEqual(NativeResponseVerifier.observe(before: [], windows: [], pids: [5], original: frame, current: frame, originalTitle: "OB-T14", currentTitle: "OB-T15"), .itemChanged)
        XCTAssertEqual(NativeResponseVerifier.observe(before: [], windows: [], pids: [5], original: frame, current: frame, originalTitle: "OB-T14", currentTitle: "OB-T14"), .unobserved)
    }
    func testDeliveredClickIsNotAConfirmedNativeResponse() {
        XCTAssertEqual(NativeResponseVerifier.observe(before: [], windows: [], pids: [5], original: CGRect(x: 10, y: 0, width: 20, height: 24), current: CGRect(x: 40, y: 0, width: 20, height: 24)), .unobserved)
    }
    func testOnlyNewOwnerInterfaceCountsAsMenuReaction() {
        let window = NativeInterfaceWindow(id: 10, pid: 5, layer: 101, frame: CGRect(x: 20, y: 24, width: 120, height: 200))
        XCTAssertEqual(NativeResponseVerifier.observe(before: [], windows: [window], pids: [5], original: .zero, current: .zero), .openedInterface(10))
        XCTAssertEqual(NativeResponseVerifier.observe(before: [10], windows: [window], pids: [5], original: .zero, current: .zero), .unobserved)
        XCTAssertEqual(NativeResponseVerifier.observe(before: [], windows: [window], pids: [6], original: .zero, current: .zero), .unobserved)
    }
    func testAnchoredNativeMenuCountsWhenSystemHostOwnsIt() {
        let item = CGRect(x: 20, y: 0, width: 24, height: 24)
        let menu = NativeInterfaceWindow(id: 12, pid: 99, layer: Int(CGWindowLevelForKey(.popUpMenuWindow)), frame: CGRect(x: 8, y: 24, width: 180, height: 220))
        XCTAssertEqual(NativeResponseVerifier.observe(before: [], windows: [menu], pids: [5], original: item, current: item), .openedInterface(12))
    }
    func testAnchoredPopoverAtFloatingLevelCountsWhenSystemHostOwnsIt() {
        let item = CGRect(x: 20, y: 0, width: 24, height: 24)
        let popover = NativeInterfaceWindow(id: 14, pid: 99, layer: Int(CGWindowLevelForKey(.floatingWindow)), frame: CGRect(x: 8, y: 24, width: 220, height: 260))
        XCTAssertEqual(NativeResponseVerifier.observe(before: [], windows: [popover], pids: [5], original: item, current: item), .openedInterface(14))
    }
    func testAccessibilityPressIsReservedForElectronTrayItems() {
        XCTAssertTrue(NativeActivationPolicy.usesAccessibilityPress(isElectron: true, supportsPress: true))
        XCTAssertFalse(NativeActivationPolicy.usesAccessibilityPress(isElectron: false, supportsPress: true))
        XCTAssertFalse(NativeActivationPolicy.usesAccessibilityPress(isElectron: true, supportsPress: false))
    }
    func testUnanchoredSystemPopupDoesNotCountAsTargetResponse() {
        let item = CGRect(x: 20, y: 0, width: 24, height: 24)
        let popup = NativeInterfaceWindow(id: 13, pid: 99, layer: Int(CGWindowLevelForKey(.popUpMenuWindow)), frame: CGRect(x: 500, y: 400, width: 180, height: 220))
        XCTAssertEqual(NativeResponseVerifier.observe(before: [], windows: [popup], pids: [5], original: item, current: item), .unobserved)
    }
    func testSizeChangeOrDisappearanceCountsButOriginChangeDoesNot() {
        let original = CGRect(x: 0, y: 0, width: 20, height: 24)
        XCTAssertEqual(NativeResponseVerifier.observe(before: [], windows: [], pids: [], original: original, current: nil), .itemChanged)
        XCTAssertEqual(NativeResponseVerifier.observe(before: [], windows: [], pids: [], original: original, current: CGRect(x: 0, y: 0, width: 30, height: 24)), .itemChanged)
    }

    func testManualMenuMustOpenAndThenCloseBeforeLayoutCanBeRestored() {
        var lifecycle = NativeInterfaceLifecycle(before: [4])
        XCTAssertFalse(lifecycle.observe([4]))
        XCTAssertFalse(lifecycle.observe([4, 9]))
        XCTAssertFalse(lifecycle.observe([4, 9]))
        XCTAssertTrue(lifecycle.observe([4]))
    }

    func testAlreadyObservedMenuMustCloseBeforeLayoutCanBeRestored() {
        var lifecycle = NativeInterfaceLifecycle(before: [], interface: 9)
        XCTAssertFalse(lifecycle.observe([9]))
        XCTAssertTrue(lifecycle.observe([]))
    }
}
