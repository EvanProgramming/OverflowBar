import AppKit
import XCTest
@testable import OverflowBar

final class OverflowPanelTests: XCTestCase {
    @MainActor
    func testExplicitPanelSupportsKeyboardAndEscape() {
        let panel = OverflowPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        var cancelled = false
        panel.onCancel = { cancelled = true }
        panel.cancelOperation(nil)
        XCTAssertTrue(cancelled)
    }
}

final class MenuBarHoverRevealStateTests: XCTestCase {
    func testFirstMenuBarEntryRevealsOnlyOnceDuringRepeatedMovement() {
        var state = MenuBarHoverRevealState()

        XCTAssertTrue(state.shouldReveal(enabled: true, pointerInMenuBar: true, operationInProgress: false))
        XCTAssertFalse(state.shouldReveal(enabled: true, pointerInMenuBar: true, operationInProgress: false))
        XCTAssertFalse(state.shouldReveal(enabled: true, pointerInMenuBar: true, operationInProgress: false))
    }

    func testLeavingAndReenteringAllowsAnotherReveal() {
        var state = MenuBarHoverRevealState()

        XCTAssertTrue(state.shouldReveal(enabled: true, pointerInMenuBar: true, operationInProgress: false))
        XCTAssertFalse(state.shouldReveal(enabled: true, pointerInMenuBar: false, operationInProgress: false))
        XCTAssertTrue(state.shouldReveal(enabled: true, pointerInMenuBar: true, operationInProgress: false))
    }

    func testDisabledHoverResetsEntryState() {
        var state = MenuBarHoverRevealState()

        XCTAssertTrue(state.shouldReveal(enabled: true, pointerInMenuBar: true, operationInProgress: false))
        XCTAssertFalse(state.shouldReveal(enabled: false, pointerInMenuBar: true, operationInProgress: false))
        XCTAssertTrue(state.shouldReveal(enabled: true, pointerInMenuBar: true, operationInProgress: false))
    }

    func testNativeOperationSuppressesRevealUntilPointerLeaves() {
        var state = MenuBarHoverRevealState()

        XCTAssertFalse(state.shouldReveal(enabled: true, pointerInMenuBar: true, operationInProgress: true))
        XCTAssertFalse(state.shouldReveal(enabled: true, pointerInMenuBar: true, operationInProgress: false))
        XCTAssertFalse(state.shouldReveal(enabled: true, pointerInMenuBar: false, operationInProgress: false))
        XCTAssertTrue(state.shouldReveal(enabled: true, pointerInMenuBar: true, operationInProgress: false))
    }
}
