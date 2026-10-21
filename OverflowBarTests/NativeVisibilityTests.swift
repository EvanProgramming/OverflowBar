import XCTest
@testable import OverflowBar

final class NativeVisibilityTests: XCTestCase {
    func testHostedPaddingMayOverlapNotchWhenActualButtonDoesNot() {
        let display = CGRect(x: 0, y: 0, width: 1470, height: 956)
        let segments = [CGRect(x: 825, y: 0, width: 645, height: 32)]
        let hosted = CGRect(x: 824, y: 0, width: 58, height: 33)
        XCTAssertFalse(NativeVisibilityPolicy.isUsable(hosted, display: display, segments: segments))
        XCTAssertTrue(NativeVisibilityPolicy.isUsable(hosted, display: display, segments: segments, accessibilityFrame: CGRect(x: 831, y: 4.5, width: 44, height: 24)))
        XCTAssertFalse(NativeVisibilityPolicy.isUsable(hosted, display: display, segments: segments, accessibilityFrame: CGRect(x: 900, y: 4.5, width: 44, height: 24)))
    }
    func testNotchAndPartialOverlapAreNotUsable() {
        let display = CGRect(x: -1000, y: 0, width: 1000, height: 800)
        let segments = [CGRect(x: -1000, y: 0, width: 450, height: 30), CGRect(x: -450, y: 0, width: 450, height: 30)]
        XCTAssertFalse(NativeVisibilityPolicy.isUsable(CGRect(x: -510, y: 0, width: 20, height: 24), display: display, segments: segments))
        XCTAssertFalse(NativeVisibilityPolicy.isUsable(CGRect(x: -460, y: 0, width: 20, height: 24), display: display, segments: segments))
        XCTAssertTrue(NativeVisibilityPolicy.isUsable(CGRect(x: -100, y: 0, width: 20, height: 24), display: display, segments: segments))
    }
    func testHostedWindowHeightAllowsOnePointVerticalRounding() {
        XCTAssertTrue(NativeVisibilityPolicy.isUsable(CGRect(x: 900, y: 0, width: 33, height: 33), display: CGRect(x: 0, y: 0, width: 1470, height: 956), segments: [CGRect(x: 825, y: 0, width: 645, height: 32)]))
    }
    func testOrdinaryOwnerPopoverCountsAsResponse() {
        let window = NativeInterfaceWindow(id: 11, pid: 5, layer: 0, frame: CGRect(x: 10, y: 24, width: 100, height: 100))
        XCTAssertEqual(NativeResponseVerifier.observe(before: [], windows: [window], pids: [5], original: .zero, current: .zero), .openedInterface(11))
    }
}
