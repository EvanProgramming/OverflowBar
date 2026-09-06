import CoreGraphics

/// A small compatibility wrapper around the public WindowServer API.
/// macOS 26 hosts third-party status items in Control Center scenes that do
/// not have public CGWindowIDs; returning only public descriptions lets the
/// caller fail closed instead of guessing another item's window.
enum MenuBarWindowServer {
    static func windowIDs() -> [CGWindowID] {
        windowInfo().compactMap { info in
            guard let rawID = info[kCGWindowNumber as String] as? Int,
                  rawID > 0,
                  rawID <= Int(CGWindowID.max) else { return nil }
            return CGWindowID(rawID)
        }
    }

    static func windowInfo() -> [[String: Any]] {
        CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
    }
}
