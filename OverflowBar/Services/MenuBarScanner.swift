import AppKit
import ApplicationServices

/// Reads status items exposed through each running application's accessibility tree.
final class MenuBarScanner {
    private let excludedTitles = Set(["Clock", "Battery", "Siri", "WiFi", "BentoBox-0", "BentoBox", "OverflowBarControlItem", "OverflowBarHiddenSection"])
    func scan(selectedIDs: Set<String>) -> [MenuBarItem] {
        var results = scanWindowBackedItems(selectedIDs: selectedIDs)
        guard AXIsProcessTrusted() else { return results }
        let ownBundleID = Bundle.main.bundleIdentifier
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .accessory || app.activationPolicy == .prohibited {
            guard let bundleID = app.bundleIdentifier, bundleID != ownBundleID else { continue }
            let application = AXUIElementCreateApplication(app.processIdentifier)
            guard let menuBar = elementAttribute(application, kAXMenuBarAttribute as CFString),
                  let children = arrayAttribute(menuBar, kAXChildrenAttribute as CFString) else { continue }
            for child in children {
                guard let frame = frame(of: child), frame.width > 5, frame.height > 5,
                      isOnRightSide(frame) || isHiddenMenuBarFrame(frame) else { continue }
                let title = stringAttribute(child, kAXTitleAttribute as CFString) ?? stringAttribute(child, kAXDescriptionAttribute as CFString) ?? "Menu Bar Item"
                let matchingIndex = results.firstIndex(where: { framesMatch($0.frame, frame) })
                if title.isEmpty || excludedTitles.contains(title) || looksLikeTextMenu(title, frame: frame) {
                    if let matchingIndex { results.remove(at: matchingIndex) }
                    continue
                }
                let id = "\(bundleID)|\(title)"
                let supportsPress = actionNames(child).contains(kAXPressAction as String)
                if let matchingIndex {
                    let existing = results[matchingIndex]
                    existing.axElement = child
                    existing.supportsPressAction = supportsPress
                    existing.title = title
                    existing.ownerName = app.localizedName ?? bundleID
                    existing.bundleIdentifier = bundleID
                    continue
                }
                results.append(MenuBarItem(id: id, title: title, ownerName: app.localizedName ?? bundleID, bundleIdentifier: bundleID, frame: frame, axElement: child, isSelected: selectedIDs.contains(id), supportsPressAction: supportsPress))
            }
        }
        return results.sorted { $0.frame.minX < $1.frame.minX }
    }

    /// macOS 26 exposes most menu bar controls as Control Center-owned windows.
    /// This public window-list fallback discovers those controls even when the
    /// originating app does not publish an Accessibility menu-bar element.
    private func scanWindowBackedItems(selectedIDs: Set<String>) -> [MenuBarItem] {
        // Hidden-section items are deliberately moved offscreen. They must
        // remain in the settings and overflow panel when either is refreshed.
        let options: CGWindowListOption = [.excludeDesktopElements]
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates: [(identifier: Int, ownerPID: Int, title: String, owner: String, ownerKey: String, frame: CGRect)] = windows.compactMap { window in
            guard (window[kCGWindowLayer as String] as? Int) == 25,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let identifier = window[kCGWindowNumber as String] as? Int,
                  let ownerPID = window[kCGWindowOwnerPID as String] as? Int else { return nil }
            guard ownerPID != Int(getpid()) else { return nil }
            let title = (window[kCGWindowName as String] as? String) ?? "Menu Bar Item"
            guard !excludedTitles.contains(title) else { return nil }
            let owner = (window[kCGWindowOwnerName as String] as? String) ?? "System Menu Bar"
            let ownerKey = NSRunningApplication(processIdentifier: pid_t(ownerPID))?.bundleIdentifier ?? owner
            let frame = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            guard isMenuBarWindowFrame(frame), frame.width > 4, frame.height > 4, frame.height <= 40 else { return nil }
            return (identifier, ownerPID, title, owner, ownerKey, frame)
        }
        var occurrences: [String: Int] = [:]
        var legacyOccurrences: [String: Int] = [:]
        return candidates.sorted { $0.frame.minX > $1.frame.minX }.map { candidate in
            let occurrenceKey = "\(candidate.ownerKey)|\(candidate.title)"
            let occurrence = occurrences[occurrenceKey, default: 0]
            occurrences[occurrenceKey] = occurrence + 1
            let legacyOccurrence = legacyOccurrences[candidate.title, default: 0]
            legacyOccurrences[candidate.title] = legacyOccurrence + 1
            let id = "window|\(candidate.ownerKey)|\(candidate.title)|\(occurrence)"
            let legacyID = "window|\(candidate.title)|\(legacyOccurrence)"
            return MenuBarItem(id: id, title: candidate.title == "Item-0" ? "Menu Bar Item" : candidate.title, ownerName: candidate.owner, bundleIdentifier: candidate.ownerKey, frame: candidate.frame, axElement: nil, isSelected: selectedIDs.contains(id) || selectedIDs.contains(legacyID), supportsPressAction: false, windowID: CGWindowID(candidate.identifier), ownerPID: pid_t(candidate.ownerPID))
        }
    }

    private func isOnRightSide(_ frame: CGRect) -> Bool {
        guard let display = displayBounds().first(where: { $0.intersects(frame) }) else { return false }
        return frame.midX > display.midX && abs(frame.minY - display.minY) <= 2
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

    private func framesMatch(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let horizontalOverlap = max(0, min(lhs.maxX, rhs.maxX) - max(lhs.minX, rhs.minX))
        return horizontalOverlap >= min(lhs.width, rhs.width) * 0.5 &&
            lhs.minY < 40 && rhs.minY < 40
    }

    private func looksLikeTextMenu(_ title: String, frame: CGRect) -> Bool { title.count > 18 || frame.width > 150 }
    private func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? { var value: CFTypeRef?; return AXUIElementCopyAttributeValue(element, attribute, &value) == .success ? value as? String : nil }
    private func arrayAttribute(_ element: AXUIElement, _ attribute: CFString) -> [AXUIElement]? { var value: CFTypeRef?; return AXUIElementCopyAttributeValue(element, attribute, &value) == .success ? value as? [AXUIElement] : nil }
    private func elementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func actionNames(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success, let names else { return [] }
        return names as? [String] ?? []
    }

    private func frame(of element: AXUIElement) -> CGRect? {
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
}
