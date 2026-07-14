import AppKit
import CoreGraphics

/// Moves status-item windows by sending WindowServer-targeted Command-drag events.
/// The physical mouse cursor is never moved.
final class MenuBarLayoutManager {
    private let preferences: PreferencesStore
    private var relays: [MenuBarEventRelay] = []
    init(preferences: PreferencesStore) { self.preferences = preferences }

    var isEnabled: Bool {
        get { preferences.layoutManagementEnabled }
        set { preferences.layoutManagementEnabled = newValue }
    }

    func hide(_ items: [MenuBarItem], relativeTo controlFrame: CGRect) {
        guard isEnabled, let target = controlTargetWindow() else { return }
        for (index, item) in items.filter({ $0.windowID != target.id }).enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) { [weak self] in
                self?.move(item, to: CGPoint(x: target.frame.minX, y: target.frame.midY), targetWindowID: target.id)
            }
        }
    }

    func reveal(_ item: MenuBarItem, relativeTo controlFrame: CGRect, rehideAfter delay: TimeInterval = 2) {
        guard let target = controlTargetWindow() else { return }
        move(item, to: CGPoint(x: target.frame.maxX, y: target.frame.midY), targetWindowID: target.id)
        guard isEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let refreshedTarget = self.controlTargetWindow() else { return }
            self.move(item, to: CGPoint(x: refreshedTarget.frame.minX, y: refreshedTarget.frame.midY), targetWindowID: refreshedTarget.id)
        }
    }

    func restore(_ items: [MenuBarItem], relativeTo controlFrame: CGRect) {
        guard let target = controlTargetWindow() else { return }
        for item in items.reversed() {
            move(item, to: CGPoint(x: target.frame.maxX, y: target.frame.midY), targetWindowID: target.id)
        }
    }

    private func move(_ item: MenuBarItem, to destination: CGPoint, targetWindowID: CGWindowID) {
        guard let itemWindowID = item.windowID, let ownerPID = item.ownerPID,
              currentFrame(windowID: itemWindowID) != nil,
              let source = CGEventSource(stateID: .hidSystemState),
              let down = targetedEvent(type: .leftMouseDown, point: CGPoint(x: 20_000, y: 20_000), windowID: itemWindowID, pid: ownerPID, source: source, command: true),
              let up = targetedEvent(type: .leftMouseUp, point: destination, windowID: targetWindowID, pid: ownerPID, source: source, command: false) else { return }
        if let suppressionSource = CGEventSource(stateID: .combinedSessionState) {
            let permitAll: CGEventFilterMask = [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents]
            suppressionSource.setLocalEventsFilterDuringSuppressionState(permitAll, state: .eventSuppressionStateRemoteMouseDrag)
            suppressionSource.setLocalEventsFilterDuringSuppressionState(permitAll, state: .eventSuppressionStateSuppressionInterval)
            suppressionSource.localEventsSuppressionInterval = 0
        }
        relay(down, to: ownerPID) { [weak self] success in
            guard success else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                self?.relay(up, to: ownerPID, completion: { _ in })
            }
        }
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

    private func targetedEvent(type: CGEventType, point: CGPoint, windowID: CGWindowID, pid: pid_t, source: CGEventSource, command: Bool) -> CGEvent? {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { return nil }
        event.flags = command ? .maskCommand : []
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        event.setIntegerValueField(.eventSourceUserData, value: Int64.random(in: 1...Int64.max))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(windowID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(windowID))
        event.setIntegerValueField(CGEventField(rawValue: 0x33)!, value: Int64(windowID))
        return event
    }

    private func controlTargetWindow() -> (id: CGWindowID, frame: CGRect)? {
        let records = windowRecords()
        if let overflowBar = records.first(where: { $0.title == "OverflowBarControlItem" }) {
            return (overflowBar.id, overflowBar.frame)
        }
        if let own = records.first(where: { $0.pid == getpid() }) { return (own.id, own.frame) }
        if let controlCenter = records.first(where: { $0.title == "BentoBox-0" }) { return (controlCenter.id, controlCenter.frame) }
        return records.max(by: { $0.frame.maxX < $1.frame.maxX }).map { ($0.id, $0.frame) }
    }

    private func currentFrame(windowID: CGWindowID) -> CGRect? { windowRecords().first { $0.id == windowID }?.frame }

    private func windowRecords() -> [(id: CGWindowID, pid: pid_t, title: String, frame: CGRect)] {
        let list = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 25,
                  let id = info[kCGWindowNumber as String] as? Int,
                  let pid = info[kCGWindowOwnerPID as String] as? Int,
                  let b = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            return (CGWindowID(id), pid_t(pid), info[kCGWindowName as String] as? String ?? "", CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0))
        }
    }
}
