import AppKit
import XCTest
@testable import OverflowBar

final class NativeEventTests: XCTestCase {
    @MainActor
    func testNativeDragRetainsMoveOnlyWindowFieldAndCommand() throws {
        let event = try NativeEventRelay.event(type: .leftMouseDown, point: .zero, window: 42, pid: 100, command: true, moving: true)
        XCTAssertEqual(event.getIntegerValueField(CGEventField(rawValue: 0x33)!), 42)
        XCTAssertEqual(event.getIntegerValueField(.mouseEventClickState), 0)
        XCTAssertTrue(event.flags.contains(.maskCommand))
    }
    @MainActor
    func testNativeClickUsesWindowUnderPointerWithoutMoveOnlyField() throws {
        let down = try NativeEventRelay.event(type: .leftMouseDown, point: CGPoint(x: 10, y: 12), window: 42, pid: 100, command: false)
        let up = try NativeEventRelay.event(type: .leftMouseUp, point: CGPoint(x: 10, y: 12), window: 42, pid: 100, command: false)
        XCTAssertEqual(down.getIntegerValueField(.mouseEventWindowUnderMousePointer), 42)
        XCTAssertEqual(down.getIntegerValueField(CGEventField(rawValue: 0x33)!), 0)
        XCTAssertEqual(down.getIntegerValueField(.mouseEventClickState), 1)
        XCTAssertEqual(up.getIntegerValueField(.mouseEventClickState), 0)
    }
}
