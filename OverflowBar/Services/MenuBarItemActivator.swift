import ApplicationServices

enum MenuBarActivationResult: Equatable {
    case activated
    case itemChanged
    case unobserved
    case awaitingManualInterface
    case manualFallback
    case unavailable

    func layoutMessage(groupHidden: Bool) -> String? {
        switch self {
        case .itemChanged:
            "This icon changed. Review its menu bar position before hiding it again."
        case .awaitingManualInterface:
            "Open this icon from the menu bar. OverflowBar will put it back after its menu closes."
        case .unobserved where !groupHidden, .manualFallback where !groupHidden:
            "Open this icon from the menu bar, then hide selected icons when you're ready."
        default:
            nil
        }
    }
}

enum AccessibilityTargetResolution {
    case unique(AXUIElement)
    case ambiguous
    case unavailable

    static func classify(count: Int, element: AXUIElement?) -> AccessibilityTargetResolution {
        guard count > 0 else { return .unavailable }
        guard count == 1, let element else { return .ambiguous }
        return .unique(element)
    }
}

enum MenuBarItemActivator {
    static func outcome(advertised: Bool, succeeded: Bool) -> MenuBarActivationResult {
        advertised && succeeded ? .activated : .manualFallback
    }

    static func perform(_ element: AXUIElement, contextMenu: Bool = false) -> MenuBarActivationResult {
        AXUIElementSetMessagingTimeout(element, 0.25)
        var actions: CFArray?
        guard AXUIElementCopyActionNames(element, &actions) == .success,
              let names = actions as? [String] else { return .manualFallback }
        let action = contextMenu ? kAXShowMenuAction as String : kAXPressAction as String
        let advertised = names.contains(action)
        return outcome(advertised: advertised, succeeded: advertised && AXUIElementPerformAction(element, action as CFString) == .success)
    }
}
