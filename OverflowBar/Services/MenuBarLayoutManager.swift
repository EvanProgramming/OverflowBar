import AppKit
import CoreGraphics
import OSLog

/// Moves status-item windows by sending WindowServer-targeted Command-drag events.
/// The physical mouse cursor is never moved.
final class MenuBarLayoutManager {
    private enum Placement { case left, right }
    private let protectedSystemTitles = Set(["Battery", "Siri", "WiFi", "Clock", "BentoBox-0", "BentoBox"])
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

    func hide(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, targetAttempt: Int = 0, completion: @escaping (Int) -> Void = { _ in }) {
        guard isEnabled else { completion(0); return }
        restoreProtectedSystemItems { [weak self] _ in
            self?.hideAfterRestoringProtectedItems(items, relativeTo: controlFrame, targetAttempt: targetAttempt, completion: completion)
        }
    }

    private func hideAfterRestoringProtectedItems(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, targetAttempt: Int, completion: @escaping (Int) -> Void) {
        guard isEnabled else { completion(0); return }
        guard let target = hiddenTargetWindow() else {
            guard targetAttempt < 10 else {
                logger.error("Hidden-section target did not appear after bounded retries")
                completion(0)
                return
            }
            logger.info("Control window pending; retrying attempt \(targetAttempt + 1, privacy: .public)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.hideAfterRestoringProtectedItems(items, relativeTo: controlFrame, targetAttempt: targetAttempt + 1, completion: completion)
            }
            return
        }
        logger.info("Hiding \(items.count, privacy: .public) items relative to window \(target.id, privacy: .public)")
        let protectedWindowIDs = Set(windowRecords().filter { protectedSystemTitles.contains($0.title) }.map(\.id))
        let managed = items.filter {
            !$0.isProtectedSystemItem && $0.windowID != target.id && $0.windowID.map(protectedWindowIDs.contains) != true
        }
        publishCurrentFrames(for: managed)
        hideSequentially(managed, index: 0, movedCount: 0) { [weak self] movedCount in
            self?.publishCurrentFrames(for: managed)
            self?.restoreProtectedSystemItems { _ in completion(movedCount) }
        }
    }

    func reveal(_ item: MenuBarItem, completion: @escaping (Bool) -> Void) {
        guard let target = controlTargetWindow() else { completion(false); return }
        // The hidden-section separator reaches the control item's left edge,
        // so the only valid temporary visible slot is immediately to its right.
        move(item, relativeTo: target.id, placement: .right, completion: completion)
    }

    func rehide(_ item: MenuBarItem, completion: @escaping (Bool) -> Void = { _ in }) {
        guard isEnabled, let target = hiddenTargetWindow() else { completion(false); return }
        move(item, relativeTo: target.id, placement: .left, completion: completion)
    }

    func restore(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, completion: @escaping (Int) -> Void = { _ in }) {
        guard let target = controlTargetWindow() else { completion(0); return }
        restoreSequentially(Array(items.reversed()), index: 0, target: target, movedCount: 0, completion: completion)
    }

    func show(_ item: MenuBarItem) {
        guard let target = controlTargetWindow() else { return }
        move(item, relativeTo: target.id, placement: .left) { _ in }
    }

    func restoreProtectedSystemItems(attempt: Int = 0, completion: @escaping (Int) -> Void = { _ in }) {
        guard let target = controlTargetWindow() else {
            guard attempt < 10 else {
                logger.error("Control target unavailable while restoring protected items")
                completion(0)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.restoreProtectedSystemItems(attempt: attempt + 1, completion: completion)
            }
            return
        }
        let hidden = windowRecords().filter {
            protectedSystemTitles.contains($0.title) && $0.frame.maxX <= 0
        }
        restoreProtectedSequentially(hidden, index: 0, target: target, movedCount: 0, completion: completion)
    }

