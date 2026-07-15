import AppKit
import ApplicationServices

final class MenuBarItemActivator {
    func canActivateDirectly(_ item: MenuBarItem) -> Bool {
        item.axElement != nil && item.supportsPressAction
    }

    func activateDirectly(_ item: MenuBarItem, completion: @escaping (Bool) -> Void) {
        guard let axElement = item.axElement, item.supportsPressAction else { completion(false); return }
        completion(AXUIElementPerformAction(axElement, kAXPressAction as CFString) == .success)
    }

    /// Clicks an item after it has been temporarily moved into the visible menu bar.
    func activateMovedItem(_ item: MenuBarItem, completion: @escaping (Bool) -> Void) {
        if let windowID = item.windowID, let ownerPID = item.ownerPID,
           let source = CGEventSource(stateID: .hidSystemState),
           let down = targetedEvent(type: .leftMouseDown, item: item, windowID: windowID, pid: ownerPID, source: source),
           let up = targetedEvent(type: .leftMouseUp, item: item, windowID: windowID, pid: ownerPID, source: source) {
            let cursorLocation = restorableCursorLocation()
            down.post(tap: .cgSessionEventTap)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                up.post(tap: .cgSessionEventTap)
                if let cursorLocation { CGWarpMouseCursorPosition(cursorLocation) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { completion(true) }
            }
            return
        }
        completion(false)
    }

    private func targetedEvent(type: CGEventType, item: MenuBarItem, windowID: CGWindowID, pid: pid_t, source: CGEventSource) -> CGEvent? {
        let point = currentFrame(windowID: windowID).map { CGPoint(x: $0.midX, y: $0.midY) }
            ?? CGPoint(x: item.frame.midX, y: item.frame.midY)
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { return nil }
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

    private func restorableCursorLocation() -> CGPoint? {
        guard let point = CGEvent(source: nil)?.location,
              point.x.isFinite, point.y.isFinite,
              point.x > 1 || point.y > 1 else { return nil }
        let isOnDisplay = NSScreen.screens.first { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayBounds(CGDirectDisplayID(number.uint32Value)).contains(point)
        } != nil
        return isOnDisplay ? point : nil
    }
}
