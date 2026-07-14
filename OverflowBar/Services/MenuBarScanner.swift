import AppKit
import ApplicationServices

/// Reads status items exposed through each running application's accessibility tree.
final class MenuBarScanner {
    private let excludedTitles = Set(["Clock", "Battery", "Siri", "BentoBox-0", "BentoBox", "OverflowBarControlItem"])
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
                guard let frame = frame(of: child), frame.width > 5, frame.height > 5, isOnRightSide(frame) else { continue }
                let title = stringAttribute(child, kAXTitleAttribute as CFString) ?? stringAttribute(child, kAXDescriptionAttribute as CFString) ?? "Menu Bar Item"
                guard !title.isEmpty, !excludedTitles.contains(title), !looksLikeTextMenu(title, frame: frame) else { continue }
                let id = "\(bundleID)|\(title)"
                let supportsPress = actionNames(child).contains(kAXPressAction as String)
                guard !results.contains(where: { $0.frame.equalTo(frame) }) else { continue }
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
        let candidates: [(identifier: Int, ownerPID: Int, title: String, owner: String, frame: CGRect)] = windows.compactMap { window in
            guard (window[kCGWindowLayer as String] as? Int) == 25,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let identifier = window[kCGWindowNumber as String] as? Int,
                  let ownerPID = window[kCGWindowOwnerPID as String] as? Int else { return nil }
            guard ownerPID != Int(getpid()) else { return nil }
            let title = (window[kCGWindowName as String] as? String) ?? "Menu Bar Item"
            guard !excludedTitles.contains(title) else { return nil }
            let owner = (window[kCGWindowOwnerName as String] as? String) ?? "System Menu Bar"
            let frame = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            guard frame.minY == 0, frame.width > 4, frame.height > 4, frame.height <= 40 else { return nil }
            return (identifier, ownerPID, title, owner, frame)
        }
        var occurrences: [String: Int] = [:]
        return candidates.sorted { $0.frame.minX > $1.frame.minX }.map { candidate in
            let occurrence = occurrences[candidate.title, default: 0]
            occurrences[candidate.title] = occurrence + 1
            let id = "window|\(candidate.title)|\(occurrence)"
            return MenuBarItem(id: id, title: candidate.title == "Item-0" ? "Menu Bar Item" : candidate.title, ownerName: candidate.owner, bundleIdentifier: nil, frame: candidate.frame, axElement: nil, isSelected: selectedIDs.contains(id), supportsPressAction: false, windowID: CGWindowID(candidate.identifier), ownerPID: pid_t(candidate.ownerPID))
        }
    }

    private func isOnRightSide(_ frame: CGRect) -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) else { return false }
        return frame.midX > screen.frame.midX && frame.maxY >= screen.frame.maxY - 32
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
