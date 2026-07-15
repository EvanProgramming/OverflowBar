import AppKit
import ApplicationServices

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
    var iconImage: NSImage?
    var isSelected: Bool

    init(id: String, title: String, ownerName: String, bundleIdentifier: String?, frame: CGRect, axElement: AXUIElement?, iconImage: NSImage? = nil, isSelected: Bool, supportsPressAction: Bool, windowID: CGWindowID? = nil, ownerPID: pid_t? = nil) {
        self.id = id
        self.title = title
        self.ownerName = ownerName
        self.bundleIdentifier = bundleIdentifier
        self.frame = frame
        self.axElement = axElement
        self.iconImage = iconImage
        self.isSelected = isSelected
        self.supportsPressAction = supportsPressAction
        self.windowID = windowID
        self.ownerPID = ownerPID
    }

    var tooltip: String { title.isEmpty ? ownerName : "\(ownerName) — \(title)" }

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
