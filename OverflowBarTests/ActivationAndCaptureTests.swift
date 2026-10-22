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
            "Open this icon from the menu bar, then hide selected icons when you're ready."
        )
        XCTAssertNil(MenuBarActivationResult.unobserved.layoutMessage(groupHidden: true))
    }

    func testManualMenuFallbackExplainsAutomaticRestoration() {
        XCTAssertEqual(
            MenuBarActivationResult.awaitingManualInterface.layoutMessage(groupHidden: false),
            "Open this icon from the menu bar. OverflowBar will put it back after its menu closes."
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
