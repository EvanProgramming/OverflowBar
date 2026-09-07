import CoreGraphics
import Foundation

/// A small compatibility wrapper around the public WindowServer API.
/// macOS 26 hosts third-party status items in Control Center scenes that do
/// not have public CGWindowIDs; returning only public descriptions lets the
/// caller fail closed instead of guessing another item's window.
enum MenuBarWindowServer {
    static func integer(_ key: String, in info: [String: Any]) -> Int? {
        if let value = info[key] as? Int { return value }
        if let value = info[key] as? NSNumber { return value.intValue }
        return nil
    }

    static func isStatusItemLayer(_ info: [String: Any]) -> Bool {
        integer(kCGWindowLayer as String, in: info) == 25
    }

    static func bounds(in info: [String: Any]) -> CGRect? {
        guard let raw = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
        func value(_ key: String) -> CGFloat? {
            if let number = raw[key] as? NSNumber { return CGFloat(number.doubleValue) }
            if let number = raw[key] as? CGFloat { return number }
            return nil
        }
        guard let x = value("X"), let y = value("Y"),
              let width = value("Width"), let height = value("Height") else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func windowIDs() -> [CGWindowID] {
        windowInfo().compactMap { info in
            guard let rawID = integer(kCGWindowNumber as String, in: info),
                  rawID > 0,
                  rawID <= Int(CGWindowID.max) else { return nil }
            return CGWindowID(rawID)
        }
    }

    static func windowInfo() -> [[String: Any]] {
        CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
    }
}
