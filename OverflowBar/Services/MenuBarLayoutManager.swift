import AppKit
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
        reportDisabledOperation()
        completion(0)
    }

    func reveal(_ item: MenuBarItem, restoreCursorLocation: CGPoint? = nil, completion: @escaping (Bool) -> Void) {
        reportDisabledOperation()
        completion(false)
    }

    func restore(_ items: [MenuBarItem], relativeTo controlFrame: CGRect, completion: @escaping (Int) -> Void = { _ in }) {
        reportDisabledOperation()
        completion(0)
    }

    func show(_ item: MenuBarItem) {
        reportDisabledOperation()
    }

    func restoreProtectedSystemItems(attempt: Int = 0, completion: @escaping (Int) -> Void = { _ in }) {
        reportDisabledOperation()
        completion(0)
    }

    private func reportDisabledOperation() {
        logger.warning("Synthetic status-item layout is disabled for pointer safety")
    }
}
