import ApplicationServices

final class MenuBarItemActivator {
    /// Uses AXPress first, then falls back to an accessibility-authorized mouse click.
    func activate(_ item: MenuBarItem) -> Bool {
        if let axElement = item.axElement, item.supportsPressAction, AXUIElementPerformAction(axElement, kAXPressAction as CFString) == .success { return true }
        let point = CGPoint(x: item.frame.midX, y: item.frame.midY)
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else { return false }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
