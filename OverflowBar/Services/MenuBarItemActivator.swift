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
            "The native item changed. Hide the group again when you are ready."
        case .awaitingManualInterface:
            "Native icons are revealed. Click the original item; OverflowBar will restore the layout after its menu closes."
        case .unobserved where !groupHidden, .manualFallback where !groupHidden:
            "Native icons are revealed. Click the original item, then hide the group again when ready."
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
