import AppKit
import CoreGraphics

/// Reorders user-selected status items around OverflowBar's control item.
///
/// macOS has no supported per-item hide API. This opt-in manager uses the same
/// Command-drag gesture available to users in the menu bar: selected items are
/// placed to the left of the OverflowBar control item, where the system clips
/// them before the control item when space is constrained.
final class MenuBarLayoutManager {
    private let preferences: PreferencesStore
    private var rehideWorkItems = [String: DispatchWorkItem]()

    init(preferences: PreferencesStore) { self.preferences = preferences }

    var isEnabled: Bool {
        get { preferences.layoutManagementEnabled }
        set { preferences.layoutManagementEnabled = newValue }
    }

    /// Moves selected items into the hidden section immediately left of the control item.
    func hide(_ items: [MenuBarItem], relativeTo controlFrame: CGRect) {
        guard isEnabled else { return }
        for item in items.sorted(by: { $0.frame.minX > $1.frame.minX }) {
            move(item, to: CGPoint(x: controlFrame.minX - 5, y: controlFrame.midY))
        }
    }

    /// Temporarily returns a single item to the visible section, then hides it again.
    func reveal(_ item: MenuBarItem, relativeTo controlFrame: CGRect, rehideAfter delay: TimeInterval = 2) {
        rehideWorkItems[item.id]?.cancel()
        move(item, to: CGPoint(x: controlFrame.maxX + 8, y: controlFrame.midY))
        guard isEnabled else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.move(item, to: CGPoint(x: controlFrame.minX - 5, y: controlFrame.midY))
        }
        rehideWorkItems[item.id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// Returns all managed items to the visible side of the OverflowBar control item.
    func restore(_ items: [MenuBarItem], relativeTo controlFrame: CGRect) {
        rehideWorkItems.values.forEach { $0.cancel() }
        rehideWorkItems.removeAll()
        for item in items.sorted(by: { $0.frame.minX < $1.frame.minX }) {
            move(item, to: CGPoint(x: controlFrame.maxX + 8, y: controlFrame.midY))
        }
    }

    private func move(_ item: MenuBarItem, to destination: CGPoint) {
        let origin = CGPoint(x: item.frame.midX, y: item.frame.midY)
        guard origin.distance(to: destination) > 4,
              let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: origin, mouseButton: .left),
              let drag = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: destination, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: destination, mouseButton: .left) else { return }
        down.flags = .maskCommand
        drag.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        drag.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat { hypot(x - other.x, y - other.y) }
}
