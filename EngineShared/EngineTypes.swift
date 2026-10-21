import Foundation
import CoreGraphics

struct EngineItemRecord: Codable, Sendable, Equatable {
    var persistentID: String?
    var title: String
    var bundleIdentifier: String?
    var sourcePID: Int32?
    var ownerPID: Int32
    var windowID: UInt32
    var frame: CGRect
    var displayID: UInt32?
    var accessibilityIdentifier: String?
    var supportsPress: Bool
    var isElectron: Bool
    var isOwnControl: Bool
    var accessibilityFrame: CGRect? = nil
    var id: String { persistentID ?? "session|\(windowID)" }
}

struct EngineCaptureFrame: Codable, Sendable {
    var windowID: UInt32
    var width: Int
    var height: Int
    var bytesPerRow: Int
    var scale: Double
    var pixels: Data
    static func actualScale(pixelWidth: Int, boundsWidth: CGFloat) -> CGFloat? {
        guard pixelWidth > 0, boundsWidth.isFinite, boundsWidth > 0 else { return nil }
        let scale = CGFloat(pixelWidth) / boundsWidth
        return scale.isFinite && scale > 0 && scale <= 8 ? scale : nil
    }
    static func isMonochrome(_ pixels: Data) -> Bool {
        guard !pixels.isEmpty, pixels.count.isMultiple(of: 4) else { return false }
        return pixels.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            var visible = 0, monochrome = 0
            for offset in stride(from: 0, to: bytes.count, by: 4) where bytes[offset + 3] > 16 {
                visible += 1
                let low = min(bytes[offset], min(bytes[offset + 1], bytes[offset + 2]))
                let high = max(bytes[offset], max(bytes[offset + 1], bytes[offset + 2]))
                if high - low <= 10 { monochrome += 1 }
            }
            return visible > 0 && monochrome * 100 >= visible * 98
        }
    }
    static func isValid(width: Int, height: Int, bytesPerRow: Int, count: Int) -> Bool {
        guard width > 0, height > 0, width <= 4096, height <= 4096,
              bytesPerRow >= width * 4, bytesPerRow <= 4 * 4096 else { return false }
        let size = bytesPerRow * height
        return size <= 4 * 1024 * 1024 && count == size
    }
}

@objc protocol EngineWorkerProtocol {
    func resolve(_ target: Data, reply: @escaping (Data?, String?) -> Void)
    func discover(_ reply: @escaping (Data?, String?) -> Void)
    func capture(_ windowIDs: [NSNumber], reply: @escaping (Data?, String?) -> Void)
    func press(_ request: Data, reply: @escaping (Bool, String?) -> Void)
    func shutdown(_ reply: @escaping () -> Void)
}

// Derived from Thaw SourcePIDCache; geometric fallback is deliberately unique and row-scoped.
enum EngineIdentity {
    static func uniqueMatch(window: CGRect, candidates: [CGRect]) -> Int? {
        let matches = candidates.indices.filter {
            let frame = candidates[$0]
            return abs(frame.midY - window.midY) <= 2 && abs(frame.midX - window.midX) <= 20
        }
        return matches.count == 1 ? matches[0] : nil
    }
    static func uniqueNearbyMatch(window: CGRect, candidates: [CGRect], tolerance: CGFloat = 64) -> Int? {
        let matches = candidates.indices.filter {
            let frame = candidates[$0]
            return abs(frame.midY - window.midY) <= 2 && abs(frame.midX - window.midX) <= tolerance
        }.sorted { abs(candidates[$0].midX - window.midX) < abs(candidates[$1].midX - window.midX) }
        guard let first = matches.first else { return nil }
        if matches.count > 1, abs(candidates[matches[0]].midX - window.midX) == abs(candidates[matches[1]].midX - window.midX) { return nil }
        return first
    }
}

// Keep a known display while its status window is temporarily displaced offscreen.
enum EngineDisplayIdentity {
    static func resolve(frame: CGRect, displays: [(UInt32, CGRect)], cached: UInt32?) -> UInt32? {
        let row = displays.filter { abs($0.1.minY - frame.minY) <= 4 }
        if let cached, row.contains(where: { $0.0 == cached }) { return cached }
        let contained = row.filter { $0.1.contains(frame) }
        if contained.count == 1 { return contained[0].0 }
        return contained.isEmpty && row.count == 1 ? row[0].0 : nil
    }
}
