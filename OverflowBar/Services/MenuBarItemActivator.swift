import AppKit
import ApplicationServices

final class MenuBarItemActivator {
    func activateDirectly(_ item: MenuBarItem) -> Bool {
        guard let axElement = item.axElement, item.supportsPressAction else { return false }
        return AXUIElementPerformAction(axElement, kAXPressAction as CFString) == .success
    }

    func activateViaAccessibilityHitTest(_ item: MenuBarItem) -> Bool {
        let system = AXUIElementCreateSystemWide()
        var value: AXUIElement?
        // MenuBarScanner receives Quartz window bounds (origin at the top
        // left), while Accessibility hit testing uses AppKit screen space
        // (origin at the bottom left). Passing the raw Quartz y-coordinate
        // makes the hit test land near the bottom of the display.
        guard let screen = NSScreen.screens.first(where: { $0.frame.minX <= item.frame.midX && $0.frame.maxX >= item.frame.midX }) ?? NSScreen.main else { return false }
        let rawPoint = CGPoint(x: item.frame.midX, y: item.frame.midY)
        let convertedPoint = CGPoint(x: item.frame.midX, y: screen.frame.maxY - item.frame.midY)
        let points = item.windowID == nil ? [rawPoint, convertedPoint] : [convertedPoint, rawPoint]
        for point in points {
            value = nil
            guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &value) == .success,
                  let element = value else { continue }
            if AXUIElementPerformAction(element, kAXPressAction as CFString) == .success { return true }
        }
        return false
    }

    /// Clicks an item after it has been temporarily moved into the visible menu bar.
    func activateMovedItem(_ item: MenuBarItem, mouseButton: CGMouseButton = .left, completion: @escaping (Bool) -> Void) {
        if let windowID = item.windowID, let ownerPID = item.ownerPID,
           let source = CGEventSource(stateID: .privateState),
           let down = targetedEvent(type: mouseButton == .right ? .rightMouseDown : .leftMouseDown, item: item, windowID: windowID, pid: ownerPID, source: source, mouseButton: mouseButton),
           let up = targetedEvent(type: mouseButton == .right ? .rightMouseUp : .leftMouseUp, item: item, windowID: windowID, pid: ownerPID, source: source, mouseButton: mouseButton) {
            // Control Center owns most status-item windows on recent macOS,
            // but it does not consistently consume events posted directly to
            // its PID. A session-tap click follows the same WindowServer path
            // as a real menu-bar click while leaving the physical cursor put.
            down.post(tap: .cgSessionEventTap)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                up.post(tap: .cgSessionEventTap)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { completion(true) }
            }
            return
        }
        completion(false)
    }

    /// Sends a right-click to an item that is already visible. Accessibility
    /// exposes AXPress only (left-click semantics), so context-menu items
    /// need a real right mouse event instead.
    func activateRightClick(_ item: MenuBarItem, completion: @escaping (Bool) -> Void) {
        guard let source = CGEventSource(stateID: .privateState) else { completion(false); return }
        let point = CGPoint(x: item.frame.midX, y: item.frame.midY)
        guard let down = CGEvent(mouseEventSource: source, mouseType: .rightMouseDown, mouseCursorPosition: point, mouseButton: .right),
              let up = CGEvent(mouseEventSource: source, mouseType: .rightMouseUp, mouseCursorPosition: point, mouseButton: .right) else { completion(false); return }
        down.setIntegerValueField(.mouseEventClickState, value: 1)
        up.setIntegerValueField(.mouseEventClickState, value: 1)
        down.post(tap: .cgSessionEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            up.post(tap: .cgSessionEventTap)
            completion(true)
        }
    }

    private func targetedEvent(type: CGEventType, item: MenuBarItem, windowID: CGWindowID, pid: pid_t, source: CGEventSource, mouseButton: CGMouseButton) -> CGEvent? {
        let point = currentFrame(windowID: windowID).map { CGPoint(x: $0.midX, y: $0.midY) }
            ?? CGPoint(x: item.frame.midX, y: item.frame.midY)
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: mouseButton) else { return nil }
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        event.setIntegerValueField(.eventSourceUserData, value: Int64.random(in: 1...Int64.max))
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(windowID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(windowID))
        event.setIntegerValueField(CGEventField(rawValue: 0x33)!, value: Int64(windowID))
        return event
    }

    private func currentFrame(windowID: CGWindowID) -> CGRect? {
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        guard let bounds = windows.first(where: { ($0[kCGWindowNumber as String] as? Int) == Int(windowID) })?[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
        return CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
    }

}
