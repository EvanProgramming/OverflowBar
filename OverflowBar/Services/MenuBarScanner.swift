import AppKit
import ApplicationServices

/// Reads status items exposed through each running application's accessibility tree.
final class MenuBarScanner {
    func scan(selectedIDs: Set<String>) -> [MenuBarItem] {
        guard AXIsProcessTrusted() else { return [] }
        let ownBundleID = Bundle.main.bundleIdentifier
        var results: [MenuBarItem] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .accessory || app.activationPolicy == .prohibited {
            guard let bundleID = app.bundleIdentifier, bundleID != ownBundleID else { continue }
            let application = AXUIElementCreateApplication(app.processIdentifier)
            guard let menuBar = elementAttribute(application, kAXMenuBarAttribute as CFString),
                  let children = arrayAttribute(menuBar, kAXChildrenAttribute as CFString) else { continue }
            for child in children {
                guard let frame = frame(of: child), frame.width > 5, frame.height > 5, isOnRightSide(frame) else { continue }
                let title = stringAttribute(child, kAXTitleAttribute as CFString) ?? stringAttribute(child, kAXDescriptionAttribute as CFString) ?? "Menu Bar Item"
                guard !title.isEmpty, !looksLikeTextMenu(title, frame: frame) else { continue }
                let id = "\(bundleID)|\(title)"
                let supportsPress = actionNames(child).contains(kAXPressAction as String)
                results.append(MenuBarItem(id: id, title: title, ownerName: app.localizedName ?? bundleID, bundleIdentifier: bundleID, frame: frame, axElement: child, isSelected: selectedIDs.contains(id), supportsPressAction: supportsPress))
            }
        }
        return results.sorted { $0.frame.minX < $1.frame.minX }
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
