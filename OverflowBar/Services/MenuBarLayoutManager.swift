import AppKit
import ApplicationServices
import CoreGraphics
import OSLog

/// Moves status-item windows by sending WindowServer-targeted Command-drag events.
/// The synthetic drag temporarily updates the system pointer, then restores it
/// to the real pre-operation location captured before the move.
final class MenuBarLayoutManager {
    private enum Placement { case left, right }
    private let logger = Logger(subsystem: "com.overflowbar.app", category: "layout")
    private let preferences: PreferencesStore
    private let initialWindowIDs: Set<CGWindowID>
    private var controlStatusItemWindowID: CGWindowID?
    private var hiddenStatusItemWindowID: CGWindowID?
    var onHiddenFramesChanged: (([CGRect]) -> Void)?
    init(preferences: PreferencesStore) {
        self.preferences = preferences
        initialWindowIDs = Set(Self.fetchWindowRecords().map(\.id))
    }

    var isEnabled: Bool {
        get { preferences.layoutManagementEnabled }
        set { preferences.layoutManagementEnabled = newValue }
    }

    /// macOS 26 does not expose the stable autosave name as the hosted
    /// status-window title. Keep the WindowServer IDs published by
    /// StatusBarController so layout operations can target the two app-owned
    /// hosts without guessing from Control Center's provisional Item-0/1
    /// names.
    func setStatusItemWindowIDs(control: CGWindowID?, hidden: CGWindowID?) {
        controlStatusItemWindowID = control
        hiddenStatusItemWindowID = hidden
        logger.info("Published status window IDs control=\(control ?? 0, privacy: .public) hidden=\(hidden ?? 0, privacy: .public)")
    }

