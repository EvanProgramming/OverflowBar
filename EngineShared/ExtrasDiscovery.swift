// Copyright (Thaw) © 2026 Toni Förster
// Adapted from SourcePIDCache/AXHelpers; GPL-3.0. See THIRD_PARTY_NOTICES.md.
import AppKit
import ApplicationServices
import OSLog

final class ExtrasDiscovery {
    struct Candidate {
        let app: NSRunningApplication
        let element: AXUIElement
        let frame: CGRect
        let windowID: UInt32?
        let title: String
        let identifier: String?
        let press: Bool
    }
    private var candidateCache: [Int32: [Candidate]] = [:]
    private var nextApp = 0
    private var displayCache: [UInt32: UInt32] = [:]
    private var displayGeometry: [UInt32: CGRect] = [:]
    private var resolved: [UInt32: Candidate] = [:]
    static func value(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success ? value : nil
    }
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = value(element, kAXPositionAttribute), let size = value(element, kAXSizeAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero; var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point), AXValueGetValue(size as! AXValue, .cgSize, &dimensions), dimensions.width > 0, dimensions.height > 0 else { return nil }
        return CGRect(origin: point, size: dimensions)
    }
    static func window(_ element: AXUIElement) -> UInt32? {
        typealias Getter = @convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> Int32
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else { return nil }
        let function = unsafeBitCast(symbol, to: Getter.self)
        var id: UInt32 = 0
        return function(element, &id) == 0 && id > 0 ? id : nil
    }
    func discover(onlyPID: Int32? = nil) -> [EngineItemRecord] {
        let log = Logger(subsystem: "com.overflowbar.native", category: "discovery")
        log.info("Scan beginning; main thread: \(Thread.isMainThread), trusted: \(AXIsProcessTrusted())")
        let deadline = Date().addingTimeInterval(2)
        var candidates: [Candidate] = []
        if AXIsProcessTrusted() {
            let running = NSWorkspace.shared.runningApplications.filter { $0.isFinishedLaunching && !$0.isTerminated && $0.bundleURL?.pathExtension == "app" }
            log.info("Running applications enumerated: \(running.count)")
            candidateCache = candidateCache.filter { pid, _ in running.contains { $0.processIdentifier == pid } }
            let sorted = running.sorted { $0.processIdentifier < $1.processIdentifier }
            let rotated = sorted.isEmpty ? [] : Array(sorted.dropFirst(nextApp % sorted.count)) + Array(sorted.prefix(nextApp % sorted.count))
            let apps = (rotated.filter { $0.bundleIdentifier == "com.overflowbar.mac26.v6" } + rotated.filter { $0.bundleIdentifier != "com.overflowbar.mac26.v6" })
                .filter { onlyPID == nil || $0.processIdentifier == onlyPID }
            nextApp += 1
            for app in apps where app.isFinishedLaunching && !app.isTerminated && app.bundleURL?.pathExtension == "app" {
                guard Date() < deadline else { break }
                candidateCache[app.processIdentifier] = []
                let first = candidates.count
                let ax = AXUIElementCreateApplication(app.processIdentifier)
                AXUIElementSetMessagingTimeout(ax, 0.1)
                var extras: CFTypeRef?
                let extrasError = AXUIElementCopyAttributeValue(ax, "AXExtrasMenuBar" as CFString, &extras)
                if app.bundleIdentifier == "com.overflowbar.mac26.v6" { log.info("Own extras result: \(extrasError.rawValue); present: \(extras != nil)") }
                guard let value = extras, CFGetTypeID(value) == AXUIElementGetTypeID() else { continue }
                let bar = unsafeBitCast(value, to: AXUIElement.self)
                AXUIElementSetMessagingTimeout(bar, 0.1)
                guard let children = Self.value(bar, kAXChildrenAttribute) as? [AXUIElement] else { continue }
                for child in children {
                    guard Date() < deadline else { break }
                    AXUIElementSetMessagingTimeout(child, 0.1)
                    guard let frame = Self.frame(child), frame.height <= 40 else { continue }
                    if app.bundleIdentifier == "com.overflowbar.mac26.v6" { log.info("Own AX child frame: \(String(describing: frame), privacy: .public)") }
                    var actions: CFArray?
                    AXUIElementCopyActionNames(child, &actions)
                    candidates.append(Candidate(app: app, element: child, frame: frame, windowID: Self.window(child),
                        title: (Self.value(child, kAXTitleAttribute) as? String).flatMap { $0.isEmpty ? nil : $0 } ?? (Self.value(child, kAXDescriptionAttribute) as? String) ?? app.localizedName ?? "Status Item",
                        identifier: (Self.value(child, kAXIdentifierAttribute) as? String) ?? (Self.value(child, kAXChildrenAttribute) as? [AXUIElement])?.compactMap { Self.value($0, kAXIdentifierAttribute) as? String }.first,
                        press: (actions as? [String] ?? []).contains(kAXPressAction)))
                }
                candidateCache[app.processIdentifier] = Array(candidates.dropFirst(first))
            }
            candidates = candidateCache.filter { onlyPID == nil || $0.key == onlyPID }.values.flatMap { $0 }
        }
        log.info("AX scan completed")
        let windows = NativeWindowBridge.statusWindows()
        log.info("Native windows enumerated: \(windows.count)")
        let displays = NativeWindowBridge.displays()
        let geometry = Dictionary(uniqueKeysWithValues: displays)
        if geometry != displayGeometry { displayCache.removeAll(); displayGeometry = geometry }
        let liveIDs = Set(windows.compactMap { $0[kCGWindowNumber as String] as? UInt32 })
        displayCache = displayCache.filter { liveIDs.contains($0.key) }
        var output: [EngineItemRecord] = []
        var claims = Set<Int>()
        resolved.removeAll()
        for row in windows {
            guard let id = row[kCGWindowNumber as String] as? UInt32,
                  let owner = row[kCGWindowOwnerPID as String] as? Int32,
                  let frame = NativeWindowBridge.bounds(row), frame.height <= 40, frame.width > 0 else { continue }
            let exact = candidates.indices.filter { candidates[$0].windowID == id }
            var index: Int? = exact.count == 1 ? exact.first : nil
            if exact.isEmpty {
                let owned = candidates.indices.filter { candidates[$0].app.processIdentifier == owner && candidates[$0].app.bundleIdentifier == "com.overflowbar.mac26.v6" && ["OverflowBarControlItem", "OverflowBarHiddenSection"].contains(candidates[$0].identifier ?? "") }
                index = EngineIdentity.uniqueNearbyMatch(window: frame, candidates: owned.map { candidates[$0].frame }).map { owned[$0] }
                if index == nil { index = EngineIdentity.uniqueMatch(window: frame, candidates: candidates.map(\.frame)) }
            }
            if let i = index, claims.contains(i) { index = nil }
            let candidate = index.map { candidates[$0] }
            if let index { claims.insert(index); resolved[id] = candidate }
            let source = candidate?.app ?? (ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26 ? NSRunningApplication(processIdentifier: owner) : nil)
            let bundle = source?.bundleIdentifier
            let rawTitle = row[kCGWindowName as String] as? String ?? "Unknown Status Item"
            let title = candidate?.title ?? rawTitle
            let identifier = candidate?.identifier.flatMap { $0.isEmpty ? nil : $0 }
            let name = identifier ?? title
            let duplicates = candidates.filter { $0.app.processIdentifier == source?.processIdentifier && ($0.identifier ?? $0.title) == name }.count
            let persistentID = bundle.flatMap { duplicates <= 1 && !name.hasPrefix("Item-") && name != "Unknown Status Item" ? "\($0)|\(name)" : nil }
            let displayID = EngineDisplayIdentity.resolve(frame: frame, displays: displays, cached: displayCache[id])
            if let displayID { displayCache[id] = displayID }
            let own = bundle == "com.overflowbar.mac26.v6" && ["OverflowBarControlItem", "OverflowBarHiddenSection"].contains(identifier ?? "")
            let electron = source?.bundleURL.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent("Contents/Frameworks/Electron Framework.framework").path) } ?? false
            output.append(EngineItemRecord(persistentID: persistentID, title: title, bundleIdentifier: bundle, sourcePID: source?.processIdentifier, ownerPID: owner, windowID: id, frame: frame, displayID: displayID, accessibilityIdentifier: identifier, supportsPress: candidate?.press ?? false, isElectron: electron, isOwnControl: own, accessibilityFrame: candidate?.frame))
        }
        return output
    }
    func press(_ item: EngineItemRecord) -> Bool {
        _ = discover(onlyPID: item.sourcePID)
        guard let candidate = resolved[item.windowID], candidate.app.processIdentifier == item.sourcePID,
              candidate.identifier == item.accessibilityIdentifier, candidate.press else { return false }
        return AXUIElementPerformAction(candidate.element, kAXPressAction as CFString) == .success
    }
}