    private func hideSequentially(_ items: [MenuBarItem], index: Int, movedCount: Int, completion: @escaping (Int) -> Void) {
        guard index < items.count else { completion(movedCount); return }
        guard let target = hiddenTargetWindow() else { completion(movedCount); return }
        let item = items[index]
        move(item, relativeTo: target.id, placement: .left) { [weak self] moved in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                self?.hideSequentially(items, index: index + 1, movedCount: movedCount + (moved ? 1 : 0), completion: completion)
            }
        }
    }

    private func publishCurrentFrames(for items: [MenuBarItem]) {
        let frames = items.compactMap { item in
            item.windowID.flatMap(currentFrame(windowID:))
        }
        onHiddenFramesChanged?(frames)
    }

    private func restoreSequentially(_ items: [MenuBarItem], index: Int, target: (id: CGWindowID, frame: CGRect), movedCount: Int, completion: @escaping (Int) -> Void) {
        guard index < items.count else { completion(movedCount); return }
        let item = items[index]
        move(item, relativeTo: target.id, placement: .left) { [weak self] moved in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                guard let self, let refreshed = self.controlTargetWindow() else {
                    completion(movedCount + (moved ? 1 : 0))
                    return
                }
                self.restoreSequentially(items, index: index + 1, target: refreshed, movedCount: movedCount + (moved ? 1 : 0), completion: completion)
            }
        }
    }

    private func restoreProtectedSequentially(_ records: [(id: CGWindowID, pid: pid_t, title: String, frame: CGRect)], index: Int, target: (id: CGWindowID, frame: CGRect), movedCount: Int, completion: @escaping (Int) -> Void) {
        guard index < records.count else { completion(movedCount); return }
        let record = records[index]
        let item = MenuBarItem(
            id: "protected|\(record.title)",
            title: record.title,
            ownerName: "System Menu Bar",
            bundleIdentifier: nil,
            frame: record.frame,
            axElement: nil,
            isSelected: false,
            supportsPressAction: false,
            windowID: record.id,
            ownerPID: record.pid
        )
        move(item, relativeTo: target.id, placement: .right) { [weak self] moved in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                guard let self, let refreshed = self.controlTargetWindow() else {
                    completion(movedCount + (moved ? 1 : 0))
                    return
                }
                self.restoreProtectedSequentially(records, index: index + 1, target: refreshed, movedCount: movedCount + (moved ? 1 : 0), completion: completion)
            }
        }
    }

    private func move(_ item: MenuBarItem, relativeTo targetWindowID: CGWindowID, placement: Placement, attempt: Int = 1, completion: @escaping (Bool) -> Void) {
        // CGEvent mouse locations update the system's logical pointer position
        // even though the event is targeted at another process. Keep the real
        // pointer location and put it back once the internal drag is complete.
        let cursorLocation = restorableCursorLocation()
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
                    if let cursorLocation { CGWarpMouseCursorPosition(cursorLocation) }
                    self?.verifyMove(item, relativeTo: targetWindowID, placement: placement, attempt: attempt, check: 0, completion: completion)
                }
            }
        }
    }

    private func verifyMove(_ item: MenuBarItem, relativeTo targetWindowID: CGWindowID, placement: Placement, attempt: Int, check: Int, completion: @escaping (Bool) -> Void) {
        guard let itemWindowID = item.windowID else { completion(false); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { completion(false); return }
            let itemFrame = self.currentFrame(windowID: itemWindowID)
            let targetFrame = self.currentFrame(windowID: targetWindowID)
            let moved: Bool
            switch placement {
            case .left: moved = abs((itemFrame?.maxX ?? -.infinity) - (targetFrame?.minX ?? .infinity)) < 1
            case .right: moved = abs((itemFrame?.minX ?? -.infinity) - (targetFrame?.maxX ?? .infinity)) < 1
            }
            if moved {
                self.logger.info("Move verification window \(itemWindowID, privacy: .public) attempt \(attempt, privacy: .public) moved=true")
                completion(true)
            } else if check < 15 {
                self.verifyMove(item, relativeTo: targetWindowID, placement: placement, attempt: attempt, check: check + 1, completion: completion)
            } else if attempt < 3 {
                self.logger.info("Move verification window \(itemWindowID, privacy: .public) attempt \(attempt, privacy: .public) timed out")
                self.move(item, relativeTo: targetWindowID, placement: placement, attempt: attempt + 1, completion: completion)
            } else {
                self.logger.info("Move verification window \(itemWindowID, privacy: .public) failed")
                completion(false)
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

    private func hiddenTargetWindow() -> (id: CGWindowID, frame: CGRect)? {
        let records = windowRecords()
        if let hidden = records.first(where: { $0.title == "OverflowBarHiddenSection" }) {
            return (hidden.id, hidden.frame)
        }
        return records
            .filter { !initialWindowIDs.contains($0.id) && $0.frame.width > 1_000 }
            .max(by: { $0.frame.width < $1.frame.width })
            .map { ($0.id, $0.frame) }
    }

    private func currentFrame(windowID: CGWindowID) -> CGRect? { windowRecords().first { $0.id == windowID }?.frame }

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
