import AppKit
import CoreGraphics
import OSLog

/// Moves status-item windows by sending WindowServer-targeted Command-drag events.
/// The physical mouse cursor is never moved.
final class MenuBarLayoutManager {
    private enum Placement { case left, right }
    private let logger = Logger(subsystem: "com.overflowbar.app", category: "layout")
    private let preferences: PreferencesStore
    private let initialWindowIDs: Set<CGWindowID>
    private var relays: [MenuBarEventRelay] = []
    var onHiddenFramesChanged: (([CGRect]) -> Void)?
    init(preferences: PreferencesStore) {
        self.preferences = preferences
        initialWindowIDs = Set(Self.fetchWindowRecords().map(\.id))
    }

    var isEnabled: Bool {
        get { preferences.layoutManagementEnabled }
        set { preferences.layoutManagementEnabled = newValue }
    }

    func hide(_ items: [MenuBarItem], relativeTo controlFrame: CGRect) {
        guard isEnabled else { return }
        guard let target = controlTargetWindow() else {
            logger.info("Control window pending; retrying")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.hide(items, relativeTo: controlFrame)
            }
            return
        }
        logger.info("Hiding \(items.count, privacy: .public) items relative to window \(target.id, privacy: .public)")
        let managed = items.filter { $0.windowID != target.id }
        publishCurrentFrames(for: managed)
        hideSequentially(managed, index: 0) { [weak self] in
            self?.publishCurrentFrames(for: managed)
        }
    }

    func reveal(_ item: MenuBarItem, relativeTo controlFrame: CGRect, rehideAfter delay: TimeInterval = 2) {
        guard let target = controlTargetWindow() else { return }
        move(item, relativeTo: target.id, placement: .right) { _ in }
        guard isEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let refreshedTarget = self.controlTargetWindow() else { return }
            self.move(item, relativeTo: refreshedTarget.id, placement: .left) { _ in }
        }
    }

    func restore(_ items: [MenuBarItem], relativeTo controlFrame: CGRect) {
        guard let target = controlTargetWindow() else { return }
        restoreSequentially(Array(items.reversed()), index: 0, target: target)
    }

    func show(_ item: MenuBarItem) {
        guard let target = controlTargetWindow() else { return }
        move(item, relativeTo: target.id, placement: .left) { _ in }
    }

    private func hideSequentially(_ items: [MenuBarItem], index: Int, completion: @escaping () -> Void) {
        guard index < items.count else { completion(); return }
        guard let target = controlTargetWindow() else { completion(); return }
        let item = items[index]
        move(item, relativeTo: target.id, placement: .left) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                self?.hideSequentially(items, index: index + 1, completion: completion)
            }
        }
    }

    private func publishCurrentFrames(for items: [MenuBarItem]) {
        let frames = items.compactMap { item in
            item.windowID.flatMap(currentFrame(windowID:))
        }
        onHiddenFramesChanged?(frames)
    }

    private func restoreSequentially(_ items: [MenuBarItem], index: Int, target: (id: CGWindowID, frame: CGRect)) {
        guard index < items.count else { return }
        let item = items[index]
        move(item, relativeTo: target.id, placement: .left) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                guard let refreshed = self?.controlTargetWindow() else { return }
                self?.restoreSequentially(items, index: index + 1, target: refreshed)
            }
        }
    }

    private func move(_ item: MenuBarItem, relativeTo targetWindowID: CGWindowID, placement: Placement, attempt: Int = 1, completion: @escaping (Bool) -> Void) {
        guard let itemWindowID = item.windowID, let ownerPID = item.ownerPID,
              currentFrame(windowID: itemWindowID) != nil,
              let targetFrame = currentFrame(windowID: targetWindowID),
              let source = CGEventSource(stateID: .hidSystemState),
              let down = targetedEvent(type: .leftMouseDown, point: CGPoint(x: 20_000, y: 20_000), windowID: itemWindowID, pid: ownerPID, source: source, command: true),
              let up = targetedEvent(type: .leftMouseUp, point: CGPoint(x: placement == .left ? targetFrame.minX : targetFrame.maxX, y: targetFrame.midY), windowID: targetWindowID, pid: ownerPID, source: source, command: false) else {
            completion(false)
            return
        }
        if let suppressionSource = CGEventSource(stateID: .combinedSessionState) {
            let permitAll: CGEventFilterMask = [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents]
            suppressionSource.setLocalEventsFilterDuringSuppressionState(permitAll, state: .eventSuppressionStateRemoteMouseDrag)
            suppressionSource.setLocalEventsFilterDuringSuppressionState(permitAll, state: .eventSuppressionStateSuppressionInterval)
            suppressionSource.localEventsSuppressionInterval = 0
        }
        relay(down, to: ownerPID) { [weak self] success in
            self?.logger.info("Mouse-down relay window \(itemWindowID, privacy: .public) success=\(success, privacy: .public)")
            guard success else { completion(false); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                self?.relay(up, to: ownerPID) { success in
                    self?.logger.info("Mouse-up relay window \(itemWindowID, privacy: .public) success=\(success, privacy: .public)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                        guard let self else { completion(false); return }
                        let itemFrame = self.currentFrame(windowID: itemWindowID)
                        let latestTargetFrame = self.currentFrame(windowID: targetWindowID)
                        let moved: Bool
                        switch placement {
                        case .left: moved = itemFrame?.maxX == latestTargetFrame?.minX
                        case .right: moved = itemFrame?.minX == latestTargetFrame?.maxX
                        }
                        self.logger.info("Move verification window \(itemWindowID, privacy: .public) attempt \(attempt, privacy: .public) moved=\(moved, privacy: .public)")
                        if !moved, attempt < 3 {
                            self.move(item, relativeTo: targetWindowID, placement: placement, attempt: attempt + 1, completion: completion)
                        } else {
                            completion(moved)
                        }
                    }
                }
            }
        }
    }

    private func relay(_ event: CGEvent, to pid: pid_t, completion: @escaping (Bool) -> Void) {
        var relay: MenuBarEventRelay?
        relay = MenuBarEventRelay(event: event, pid: pid) { [weak self] success in
            if let relay { self?.relays.removeAll { $0 === relay } }
            completion(success)
        }
        guard let relay else {
            logger.error("Unable to create event relay for pid \(pid, privacy: .public)")
            completion(false)
            return
        }
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
        if let newlyHostedStatusItem = records
            .filter({ !initialWindowIDs.contains($0.id) && $0.frame.width >= 30 && $0.frame.width <= 44 })
            .max(by: { $0.id < $1.id }) {
            return (newlyHostedStatusItem.id, newlyHostedStatusItem.frame)
        }
        return records.first(where: { $0.pid == getpid() }).map { ($0.id, $0.frame) }
    }

    private func currentFrame(windowID: CGWindowID) -> CGRect? { windowRecords().first { $0.id == windowID }?.frame }

    private func windowRecords() -> [(id: CGWindowID, pid: pid_t, title: String, frame: CGRect)] { Self.fetchWindowRecords() }

    private static func fetchWindowRecords() -> [(id: CGWindowID, pid: pid_t, title: String, frame: CGRect)] {
        let list = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 25,
                  let id = info[kCGWindowNumber as String] as? Int,
                  let pid = info[kCGWindowOwnerPID as String] as? Int,
                  let b = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            let frame = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
            guard frame.minY == 0, frame.height <= 40 else { return nil }
            return (CGWindowID(id), pid_t(pid), info[kCGWindowName as String] as? String ?? "", frame)
        }
    }
}
