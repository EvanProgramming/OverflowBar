import AppKit
import ApplicationServices

enum MenuBarSystemItemClassifier {
    static func isGenericControlCenterItem(_ title: String, owner: String? = nil) -> Bool {
        let normalized = normalize(title)
        let normalizedOwner = normalize(owner ?? "")
        return normalizedOwner.contains("controlcenter") &&
            ["item-0", "item0", "statusmenu", "menubaritem"].contains(normalized)
    }

    static func isProtected(_ title: String, owner: String? = nil) -> Bool {
        let normalized = normalize(title)
        return normalized.contains("clock") ||
            normalized.contains("battery") ||
            normalized.contains("siri") ||
            normalized.contains("wifi") ||
            normalized.contains("bluetooth") ||
            normalized.contains("screenrecording") ||
            normalized.contains("bentobox") ||
            normalized.contains("audiovideomodule") ||
            normalized.contains("audioandvideocontrols")
    }

    static func canonicalName(_ title: String, owner: String? = nil) -> String {
        let normalized = normalize(title)
        if normalized.contains("wifi") { return "WiFi" }
        if normalized.contains("bluetooth") { return "Bluetooth" }
        if normalized.contains("battery") { return "Battery" }
        if normalized.contains("siri") { return "Siri" }
        if normalized.contains("screenrecording") { return "Screen Recording" }
        if normalized.contains("clock") { return "Clock" }
        if normalized.contains("controlcenter") { return "Control Center" }
        if normalized.contains("audioandvideocontrols") || normalized.contains("audiovideomodule") {
            return "Audio and Video Controls"
        }
        // While capture is active, Control Center exposes the privacy/media
        // indicators as BentoBox/AudioVideoModule windows. They are OS-owned
        // security indicators rather than draggable status items.
        if normalized.contains("bentobox") { return "Screen Recording" }
        if isProtected(title, owner: owner) && normalize(owner ?? "").contains("controlcenter") {
            return "Control Center Item"
        }
        return title
    }

    private static func normalize(_ title: String) -> String {
        title
            .replacingOccurrences(of: "‑", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}

/// Accessibility-backed description of one right-side menu bar control.
final class MenuBarItem: Identifiable {
    let id: String
    var title: String
    var ownerName: String
    var bundleIdentifier: String?
    let frame: CGRect
    var axElement: AXUIElement?
    var supportsPressAction: Bool
    let windowID: CGWindowID?
    let ownerPID: pid_t?
    var isProtectedSystemItem: Bool
    var iconImage: NSImage?
    let applicationIcon: NSImage?
    var isSelected: Bool

    init(id: String, title: String, ownerName: String, bundleIdentifier: String?, frame: CGRect, axElement: AXUIElement?, iconImage: NSImage? = nil, applicationIcon: NSImage? = nil, isSelected: Bool, supportsPressAction: Bool, windowID: CGWindowID? = nil, ownerPID: pid_t? = nil, isProtectedSystemItem: Bool = false) {
        self.id = id
        self.title = title
        self.ownerName = ownerName
        self.bundleIdentifier = bundleIdentifier
        self.frame = frame
        self.axElement = axElement
        self.iconImage = iconImage
        self.applicationIcon = applicationIcon
        self.isSelected = isSelected
        self.supportsPressAction = supportsPressAction
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.isProtectedSystemItem = isProtectedSystemItem
    }

    var tooltip: String { title.isEmpty ? ownerName : "\(ownerName) — \(title)" }
    var isAlwaysVisibleSystemItem: Bool {
        guard isProtectedSystemItem else { return false }
        return title == "Screen Recording" || title == "Audio and Video Controls"
    }
    var displayImage: NSImage? { iconImage ?? applicationIcon }
    /// The activation path used by the item. WindowServer-backed items do not
    /// expose an Accessibility press action, but they can still be activated
    /// directly without moving the user's cursor or waiting for AX traversal.
    var activationStatusSymbolName: String {
        if supportsPressAction { return "hand.tap" }
        if windowID != nil { return "bolt.fill" }
        return "exclamationmark.triangle"
    }
    var activationStatusHelp: String {
        if supportsPressAction { return "Supports Accessibility press" }
        if windowID != nil { return "Uses fast WindowServer activation" }
        return "Accessibility activation unavailable"
    }
    var hasUsableDisplayIcon: Bool {
        displayImage != nil || NSImage(systemSymbolName: fallbackSymbolName, accessibilityDescription: nil) != nil
    }

    var fallbackSymbolName: String {
        let value = title.lowercased()
        if value.contains("audio") || value.contains("sound") { return "speaker.wave.2.fill" }
        if value.contains("battery") { return "battery.75percent" }
        if value.contains("wifi") { return "wifi" }
        if value.contains("screen recording") || value.contains("screenrecording") { return "record.circle" }
        if value.contains("vpn") { return "lock.shield.fill" }
        if value.contains("clock") { return "clock.fill" }
        if value.contains("amphetamine") { return "bolt.fill" }
        return "circle.grid.2x2.fill"
    }
}
