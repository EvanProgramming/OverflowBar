import AppKit
import ApplicationServices

enum MenuBarSystemItemClassifier {
    static func isProtected(_ title: String, owner: String? = nil) -> Bool {
        let normalized = normalize(title)
        if normalized.contains("clock") ||
            normalized.contains("battery") ||
            normalized.contains("siri") ||
            normalized.contains("wifi") ||
            normalized.contains("bluetooth") ||
            normalized.contains("bentobox") ||
            normalized.contains("audiovideomodule") ||
            normalized.contains("audioandvideocontrols") ||
            normalized.contains("controlcenter") {
            return true
        }

        // macOS 26 gives several Control Center-owned status items only a
        // generic WindowServer/AX title (for example "Item-0" or
        // "status menu"). Their owner is the reliable system boundary.
        let normalizedOwner = normalize(owner ?? "")
        return normalizedOwner.contains("controlcenter") &&
            ["item-0", "item0", "statusmenu", "menubaritem"].contains(normalized)
    }

    static func canonicalName(_ title: String, owner: String? = nil) -> String {
        let normalized = normalize(title)
        if normalized.contains("wifi") { return "WiFi" }
        if normalized.contains("bluetooth") { return "Bluetooth" }
        if normalized.contains("battery") { return "Battery" }
        if normalized.contains("siri") { return "Siri" }
        if normalized.contains("clock") { return "Clock" }
        if normalized.contains("controlcenter") { return "Control Center" }
        if normalized.contains("audioandvideocontrols") || normalized.contains("audiovideomodule") {
            return "Audio and Video Controls"
        }
        if normalized.contains("bentobox") { return "Control Center" }
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
    var displayImage: NSImage? { iconImage ?? applicationIcon }
    var hasUsableDisplayIcon: Bool {
        displayImage != nil || NSImage(systemSymbolName: fallbackSymbolName, accessibilityDescription: nil) != nil
    }

    var fallbackSymbolName: String {
        let value = title.lowercased()
        if value.contains("audio") || value.contains("sound") { return "speaker.wave.2.fill" }
        if value.contains("battery") { return "battery.75percent" }
        if value.contains("wifi") { return "wifi" }
        if value.contains("vpn") { return "lock.shield.fill" }
        if value.contains("clock") { return "clock.fill" }
        if value.contains("amphetamine") { return "bolt.fill" }
        return "circle.grid.2x2.fill"
    }
}
