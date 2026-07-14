import AppKit
import ApplicationServices

final class MenuBarItemActivator {
    private var relays: [MenuBarEventRelay] = []
    /// Uses AXPress first, then falls back to an accessibility-authorized mouse click.
    func activate(_ item: MenuBarItem, completion: @escaping (Bool) -> Void) {
        if let axElement = item.axElement, item.supportsPressAction, AXUIElementPerformAction(axElement, kAXPressAction as CFString) == .success {
            completion(true)
            return
        }
        if let windowID = item.windowID, let ownerPID = item.ownerPID,
           let source = CGEventSource(stateID: .hidSystemState),
           let down = targetedEvent(type: .leftMouseDown, item: item, windowID: windowID, pid: ownerPID, source: source),
           let up = targetedEvent(type: .leftMouseUp, item: item, windowID: windowID, pid: ownerPID, source: source) {
            relay(down, to: ownerPID) { [weak self] success in
                guard success else { completion(false); return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    self?.relay(up, to: ownerPID, completion: completion)
                }
            }
            return
        }

        let point = CGPoint(x: item.frame.midX, y: item.frame.midY)
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else { completion(false); return }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        completion(true)
    }

    private func relay(_ event: CGEvent, to pid: pid_t, completion: @escaping (Bool) -> Void) {
        var relay: MenuBarEventRelay?
        relay = MenuBarEventRelay(event: event, pid: pid) { [weak self] success in
            if let relay { self?.relays.removeAll { $0 === relay } }
            completion(success)
        }
        guard let relay else { completion(false); return }
        relays.append(relay)
        relay.start()
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
}
