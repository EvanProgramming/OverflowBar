import XCTest
import ApplicationServices
@testable import OverflowBar

final class ActivationAndCaptureTests: XCTestCase {
    func testAmbiguousAccessibilityTargetsFailClosed() {
        let element = AXUIElementCreateSystemWide()
        if case .ambiguous = AccessibilityTargetResolution.classify(count: 2, element: element) { } else {
            XCTFail("Multiple matching controls must not be activated")
        }
    }

    func testUnsupportedActivationUsesManualFallback() {
        XCTAssertEqual(MenuBarItemActivator.outcome(advertised: false, succeeded: false), .manualFallback)
        XCTAssertEqual(MenuBarItemActivator.outcome(advertised: true, succeeded: false), .manualFallback)
        XCTAssertEqual(MenuBarItemActivator.outcome(advertised: true, succeeded: true), .activated)
    }

    func testManualActivationFallbackReportsRevealedGroupState() {
        XCTAssertEqual(
            MenuBarActivationResult.unobserved.layoutMessage(groupHidden: false),
            "Native icons are revealed. Click the original item, then hide the group again when ready."
        )
        XCTAssertNil(MenuBarActivationResult.unobserved.layoutMessage(groupHidden: true))
    }

    func testManualMenuFallbackExplainsAutomaticRestoration() {
        XCTAssertEqual(
            MenuBarActivationResult.awaitingManualInterface.layoutMessage(groupHidden: false),
            "Native icons are revealed. Click the original item; OverflowBar will restore the layout after its menu closes."
        )
    }

    @MainActor
    func testCaptureCancellationCompletesAllWaitingCallbacksOnce() {
        let queue = CaptureCompletionQueue()
        var completions = 0
        queue.append { completions += 1 }
        queue.append { completions += 1 }
        queue.cancel()
        queue.cancel()
        XCTAssertEqual(completions, 2)
    }
}
