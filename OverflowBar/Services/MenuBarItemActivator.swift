import ApplicationServices

final class MenuBarItemActivator {
    func activateDirectly(_ item: MenuBarItem) -> Bool {
        guard let axElement = item.axElement, item.supportsPressAction else { return false }
        return AXUIElementPerformAction(axElement, kAXPressAction as CFString) == .success
    }

    /// Resolves the status item through the system accessibility hit-test.
    /// This also covers some Control Center-owned items that are absent from
    /// the originating app's AX menu bar, without synthesizing mouse events.
    func activateViaAccessibilityHitTest(_ item: MenuBarItem) -> Bool {
        let point = CGPoint(x: item.frame.midX, y: item.frame.midY)
        let system = AXUIElementCreateSystemWide()
        var value: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &value) == .success,
              let element = value else { return false }
        return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

}
