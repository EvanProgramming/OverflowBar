// Copyright (Ice) © 2023–2025 Jordan Baird
// Copyright (Thaw) © 2026 Toni Förster
// Adapted from Shared/Bridging for OverflowBar; GPL-3.0.
import AppKit
import Darwin

enum NativeWindowBridge {
    static let library = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW | RTLD_LOCAL)
    static func load<T>(_ name: String, as type: T.Type) -> T? {
        guard let library, let symbol = dlsym(library, name) else { return nil }
        return unsafeBitCast(symbol, to: type)
    }
    typealias Connection = @convention(c) () -> Int32
    typealias Count = @convention(c) (Int32, Int32, UnsafeMutablePointer<Int32>) -> Int32
    typealias List = @convention(c) (Int32, Int32, Int32, UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<Int32>) -> Int32
    typealias Bounds = @convention(c) (Int32, UInt32, UnsafeMutablePointer<CGRect>) -> Int32
    static func statusWindows() -> [[String: Any]] {
        func published() -> [[String: Any]] {
            (CGWindowListCopyWindowInfo(.optionAll, 0) as? [[String: Any]] ?? []).filter { ($0[kCGWindowLayer as String] as? Int) == 25 }
        }

        guard let connection = load("CGSMainConnectionID", as: Connection.self),
              let countFn = load("CGSGetWindowCount", as: Count.self),
              let listFn = load("CGSGetProcessMenuBarWindowList", as: List.self) else {
            return published()
        }
        var count: Int32 = 0
        guard countFn(connection(), 0, &count) == 0, count > 0, count < 65536 else { return published() }
        var ids = [UInt32](repeating: 0, count: Int(count))
        let capacity = count
        guard listFn(connection(), 0, capacity, &ids, &count) == 0 else { return published() }
        let privateRows = descriptions(Array(ids.prefix(max(0, min(Int(count), ids.count)))))
            .filter { ($0[kCGWindowLayer as String] as? Int) == 25 }
        return privateRows.isEmpty ? published() : privateRows
    }
    static func descriptions(_ ids: [UInt32]) -> [[String: Any]] {
        var pointers = ids.filter { $0 != 0 }.map { UnsafeRawPointer(bitPattern: UInt($0)) }
        guard !pointers.isEmpty else { return [] }
        return pointers.withUnsafeMutableBufferPointer {
            guard let array = CFArrayCreate(nil, $0.baseAddress, $0.count, nil) else { return [] }
            return CGWindowListCreateDescriptionFromArray(array) as? [[String: Any]] ?? []
        }
    }
    static func frame(_ id: UInt32) -> CGRect? {
        guard let connection = load("CGSMainConnectionID", as: Connection.self), let function = load("CGSGetScreenRectForWindow", as: Bounds.self) else {
            return descriptions([id]).first.flatMap(bounds)
        }
        var frame = CGRect.zero
        guard function(connection(), id, &frame) == 0, frame.width > 0, frame.height > 0 else { return descriptions([id]).first.flatMap(bounds) }
        return frame
    }
    static func bounds(_ info: [String: Any]) -> CGRect? {
        guard let dictionary = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: dictionary)
    }
    static func displays() -> [(UInt32, CGRect)] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [UInt32](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { ($0, CGDisplayBounds($0)) }
    }
}
