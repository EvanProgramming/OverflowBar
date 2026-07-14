import AppKit
import ApplicationServices

/// Accessibility-backed description of one right-side menu bar control.
final class MenuBarItem: Identifiable {
    let id: String
    let title: String
    let ownerName: String
    let bundleIdentifier: String?
    let frame: CGRect
    let axElement: AXUIElement?
    let supportsPressAction: Bool
    var iconImage: NSImage?
    var isSelected: Bool

    init(id: String, title: String, ownerName: String, bundleIdentifier: String?, frame: CGRect, axElement: AXUIElement?, iconImage: NSImage? = nil, isSelected: Bool, supportsPressAction: Bool) {
        self.id = id
        self.title = title
        self.ownerName = ownerName
        self.bundleIdentifier = bundleIdentifier
        self.frame = frame
        self.axElement = axElement
        self.iconImage = iconImage
        self.isSelected = isSelected
        self.supportsPressAction = supportsPressAction
    }

    var tooltip: String { title.isEmpty ? ownerName : "\(ownerName) — \(title)" }
}