    func hide(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, targetAttempt: Int = 0, completion: @escaping (Int) -> Void = { _ in }) {
        guard isEnabled else { completion(0); return }
        if #available(macOS 27.0, *) {
            // The macOS 27 menu bar is a composite host. Never send the old
            // per-window Command-drag event to that host: it cannot hide a
            // single icon and can move or disturb the whole bar. AX-backed
            // children are attempted individually; unsupported children are
            // intentionally left visible and reported by the caller.
            completion(hideAccessibilityItems(items.filter { $0.axElement != nil }))
            return
        }
        if #available(macOS 26.0, *) {
            hideWindowBacked(items, relativeTo: controlFrame, targetAttempt: targetAttempt, completion: completion)
        } else {
            let accessibilityItems = items.filter { $0.windowID == nil && $0.axElement != nil }
            let windowItems = items.filter { $0.windowID != nil || $0.axElement == nil }
            let movedAccessibility = hideAccessibilityItems(accessibilityItems)
            guard !windowItems.isEmpty else { completion(movedAccessibility); return }
            hideWindowBacked(windowItems, relativeTo: controlFrame, targetAttempt: targetAttempt) { moved in
                completion(movedAccessibility + moved)
            }
        }
    }

    private func hideWindowBacked(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, targetAttempt: Int, completion: @escaping (Int) -> Void) {
        let managedWindowIDs = Set(items.compactMap(\.windowID))
        let managedSystemNames = protectedNames(for: items)
        restoreProtectedSystemItems(excluding: managedWindowIDs, excludingSystemNames: managedSystemNames) { [weak self] _ in
            self?.hideAfterRestoringProtectedItems(items, relativeTo: controlFrame, targetAttempt: targetAttempt, managedSystemNames: managedSystemNames, completion: completion)
        }
    }

    private func hideAfterRestoringProtectedItems(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, targetAttempt: Int, managedSystemNames: Set<String>, completion: @escaping (Int) -> Void) {
        guard isEnabled else { completion(0); return }
        guard let target = hiddenTargetWindow(), Self.isVisibleMenuBarFrame(target.frame) else {
            guard targetAttempt < 20 else {
                logger.error("Visible hidden-section staging target did not appear after bounded retries")
                completion(0)
                return
            }
            logger.info("Hidden staging target pending; retrying attempt \(targetAttempt + 1, privacy: .public)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.hideAfterRestoringProtectedItems(items, relativeTo: controlFrame, targetAttempt: targetAttempt + 1, managedSystemNames: managedSystemNames, completion: completion)
            }
            return
        }
        logger.info("Hiding \(items.count, privacy: .public) items relative to window \(target.id, privacy: .public)")
        let managed = items.filter {
            $0.windowID != target.id
        }.filter { !$0.isAlwaysVisibleSystemItem }
         .filter(needsHiding)
        publishCurrentFrames(for: managed)
        hideSequentially(managed, index: 0, movedCount: 0) { [weak self] movedCount in
            self?.publishCurrentFrames(for: managed)
            let managedWindowIDs = Set(managed.compactMap(\.windowID))
            self?.restoreProtectedSystemItems(excluding: managedWindowIDs, excludingSystemNames: managedSystemNames) { _ in completion(movedCount) }
        }
    }

    func reveal(_ item: MenuBarItem, restoreCursorLocation: CGPoint? = nil, completion: @escaping (Bool) -> Void) {
        if #available(macOS 27.0, *) {
            guard let element = item.axElement else { completion(false); return }
            completion(setAXPosition(item.frame.origin, for: element))
            return
        }
        if #unavailable(macOS 26.0), item.windowID == nil, let element = item.axElement {
            completion(setAXPosition(item.frame.origin, for: element))
            return
        }
        guard let target = controlTargetWindow() else { completion(false); return }
        // The hidden-section separator reaches the control item's left edge,
        // so the only valid temporary visible slot is immediately to its right.
        move(item, relativeTo: target.id, placement: .right, restoreCursorLocation: restoreCursorLocation, completion: completion)
    }

    func rehide(_ item: MenuBarItem, restoreCursorLocation: CGPoint? = nil, completion: @escaping (Bool) -> Void = { _ in }) {
        if #available(macOS 27.0, *) {
            guard isEnabled, let element = item.axElement else { completion(false); return }
            completion(setAXPosition(hiddenAXPosition(for: item), for: element))
            return
        }
        if #unavailable(macOS 26.0), item.windowID == nil, let element = item.axElement {
            completion(setAXPosition(hiddenAXPosition(for: item), for: element))
            return
        }
        guard isEnabled, let target = hiddenTargetWindow() else { completion(false); return }
        move(item, relativeTo: target.id, placement: .left, restoreCursorLocation: restoreCursorLocation, completion: completion)
    }

    /// Returns true only while a managed item is still occupying the visible
    /// menu bar, so repair passes focus on actual duplicate icons.
    func needsHiding(_ item: MenuBarItem) -> Bool {
        // macOS keeps active privacy/media indicators visible. These
        // Control Center windows are not draggable status items, so do not
        // report a failed layout repair when the system leaves them in place.
        if item.isAlwaysVisibleSystemItem { return false }
        guard item.windowID != nil || item.axElement != nil else { return false }
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
            guard let element = item.axElement, let frame = currentAXFrame(for: element) else {
                return Self.isVisibleMenuBarFrame(item.frame)
            }
            return Self.isVisibleMenuBarFrame(frame)
        }
        guard let frame = currentFrame(windowID: windowID) else { return false }
        return Self.isVisibleMenuBarFrame(frame)
    }

    /// Quartz screen coordinates captured before any synthetic menu-bar event.
    func currentPointerLocation() -> CGPoint? { CGEvent(source: nil)?.location }

    /// Kept as a compatibility hook for older activation call sites. Move
    /// operations restore the pointer inside `postDrag`; this method is not a
    /// second restoration pass.
    func restorePointerLocation(_ point: CGPoint?) {
        // Intentionally empty.
    }

    func restore(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, completion: @escaping (Int) -> Void = { _ in }) {
        if #available(macOS 27.0, *) {
            completion(restoreAccessibilityItems(items.filter { $0.axElement != nil }))
            return
        }
        if #unavailable(macOS 26.0) {
            let accessibilityItems = items.filter { $0.windowID == nil && $0.axElement != nil }
            let windowItems = items.filter { $0.windowID != nil || $0.axElement == nil }
            let restoredAccessibility = restoreAccessibilityItems(accessibilityItems)
            guard !windowItems.isEmpty else { completion(restoredAccessibility); return }
            guard let target = controlTargetWindow() else { completion(restoredAccessibility); return }
            restoreSequentially(Array(windowItems.reversed()), index: 0, target: target, movedCount: restoredAccessibility, completion: completion)
            return
        }
        guard let target = controlTargetWindow() else { completion(0); return }
        restoreSequentially(Array(items.reversed()), index: 0, target: target, movedCount: 0, completion: completion)
    }

    func show(_ item: MenuBarItem) {
        if #available(macOS 27.0, *) {
            guard let element = item.axElement else { return }
            _ = setAXPosition(item.frame.origin, for: element)
            return
        }
        if #unavailable(macOS 26.0), item.windowID == nil, let element = item.axElement {
            _ = setAXPosition(item.frame.origin, for: element)
            return
        }
        guard let target = controlTargetWindow() else { return }
        move(item, relativeTo: target.id, placement: .left) { _ in }
    }

    func restoreProtectedSystemItems(attempt: Int = 0, excluding excludedWindowIDs: Set<CGWindowID> = [], excludingSystemNames: Set<String> = [], completion: @escaping (Int) -> Void = { _ in }) {
        guard let target = controlTargetWindow() else {
            guard attempt < 3 else {
                logger.error("Control target unavailable while restoring protected items")
                completion(0)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
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

    /// macOS 15 still exposes some third-party status items only through AX.
    /// Their position attribute is the supported compatibility fallback for
    /// those items; WindowServer-targeted drags remain the primary macOS 26
    /// path because Control Center-owned items do not expose a settable AX
    /// position there.
    private func hideAccessibilityItems(_ items: [MenuBarItem]) -> Int {
        items.reduce(into: 0) { moved, item in
            guard let element = item.axElement,
                  setAXPosition(hiddenAXPosition(for: item), for: element) else { return }
            moved += 1
        }
    }

    private func restoreAccessibilityItems(_ items: [MenuBarItem]) -> Int {
        items.reduce(into: 0) { restored, item in
            guard let element = item.axElement,
                  setAXPosition(item.frame.origin, for: element) else { return }
            restored += 1
        }
    }

    private func hiddenAXPosition(for item: MenuBarItem) -> CGPoint {
        let leftEdge = NSScreen.screens.map(\.frame.minX).min() ?? 0
        return CGPoint(x: leftEdge - item.frame.width - 16, y: item.frame.minY)
    }

    private func setAXPosition(_ point: CGPoint, for element: AXUIElement) -> Bool {
        var position = point
        guard let value = AXValueCreate(.cgPoint, &position) else { return false }
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXPositionAttribute as CFString, &settable) == .success,
              settable.boolValue else { return false }
        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value) == .success
    }

    private func currentAXFrame(for element: AXUIElement) -> CGRect? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let position = value, CFGetTypeID(position) == AXValueGetTypeID(),
              AXValueGetType(position as! AXValue) == .cgPoint else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &point)
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
              let sizeValue = value, CFGetTypeID(sizeValue) == AXValueGetTypeID(),
              AXValueGetType(sizeValue as! AXValue) == .cgSize else { return nil }
        var size = CGSize.zero
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    private func hideSequentially(_ items: [MenuBarItem], index: Int, movedCount: Int, completion: @escaping (Int) -> Void) {
        guard index < items.count else { completion(movedCount); return }
        guard let target = hiddenTargetWindow(), Self.isVisibleMenuBarFrame(target.frame) else {
            completion(movedCount)
            return
        }
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
              let itemFrame = currentFrame(windowID: itemWindowID),
              let targetFrame = currentFrame(windowID: targetWindowID),
              let source = eventSource(for: ownerPID) else {
            completion(false)
            return
        }
        // Control Center requires the synthetic drag coordinates to start on
        // the visible source item. The WindowServer window fields identify
        // the source/destination; keeping the actual points on an active
        // display means a hidden off-screen target cannot clamp the user's
        // hardware pointer. On reveal the hidden source is invalid, so the
        // target's visible frame becomes the safe fallback for both events.
        let itemPoint = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
        let startPoint = safeEventPoint(preferred: itemPoint, fallback: targetFrame)
        guard let destinationPoint = destinationPoint(for: placement, itemFrame: itemFrame, targetFrame: targetFrame) else {
            logger.error("Refusing menu-bar move because the destination edge is off the active display")
            completion(false)
            return
        }
        guard let down = targetedEvent(type: .leftMouseDown, point: startPoint, windowID: itemWindowID, pid: ownerPID, source: source, command: true),
              let dragged = targetedEvent(type: .leftMouseDragged, point: destinationPoint, windowID: targetWindowID, pid: ownerPID, source: source, command: true),
              let up = targetedEvent(type: .leftMouseUp, point: destinationPoint, windowID: targetWindowID, pid: ownerPID, source: source, command: true) else {
            completion(false)
            return
        }
        postDrag(
            down: down,
            dragged: dragged,
            up: up,
            ownerPID: ownerPID,
            restoreCursorLocation: physicalPointerLocation
        ) { [weak self] success in
            guard let self, success else { completion(false); return }
            self.verifyMove(item, relativeTo: targetWindowID, placement: placement, attempt: attempt, check: 0, restoreCursorLocation: physicalPointerLocation, completion: completion)
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

    /// Posts the complete drag gesture through WindowServer. A down/up pair
    /// alone is treated as a click by macOS 26; the dragged event is required
    /// for Control Center's hosted status items. The gesture uses one bounded
    /// jump instead of an off-screen or multi-step path, which avoids the
    /// notch dead-zone while keeping every coordinate on an active display.
    private func postDrag(
        down: CGEvent,
        dragged: CGEvent,
        up: CGEvent,
        ownerPID: pid_t,
        restoreCursorLocation: CGPoint?,
        completion: @escaping (Bool) -> Void
    ) {
        let tap: CGEventTapLocation = isControlCenter(ownerPID) ? .cghidEventTap : .cgSessionEventTap
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            down.post(tap: tap)
            usleep(80_000)
            dragged.post(tap: tap)
            usleep(80_000)
            up.post(tap: tap)
            usleep(140_000)
            if let restoreCursorLocation,
               Self.activeDisplayBounds().contains(where: { $0.contains(restoreCursorLocation) }),
               let restore = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: restoreCursorLocation, mouseButton: .left) {
                // This is the real pointer location captured before the
                // operation, never a synthetic off-screen or test coordinate.
                restore.post(tap: .cghidEventTap)
            }
            DispatchQueue.main.async {
                self?.logger.info("Posted Command-drag window event via \(tap == .cghidEventTap ? "hid" : "session", privacy: .public)")
                completion(true)
            }
        }
    }

    private func eventSource(for pid: pid_t) -> CGEventSource? {
        let state: CGEventSourceStateID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.controlcenter"
            ? .hidSystemState
            : .privateState
        return CGEventSource(stateID: state)
    }

    private func isControlCenter(_ pid: pid_t) -> Bool {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.controlcenter"
    }

    private func destinationPoint(for placement: Placement, itemFrame: CGRect, targetFrame: CGRect) -> CGPoint? {
        let x: CGFloat
        switch placement {
        case .left:
            // Hiding means placing the item immediately before the staging
            // host. The host is compacted by StatusBarController for the
            // duration of a hide transaction, so this edge stays on-screen;
            // never fall back to an interior point, which would place the
            // item back in the visible section.
            let edge = CGPoint(x: targetFrame.minX - 1, y: targetFrame.midY)
            guard Self.activeDisplayBounds().contains(where: { $0.contains(edge) }) else { return nil }
            return edge
        case .right:
            // Drop just beyond the visible control item. Clamp below in
            // `safeEventPoint` if the control item is near a display edge.
            x = targetFrame.maxX + max(2, min(itemFrame.width * 0.25, 8))
        }
        return safeEventPoint(preferred: CGPoint(x: x, y: targetFrame.midY), fallback: targetFrame)
    }

    /// All synthetic drag events must carry an on-screen cursor coordinate.
    /// The target window fields select the status-item source/destination;
    /// using an off-screen point (20,000 or a negative hidden-section frame)
    /// makes WindowServer clamp the logical pointer to the top-left corner.
    private func safeEventPoint(preferred: CGPoint?, fallback: CGRect) -> CGPoint {
        let displays = Self.activeDisplayBounds()
        if let preferred, displays.contains(where: { $0.contains(preferred) }) {
            return preferred
        }
        if let display = displays.first {
            let x = min(max(fallback.midX, display.minX + 8), display.maxX - 8)
            let y = min(max(fallback.midY, display.minY + 8), display.maxY - 8)
            return CGPoint(x: x, y: y)
        }
        return CGPoint(x: 8, y: 8)
    }

    private func targetedEvent(type: CGEventType, point: CGPoint, windowID: CGWindowID, pid: pid_t, source: CGEventSource, command: Bool) -> CGEvent? {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { return nil }
        event.flags = command ? .maskCommand : []
        // Direct HID posting is the reliable path for macOS 26's protected
        // Control Center host. Supplying an event target PID makes WindowServer
        // drop the hosted drag, so retain that field only for ordinary owners.
        if !isControlCenter(pid) {
            event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        }
        event.setIntegerValueField(.eventSourceUserData, value: Int64.random(in: 1...Int64.max))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(windowID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(windowID))
        event.setIntegerValueField(CGEventField(rawValue: 0x33)!, value: Int64(windowID))
        return event
    }

    private func controlTargetWindow() -> (id: CGWindowID, frame: CGRect)? {
        let records = windowRecords()
        if let controlStatusItemWindowID,
           let control = records.first(where: { $0.id == controlStatusItemWindowID }) {
            return (control.id, control.frame)
        }
        if let overflowBar = records.first(where: { $0.title == "OverflowBarControlItem" }) {
            return (overflowBar.id, overflowBar.frame)
        }
        return records
            .filter { $0.pid == getpid() && $0.frame.width <= 100 && $0.frame.height > 1 }
            .min(by: { $0.id < $1.id })
            .map { ($0.id, $0.frame) }
    }

    private func hiddenTargetWindow() -> (id: CGWindowID, frame: CGRect)? {
        let records = windowRecords()
        if let hiddenStatusItemWindowID,
           let hidden = records.first(where: { $0.id == hiddenStatusItemWindowID }) {
            return (hidden.id, hidden.frame)
        }
        if let hidden = records.first(where: { $0.title == "OverflowBarHiddenSection" }) {
            return (hidden.id, hidden.frame)
        }
        return records
            .filter { $0.pid == getpid() && !initialWindowIDs.contains($0.id) && $0.frame.width > 1_000 }
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

    private static func isMenuBarWindowFrame(_ frame: CGRect) -> Bool {
        if frame.maxX <= 0 && frame.minY >= 0 && frame.maxY <= 40 {
            return frame.width > 4 && frame.height > 4
        }
        return isVisibleMenuBarFrame(frame)
    }

    private static func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return [] }
        return displays.prefix(Int(count)).map(CGDisplayBounds)
    }

    private func windowRecords() -> [(id: CGWindowID, pid: pid_t, title: String, owner: String, frame: CGRect)] { Self.fetchWindowRecords() }

    private static func fetchWindowRecords() -> [(id: CGWindowID, pid: pid_t, title: String, owner: String, frame: CGRect)] {
        let list = MenuBarWindowServer.windowInfo()
        return list.compactMap { info -> (id: CGWindowID, pid: pid_t, title: String, owner: String, frame: CGRect)? in
            guard MenuBarWindowServer.isStatusItemLayer(info),
                  let id = MenuBarWindowServer.integer(kCGWindowNumber as String, in: info),
                  let pid = MenuBarWindowServer.integer(kCGWindowOwnerPID as String, in: info),
                  let frame = MenuBarWindowServer.bounds(in: info) else { return nil }
            // Quartz window coordinates are global. On a vertically arranged
            // multi-display setup, or on systems that place the menu bar at a
            // non-zero global Y coordinate, the primary-display assumption
            // `frame.minY == 0` drops every real status-item window. Keep the
            // layout path aligned with the scanner's display-aware geometry
            // check, while still retaining offscreen hidden-section windows.
            // AppKit's macOS 26 hosted status windows can briefly report a
            // provisional frame that does not pass the global display check;
            // retain only our own layer-25 windows in that case so the IDs
            // published by StatusBarController remain usable during startup.
            guard pid_t(pid) == getpid() || Self.isMenuBarWindowFrame(frame) else { return nil }
            return (CGWindowID(id), pid_t(pid), info[kCGWindowName as String] as? String ?? "", info[kCGWindowOwnerName as String] as? String ?? "", frame)
        }
    }
}
