import AppKit
import ApplicationServices

final class MenuBarItemActivator {
    private var relays: [MenuBarEventRelay] = []

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
        if mouseButton == .right {
            activateRightClick(item, completion: completion)
            return
        }
        if let windowID = item.windowID, let ownerPID = item.ownerPID,
           let source = CGEventSource(stateID: .privateState),
           let down = targetedEvent(type: .leftMouseDown, item: item, windowID: windowID, pid: ownerPID, source: source, mouseButton: .left),
           let up = targetedEvent(type: .leftMouseUp, item: item, windowID: windowID, pid: ownerPID, source: source, mouseButton: .left) {
            // Route the event through a short-lived relay. The relay forwards
            // it to the owner process and consumes the session copy, so other
            // applications never receive a synthetic click at this item's
            // screen coordinate.
            postIsolated(down, to: ownerPID) { [weak self] success in
                guard success else { completion(false); return }
                guard let self else { completion(false); return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    self.postIsolated(up, to: ownerPID, completion: completion)
                }
            }
            return
        }
        completion(false)
    }

    /// Sends a right-click to an item that is already visible. Accessibility
    /// exposes AXPress only (left-click semantics), so context-menu items
    /// need a real right mouse event instead.
    func activateRightClick(_ item: MenuBarItem, completion: @escaping (Bool) -> Void) {
        activateRightClick(item, attempt: 0, completion: completion)
    }

    private func activateRightClick(_ item: MenuBarItem, attempt: Int, completion: @escaping (Bool) -> Void) {
        guard let source = CGEventSource(stateID: .privateState) else { completion(false); return }
        guard let point = visiblePoint(for: item) else {
            // WindowServer can publish the new frame a few ticks after the
            // reveal verification callback. Retry the lookup briefly instead
            // of reporting a false activation failure or using an old frame.
            guard attempt < 2 else { completion(false); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
                self?.activateRightClick(item, attempt: attempt + 1, completion: completion)
            }
            return
        }
        guard isValidMenuBarPoint(point) else { completion(false); return }
        guard let down = CGEvent(mouseEventSource: source, mouseType: .rightMouseDown, mouseCursorPosition: point, mouseButton: .right),
              let up = CGEvent(mouseEventSource: source, mouseType: .rightMouseUp, mouseCursorPosition: point, mouseButton: .right) else { completion(false); return }
        down.setIntegerValueField(.mouseEventClickState, value: 1)
        up.setIntegerValueField(.mouseEventClickState, value: 1)
        postIsolated(down, to: item.ownerPID) { [weak self] success in
            guard success else { completion(false); return }
            guard let self else { completion(false); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                self.postIsolated(up, to: item.ownerPID, completion: completion)
            }
        }
    }

    private func postIsolated(_ event: CGEvent, to pid: pid_t?, completion: @escaping (Bool) -> Void) {
        guard let pid else { completion(false); return }
        var relay: MenuBarEventRelay?
        relay = MenuBarEventRelay(event: event, pid: pid) { [weak self] success in
            if let relay {
                self?.relays.removeAll { $0 === relay }
            }
            completion(success)
        }
        guard let relay else {
            completion(false)
            return
        }
        relays.append(relay)
        relay.start()
    }

    private func targetedEvent(type: CGEventType, item: MenuBarItem, windowID: CGWindowID, pid: pid_t, source: CGEventSource, mouseButton: CGMouseButton) -> CGEvent? {
        // Never fall back to item.frame here: for a hidden item that frame is
        // intentionally negative, and WindowServer clamps it to (0, 0),
        // which opens the Apple menu instead of the requested status item.
        guard let frame = currentFrame(windowID: windowID), frame.maxX > 0 else { return nil }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        guard isValidMenuBarPoint(point) else { return nil }
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: mouseButton) else { return nil }
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        event.setIntegerValueField(.eventSourceUserData, value: Int64.random(in: 1...Int64.max))
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(windowID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(windowID))
        event.setIntegerValueField(CGEventField(rawValue: 0x33)!, value: Int64(windowID))
        return event
    }

    private func isValidMenuBarPoint(_ point: CGPoint) -> Bool {
        guard point.x.isFinite, point.y.isFinite else { return false }
        return activeDisplayBounds().contains { display in
            display.contains(point) && point.y >= display.minY && point.y <= display.minY + 50
        }
    }

    /// Resolves a fresh WindowServer frame before every synthetic event. The
    /// Control Center process can rebuild a status-item window while the item
    /// remains logically the same. If the original window number disappeared,
    /// choose the nearest visible layer-25 window owned by that process rather
    /// than sending a stale event to (0, 0).
    private func visiblePoint(for item: MenuBarItem) -> CGPoint? {
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        let records: [(id: CGWindowID, pid: pid_t, frame: CGRect)] = windows.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 25,
                  let id = info[kCGWindowNumber as String] as? Int,
                  let pid = info[kCGWindowOwnerPID as String] as? Int,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            let frame = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            guard isVisibleMenuBarFrame(frame) else { return nil }
            return (CGWindowID(id), pid_t(pid), frame)
        }
        if let windowID = item.windowID,
           let exact = records.first(where: { $0.id == windowID }) {
            return CGPoint(x: exact.frame.midX, y: exact.frame.midY)
        }
        if let ownerPID = item.ownerPID {
            let preferredX = item.frame.midX
            return records
                .filter { $0.pid == ownerPID }
                .min(by: { abs($0.frame.midX - preferredX) < abs($1.frame.midX - preferredX) })
                .map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) }
        }
        // AX-backed items do not carry a window number. This fallback is only
        // allowed for an already-visible positive frame; hidden items take
        // the reveal path in MenuBarItemStore instead.
        let fallback = CGPoint(x: item.frame.midX, y: item.frame.midY)
        if isValidMenuBarPoint(fallback) { return fallback }
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.minX <= item.frame.midX && $0.frame.maxX >= item.frame.midX
        }) ?? NSScreen.main else { return nil }
        let converted = CGPoint(x: item.frame.midX, y: screen.frame.maxY - item.frame.midY)
        return isValidMenuBarPoint(converted) ? converted : nil
    }

    private func isVisibleMenuBarFrame(_ frame: CGRect) -> Bool {
        guard frame.width > 4, frame.height > 4, frame.height <= 40 else { return false }
        return activeDisplayBounds().contains { display in
            frame.intersects(display) && abs(frame.minY - display.minY) <= 2
        }
    }

    private func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return [] }
        return displays.prefix(Int(count)).map(CGDisplayBounds)
    }

    private func currentFrame(windowID: CGWindowID) -> CGRect? {
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        guard let bounds = windows.first(where: { ($0[kCGWindowNumber as String] as? Int) == Int(windowID) })?[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
        return CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
    }

}
