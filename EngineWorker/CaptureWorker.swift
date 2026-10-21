// Copyright (Ice) © 2023–2025 Jordan Baird
// Copyright (Thaw) © 2026 Toni Förster
// Adapted from SkyLightAPI and MenuBarCaptureService; GPL-3.0.
import AppKit
import ScreenCaptureKit

final class CaptureWorker {
    private(set) var attempts = 0
    private let created = Date()
    var shouldRecycle: Bool { attempts >= 1800 || Date().timeIntervalSince(created) >= 60 }
    func captureOnscreen(_ requested: [UInt32]) async -> [EngineCaptureFrame] {
        guard CGPreflightScreenCaptureAccess() else { return [] }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let displays = NativeWindowBridge.displays()
            var result: [EngineCaptureFrame] = []; var batchBytes = 0
            for window in content.windows where requested.contains(window.windowID) && displays.contains(where: { $0.1.contains(window.frame) }) {
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                let scale = max(1, CGFloat(filter.pointPixelScale))
                config.width = max(1, Int(window.frame.width * scale)); config.height = max(1, Int(window.frame.height * scale))
                config.showsCursor = false; config.ignoreShadowsSingleWindow = true
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                if let frame = Self.encode(image, id: window.windowID, bounds: window.frame), batchBytes + frame.pixels.count <= 16 * 1024 * 1024 { batchBytes += frame.pixels.count; result.append(frame) }
            }
            return result
        } catch { return [] }
    }
    static func encode(_ image: CGImage, id: UInt32, bounds: CGRect) -> EngineCaptureFrame? {
        guard let scale = EngineCaptureFrame.actualScale(pixelWidth: image.width, boundsWidth: bounds.width) else { return nil }
        let stride = image.width * 4, count = stride * image.height
        guard EngineCaptureFrame.isValid(width: image.width, height: image.height, bytesPerRow: stride, count: count) else { return nil }
        var pixels = Data(count: count)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: stride, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height)); return true
        }
        guard drawn, pixels.contains(where: { $0 != 0 }) else { return nil }
        return EngineCaptureFrame(windowID: id, width: image.width, height: image.height, bytesPerRow: stride, scale: Double(scale), pixels: pixels)
    }
    func capture(_ requested: [UInt32], budget: Int = 16 * 1024 * 1024) -> [EngineCaptureFrame] {
        typealias Capture = @convention(c) (CGRect, CFArray, CGWindowImageOption) -> Unmanaged<CGImage>?
        guard let function = NativeWindowBridge.load("SLWindowListCreateImageFromArray", as: Capture.self) else { return [] }
        let allowed = NativeWindowBridge.statusWindows()
        let ids = Array(Set(requested).intersection(Set(allowed.compactMap { $0[kCGWindowNumber as String] as? UInt32 }))).prefix(64)
        let frames = Dictionary(uniqueKeysWithValues: allowed.compactMap { row -> (UInt32, CGRect)? in
            guard let id = row[kCGWindowNumber as String] as? UInt32, let rect = NativeWindowBridge.bounds(row), rect.width > 0, rect.height > 0, rect.width <= 4096, rect.height <= 40 else { return nil }
            return (id, rect)
        })
        var result: [EngineCaptureFrame] = []; var batchBytes = 0
        for id in ids {
            guard let rect = frames[id] else { continue }
            attempts += 1
            var pointer = [UnsafeRawPointer(bitPattern: UInt(id))]
            let image = pointer.withUnsafeMutableBufferPointer { buffer -> CGImage? in
                guard let array = CFArrayCreate(nil, buffer.baseAddress, buffer.count, nil) else { return nil }
                return function(.null, array, [.boundsIgnoreFraming, .bestResolution])?.takeRetainedValue()
            }
            guard let image, let encoded = Self.encode(image, id: id, bounds: rect), batchBytes + encoded.pixels.count <= budget else { continue }
            batchBytes += encoded.pixels.count; result.append(encoded)
        }
        return result
    }
}
