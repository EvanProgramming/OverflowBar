import ApplicationServices

final class MenuBarItemActivator {
    func activateDirectly(_ item: MenuBarItem) -> Bool {
        guard let axElement = item.axElement, item.supportsPressAction else { return false }
        return AXUIElementPerformAction(axElement, kAXPressAction as CFString) == .success
    }

}
