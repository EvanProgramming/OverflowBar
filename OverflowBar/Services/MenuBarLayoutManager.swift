import AppKit
import ApplicationServices
import OSLog

/// Safe layout boundary for status-item management.
///
/// Older implementations moved status items by injecting global synthetic
/// Command-drag events. That is not an isolated window operation: if the
/// target process, WindowServer, or an event tap drops the matching mouse-up,
/// every application can observe a stuck button/hover state. Until status-item
/// placement has a supported non-input API, this manager deliberately performs
/// no mouse injection.
final class MenuBarLayoutManager {
    private let preferences: PreferencesStore
    private let logger = Logger(subsystem: "com.overflowbar.app", category: "layout")
    var onHiddenFramesChanged: (([CGRect]) -> Void)?

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    var isEnabled: Bool {
        get { preferences.layoutManagementEnabled }
        set { preferences.layoutManagementEnabled = newValue }
    }

    func hide(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, targetAttempt: Int = 0, completion: @escaping (Int) -> Void = { _ in }) {
        let moved = items.reduce(into: 0) { count, item in
            guard let element = item.axElement else { return }
            let leftEdge = NSScreen.screens.map { $0.frame.minX }.min() ?? 0
            let point = CGPoint(x: leftEdge - item.frame.width - 8, y: item.frame.minY)
            if setPosition(point, for: element) { count += 1 }
        }
        logger.info("AX-only layout moved \(moved, privacy: .public) of \(items.count, privacy: .public) items")
        completion(moved)
    }

    func reveal(_ item: MenuBarItem, restoreCursorLocation: CGPoint? = nil, completion: @escaping (Bool) -> Void) {
        reportDisabledOperation()
        completion(false)
    }

    func restore(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, completion: @escaping (Int) -> Void = { _ in }) {
        let moved = items.reduce(into: 0) { count, item in
            guard let element = item.axElement, setPosition(item.frame.origin, for: element) else { return }
            count += 1
        }
        logger.info("AX-only layout restored \(moved, privacy: .public) of \(items.count, privacy: .public) items")
        completion(moved)
    }

    func show(_ item: MenuBarItem) {
        guard let element = item.axElement else {
            reportDisabledOperation()
            return
        }
        _ = setPosition(item.frame.origin, for: element)
    }

    func restoreProtectedSystemItems(attempt: Int = 0, completion: @escaping (Int) -> Void = { _ in }) {
        reportDisabledOperation()
        completion(0)
    }

    private func reportDisabledOperation() {
        logger.warning("Synthetic status-item layout is disabled for pointer safety")
    }

    private func setPosition(_ point: CGPoint, for element: AXUIElement) -> Bool {
        var position = point
        guard let value = AXValueCreate(.cgPoint, &position) else { return false }
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXPositionAttribute as CFString, &settable) == .success,
              settable.boolValue else { return false }
        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value) == .success
    }
}
