// Copyright (Thaw) © 2026 Toni Förster
// Adapted from ClickReactionVerifier at the pinned revision; GPL-3.0.
import CoreGraphics

struct NativeInterfaceWindow { let id: UInt32; let pid: Int32; let layer: Int; let frame: CGRect }
struct NativeInterfaceLifecycle {
    private let before: Set<UInt32>
    private var interface: UInt32?

    init(before: Set<UInt32>, interface: UInt32? = nil) {
        self.before = before
        self.interface = interface
    }

    mutating func observe(_ current: Set<UInt32>) -> Bool {
        if let interface { return !current.contains(interface) }
        interface = current.subtracting(before).min()
        return false
    }
}

enum NativeResponseVerifier {
    enum Reaction: Equatable { case openedInterface(UInt32), itemChanged, unobserved }
    static func isAnchoredPopup(_ window: NativeInterfaceWindow, to item: CGRect) -> Bool {
        guard item.width > 0, item.height > 0,
              window.layer >= Int(CGWindowLevelForKey(.floatingWindow)) else { return false }
        let anchor = CGRect(x: item.minX - 48, y: item.maxY - 2, width: item.width + 96, height: 96)
        return anchor.intersects(window.frame)
    }
    static func observe(before: Set<UInt32>, windows: [NativeInterfaceWindow], pids: Set<Int32>, original: CGRect, current: CGRect?, originalTitle: String? = nil, currentTitle: String? = nil) -> Reaction {
        let newWindows = windows.filter { !before.contains($0.id) && $0.frame.width > 0 && $0.frame.height > 0 }
        let ownedWindows = newWindows.filter { pids.contains($0.pid) }
        if let window = ownedWindows.first(where: { $0.layer == Int(CGWindowLevelForKey(.popUpMenuWindow)) }) ?? ownedWindows.first
            ?? newWindows.first(where: { isAnchoredPopup($0, to: original) }) { return .openedInterface(window.id) }
        guard let current else { return .itemChanged }
        if let originalTitle, let currentTitle, originalTitle != currentTitle { return .itemChanged }
        if abs(current.width - original.width) > 1 || abs(current.height - original.height) > 1 { return .itemChanged }
        return .unobserved
    }
}

enum NativeActivationPolicy {
    static func usesAccessibilityPress(isElectron: Bool, supportsPress: Bool) -> Bool {
        isElectron && supportsPress
    }

    static func shouldRestoreAfterMenu(verifiedHiddenLayout: Bool, moved: Bool) -> Bool {
        verifiedHiddenLayout || moved
    }
}
