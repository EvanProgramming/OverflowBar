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

    func hide(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, targetAttempt: Int = 0, completion: @escaping (Int) -> Void = { _ in }) {
        guard isEnabled else { completion(0); return }
        let managedWindowIDs = Set(items.compactMap(\.windowID))
        let managedSystemNames = protectedNames(for: items)
        restoreProtectedSystemItems(excluding: managedWindowIDs, excludingSystemNames: managedSystemNames) { [weak self] _ in
            self?.hideAfterRestoringProtectedItems(items, relativeTo: controlFrame, targetAttempt: targetAttempt, managedSystemNames: managedSystemNames, completion: completion)
        }
    }

    private func hideAfterRestoringProtectedItems(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, targetAttempt: Int, managedSystemNames: Set<String>, completion: @escaping (Int) -> Void) {
        guard isEnabled else { completion(0); return }
        guard let target = hiddenTargetWindow() else {
            guard targetAttempt < 10 else {
                logger.error("Hidden-section target did not appear after bounded retries")
                completion(0)
                return
            }
            logger.info("Control window pending; retrying attempt \(targetAttempt + 1, privacy: .public)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.hideAfterRestoringProtectedItems(items, relativeTo: controlFrame, targetAttempt: targetAttempt + 1, managedSystemNames: managedSystemNames, completion: completion)
            }
            return
        }
        logger.info("Hiding \(items.count, privacy: .public) items relative to window \(target.id, privacy: .public)")
        let managed = items.filter {
            $0.windowID != target.id
        }.filter(needsHiding)
        publishCurrentFrames(for: managed)
        hideSequentially(managed, index: 0, movedCount: 0) { [weak self] movedCount in
            self?.publishCurrentFrames(for: managed)
            let managedWindowIDs = Set(managed.compactMap(\.windowID))
            self?.restoreProtectedSystemItems(excluding: managedWindowIDs, excludingSystemNames: managedSystemNames) { _ in completion(movedCount) }
        }
    }

    func reveal(_ item: MenuBarItem, restoreCursorLocation: CGPoint? = nil, completion: @escaping (Bool) -> Void) {
        guard let target = controlTargetWindow() else { completion(false); return }
        // The hidden-section separator reaches the control item's left edge,
        // so the only valid temporary visible slot is immediately to its right.
        move(item, relativeTo: target.id, placement: .right, restoreCursorLocation: restoreCursorLocation, completion: completion)
    }

    func rehide(_ item: MenuBarItem, restoreCursorLocation: CGPoint? = nil, completion: @escaping (Bool) -> Void = { _ in }) {
        guard isEnabled, let target = hiddenTargetWindow() else { completion(false); return }
        move(item, relativeTo: target.id, placement: .left, restoreCursorLocation: restoreCursorLocation, completion: completion)
    }

    /// Returns true only while a managed item is still occupying the visible
    /// menu bar, so repair passes focus on actual duplicate icons.
    func needsHiding(_ item: MenuBarItem) -> Bool {
        guard item.windowID != nil else { return false }
        return isVisible(item)
    }

    /// Returns whether WindowServer currently places the item in a real menu
    /// bar slot. Hidden items intentionally retain their original window
    /// identity, but their frame is moved completely off the active display.
    /// Activation must distinguish that state from a visible item; using
    /// `needsHiding` for both meanings caused hidden right-clicks to be sent
    /// directly to invalid (negative) coordinates.
    func isVisible(_ item: MenuBarItem) -> Bool {
        guard let windowID = item.windowID else {
            // Accessibility-backed items are never moved by the layout
            // manager and therefore have no WindowServer ID. Their scanner
            // frame is the authoritative visible position.
            return Self.isVisibleMenuBarFrame(item.frame)
        }
        guard let frame = currentFrame(windowID: windowID) else { return false }
        return Self.isVisibleMenuBarFrame(frame)
    }

    /// Quartz screen coordinates captured before any synthetic menu-bar event.
    func currentPointerLocation() -> CGPoint? { CGEvent(source: nil)?.location }

    /// Reassociates WindowServer with the real pointer after a synthetic click.
    ///
    /// The order is intentional: Quartz documents that warping does not emit a
    /// mouse event, and associating before the warp can leave the hardware mouse
    /// and cursor in the disconnected state on recent macOS releases. Warp
    /// first, associate afterwards, then send a zero-delta move so other apps
    /// recompute hover/cursor tracking immediately.
    func restorePointerLocation(_ point: CGPoint?) {
        guard let point, Self.isValidPointerLocation(point) else { return }
        _ = CGWarpMouseCursorPosition(point)
        _ = CGAssociateMouseAndMouseCursorPosition(1)
        guard let source = CGEventSource(stateID: .hidSystemState),
              let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else { return }
        move.setIntegerValueField(.mouseEventDeltaX, value: 0)
        move.setIntegerValueField(.mouseEventDeltaY, value: 0)
        move.setIntegerValueField(.eventSourceUserData, value: Int64.random(in: 1...Int64.max))
        move.post(tap: .cgSessionEventTap)
    }

    func restore(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, completion: @escaping (Int) -> Void = { _ in }) {
        guard let target = controlTargetWindow() else { completion(0); return }
        restoreSequentially(Array(items.reversed()), index: 0, target: target, movedCount: 0, completion: completion)
    }

    func show(_ item: MenuBarItem) {
        guard let target = controlTargetWindow() else { return }
        move(item, relativeTo: target.id, placement: .left) { _ in }
    }

    func restoreProtectedSystemItems(attempt: Int = 0, excluding excludedWindowIDs: Set<CGWindowID> = [], excludingSystemNames: Set<String> = [], completion: @escaping (Int) -> Void = { _ in }) {
        guard let target = controlTargetWindow() else {
            guard attempt < 10 else {
                logger.error("Control target unavailable while restoring protected items")
                completion(0)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.restoreProtectedSystemItems(attempt: attempt + 1, excluding: excludedWindowIDs, excludingSystemNames: excludingSystemNames, completion: completion)
            }
            return
        }
        let hidden = windowRecords().filter {
            MenuBarSystemItemClassifier.isProtected($0.title, owner: $0.owner) &&
                $0.frame.maxX <= 0 &&
                !excludedWindowIDs.contains($0.id) &&
                !excludingSystemNames.contains($0.title) &&
                !excludingSystemNames.contains(MenuBarSystemItemClassifier.canonicalName($0.title, owner: $0.owner)) &&
                !(MenuBarSystemItemClassifier.isGenericControlCenterItem($0.title, owner: $0.owner) && excludingSystemNames.contains("Control Center Item"))
        }
        restoreProtectedSequentially(hidden, index: 0, target: target, movedCount: 0, completion: completion)
    }

    private func protectedNames(for items: [MenuBarItem]) -> Set<String> {
        var names = Set<String>()
        for item in items where item.isProtectedSystemItem {
            names.insert(item.title)
            if item.title == "Control Center Item" {
                names.insert("Control Center Item")
            }
        }
        return names
    }

    private func hideSequentially(_ items: [MenuBarItem], index: Int, movedCount: Int, completion: @escaping (Int) -> Void) {
        guard index < items.count else { completion(movedCount); return }
        guard let target = hiddenTargetWindow() else { completion(movedCount); return }
        let item = items[index]
        move(item, relativeTo: target.id, placement: .left) { [weak self] moved in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                guard let self, let refreshed = self.controlTargetWindow() else {
                    completion(movedCount + (moved ? 1 : 0))
                    return
                }
                self.restoreSequentially(items, index: index + 1, target: refreshed, movedCount: movedCount + (moved ? 1 : 0), completion: completion)
            }
        }
    }

    private func restoreProtectedSequentially(_ records: [(id: CGWindowID, pid: pid_t, title: String, owner: String, frame: CGRect)], index: Int, target: (id: CGWindowID, frame: CGRect), movedCount: Int, completion: @escaping (Int) -> Void) {
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

    private func move(_ item: MenuBarItem, relativeTo targetWindowID: CGWindowID, placement: Placement, attempt: Int = 1, restoreCursorLocation: CGPoint? = nil, completion: @escaping (Bool) -> Void) {
        // Capture before injecting the synthetic drag. At this point the
        // WindowServer location still matches the real hardware pointer,
        // including when the user clicked inside OverflowBar itself.
        let physicalPointerLocation = restoreCursorLocation ?? CGEvent(source: nil)?.location
        guard let itemWindowID = item.windowID, let ownerPID = item.ownerPID,
              currentFrame(windowID: itemWindowID) != nil,
              let targetFrame = currentFrame(windowID: targetWindowID),
              let source = CGEventSource(stateID: .privateState),
              let down = targetedEvent(type: .leftMouseDown, point: CGPoint(x: 20_000, y: 20_000), windowID: itemWindowID, pid: ownerPID, source: source, command: true),
              let up = targetedEvent(type: .leftMouseUp, point: CGPoint(x: placement == .left ? targetFrame.minX : targetFrame.maxX, y: targetFrame.midY), windowID: targetWindowID, pid: ownerPID, source: source, command: false) else {
            completion(false)
            return
        }
        relay(down, to: ownerPID) { [weak self] success in
            self?.logger.info("Mouse-down relay window \(itemWindowID, privacy: .public) success=\(success, privacy: .public)")
            guard success else { completion(false); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                self?.relay(up, to: ownerPID) { success in
                    self?.logger.info("Mouse-up relay window \(itemWindowID, privacy: .public) success=\(success, privacy: .public)")
                    if success, let physicalPointerLocation, Self.isValidPointerLocation(physicalPointerLocation) {
                        // The synthetic drag changes WindowServer's logical
                        // pointer location to the menu-bar target. Restore the
                        // last real hardware location without moving the user-visible cursor.
                        self?.restorePointerLocation(physicalPointerLocation)
                    }
                self?.verifyMove(item, relativeTo: targetWindowID, placement: placement, attempt: attempt, check: 0, restoreCursorLocation: physicalPointerLocation, completion: completion)
                }
            }
        }
    }

    private func verifyMove(_ item: MenuBarItem, relativeTo targetWindowID: CGWindowID, placement: Placement, attempt: Int, check: Int, restoreCursorLocation: CGPoint?, completion: @escaping (Bool) -> Void) {
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
            } else if check < 2 {
                self.verifyMove(item, relativeTo: targetWindowID, placement: placement, attempt: attempt, check: check + 1, restoreCursorLocation: restoreCursorLocation, completion: completion)
            } else if attempt < 3 {
                self.logger.info("Move verification window \(itemWindowID, privacy: .public) attempt \(attempt, privacy: .public) timed out")
                self.move(item, relativeTo: targetWindowID, placement: placement, attempt: attempt + 1, restoreCursorLocation: restoreCursorLocation, completion: completion)
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

    private static func isVisibleMenuBarFrame(_ frame: CGRect) -> Bool {
        guard frame.width > 4, frame.height > 4, frame.height <= 40 else { return false }
        return activeDisplayBounds().contains { display in
            frame.intersects(display) && abs(frame.minY - display.minY) <= 2
        }
    }

    private static func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return [] }
        return displays.prefix(Int(count)).map(CGDisplayBounds)
    }

    private static func isValidPointerLocation(_ point: CGPoint) -> Bool {
        guard point.x.isFinite, point.y.isFinite, point.x != 0 || point.y != 0 else { return false }
        return NSScreen.screens.contains { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayBounds(CGDirectDisplayID(number.uint32Value)).contains(point)
        }
    }

    private func windowRecords() -> [(id: CGWindowID, pid: pid_t, title: String, owner: String, frame: CGRect)] { Self.fetchWindowRecords() }

    private static func fetchWindowRecords() -> [(id: CGWindowID, pid: pid_t, title: String, owner: String, frame: CGRect)] {
        let list = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 25,
                  let id = info[kCGWindowNumber as String] as? Int,
                  let pid = info[kCGWindowOwnerPID as String] as? Int,
                  let b = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            let frame = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
            guard frame.minY == 0, frame.height <= 40 else { return nil }
            return (CGWindowID(id), pid_t(pid), info[kCGWindowName as String] as? String ?? "", info[kCGWindowOwnerName as String] as? String ?? "", frame)
        }
    }
}
