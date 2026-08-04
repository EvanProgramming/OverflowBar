import AppKit
import ApplicationServices

/// Reads menu-bar status windows from WindowServer without blocking on
/// per-process Accessibility IPC.
final class MenuBarScanner {
    private let excludedTitles = Set(["OverflowBarControlItem", "OverflowBarHiddenSection"])
    func scan(selectedIDs: Set<String>) -> [MenuBarItem] {
        // WindowServer is the authoritative, bounded source for status-item
        // windows. Accessibility calls are intentionally not performed here:
        // AXUIElementCopyAttributeValue can block indefinitely while a login
        // item or Control Center is rebuilding its menu bar, which previously
        // froze the application's main actor during refresh/hover.
        return scanWindowBackedItems(selectedIDs: selectedIDs)
    }

    /// macOS 26 exposes most menu bar controls as Control Center-owned windows.
    /// This public window-list fallback discovers those controls even when the
    /// originating app does not publish an Accessibility menu-bar element.
    private func scanWindowBackedItems(selectedIDs: Set<String>) -> [MenuBarItem] {
        // Hidden-section items are deliberately moved offscreen. They must
        // remain in the settings and overflow panel when either is refreshed.
        let options: CGWindowListOption = [.excludeDesktopElements]
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates: [(identifier: Int, ownerPID: Int, title: String, owner: String, ownerKey: String, appIcon: NSImage?, frame: CGRect)] = windows.compactMap { window in
            guard (window[kCGWindowLayer as String] as? Int) == 25,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let identifier = window[kCGWindowNumber as String] as? Int,
                  let ownerPID = window[kCGWindowOwnerPID as String] as? Int else { return nil }
            guard ownerPID != Int(getpid()) else { return nil }
            let title = (window[kCGWindowName as String] as? String) ?? "Menu Bar Item"
            guard !excludedTitles.contains(title) else { return nil }
            let owner = (window[kCGWindowOwnerName as String] as? String) ?? "System Menu Bar"
            let runningApp = NSRunningApplication(processIdentifier: pid_t(ownerPID))
            // macOS can report the same Control Center status item with either
            // the localized owner name or its bundle identifier. Keep one
            // stable key so selections survive WindowServer refreshes.
            let rawOwnerKey = runningApp?.bundleIdentifier ?? owner
            let ownerKey = rawOwnerKey == "com.apple.controlcenter" || owner == "Control Center"
                ? "Control Center"
                : rawOwnerKey
            // Control Center's generic application icon is a white rounded
            // square, not the status item's icon. Keep it out of the panel so
            // the item-specific capture/fallback symbol can be used instead.
            let applicationIcon = ownerKey == "Control Center" ? nil : runningApp?.icon
            let frame = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            guard isMenuBarWindowFrame(frame), frame.width > 4, frame.height > 4, frame.height <= 40 else { return nil }
            return (identifier, ownerPID, title, owner, ownerKey, applicationIcon, frame)
        }
        var occurrences: [String: Int] = [:]
        var legacyOccurrences: [String: Int] = [:]
        return candidates.sorted { $0.frame.minX > $1.frame.minX }.map { candidate in
            let occurrenceKey = "\(candidate.ownerKey)|\(candidate.title)"
            let occurrence = occurrences[occurrenceKey, default: 0]
            occurrences[occurrenceKey] = occurrence + 1
            let legacyOccurrence = legacyOccurrences[candidate.title, default: 0]
            legacyOccurrences[candidate.title] = legacyOccurrence + 1
            let isProtected = MenuBarSystemItemClassifier.isProtected(candidate.title, owner: candidate.ownerKey)
            let title = isProtected ? MenuBarSystemItemClassifier.canonicalName(candidate.title, owner: candidate.ownerKey) : candidate.title
            let id = isProtected ? "system|\(title)|\(occurrence)" : "window|\(candidate.ownerKey)|\(candidate.title)|\(occurrence)"
            let alternateOwnerKey = candidate.ownerKey == "Control Center" ? "com.apple.controlcenter" : candidate.ownerKey
            let alternateID = "window|\(alternateOwnerKey)|\(candidate.title)|\(occurrence)"
            let legacyID = "window|\(candidate.title)|\(legacyOccurrence)"
            let isSelected = selectedIDs.contains(id) || selectedIDs.contains(alternateID) || selectedIDs.contains(legacyID) || (isProtected && isHiddenMenuBarFrame(candidate.frame))
            let displayTitle = candidate.title == "Item-0" ? "Menu Bar Item" : title
            return MenuBarItem(id: id, title: displayTitle, ownerName: isProtected ? "System Menu Bar" : candidate.owner, bundleIdentifier: candidate.ownerKey, frame: candidate.frame, axElement: nil, applicationIcon: candidate.appIcon, isSelected: isSelected, supportsPressAction: false, windowID: CGWindowID(candidate.identifier), ownerPID: pid_t(candidate.ownerPID), isProtectedSystemItem: isProtected)
        }
    }

    /// A position-independent fingerprint used to notice status-item creation,
    /// removal, and process restarts without treating our own layout moves as
    /// new items.
    func windowSignature() -> Set<String> {
        let windows = CGWindowListCopyWindowInfo(.excludeDesktopElements, kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(windows.compactMap { window in
            guard (window[kCGWindowLayer as String] as? Int) == 25,
                  let identifier = window[kCGWindowNumber as String] as? Int,
                  let ownerPID = window[kCGWindowOwnerPID as String] as? Int,
                  ownerPID != Int(getpid()),
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            let title = (window[kCGWindowName as String] as? String) ?? ""
            guard !excludedTitles.contains(title) else { return nil }
            let width = Int((bounds["Width"] ?? 0).rounded())
            let height = Int((bounds["Height"] ?? 0).rounded())
            guard width > 4, height > 4, height <= 40 else { return nil }
            return "\(identifier)|\(ownerPID)|\(title)|\(width)x\(height)"
        })
    }

    func refreshAccessibility(for item: MenuBarItem) -> (element: AXUIElement, supportsPress: Bool)? {
        // Accessibility is an optional fast path. Window-backed activation
        // remains reliable without a synchronous AX tree walk; callers fall
        // back to the WindowServer hit-test/temporary reveal path.
        return nil
    }

    private func isHiddenMenuBarFrame(_ frame: CGRect) -> Bool {
        frame.maxX <= 0 && frame.minY >= 0 && frame.maxY <= 40
    }

    private func isMenuBarWindowFrame(_ frame: CGRect) -> Bool {
        if isHiddenMenuBarFrame(frame) { return true }
        return displayBounds().contains { display in
            abs(frame.minY - display.minY) <= 2 &&
                frame.maxX > display.minX && frame.minX < display.maxX
        }
    }

    private func displayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return [] }
        return displays.prefix(Int(count)).map(CGDisplayBounds)
    }

}
