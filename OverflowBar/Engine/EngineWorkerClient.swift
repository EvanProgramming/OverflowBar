import AppKit

final class WorkerReplyGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var callback: ((Value) -> Void)?
    init(_ callback: @escaping (Value) -> Void) { self.callback = callback }
    @discardableResult func complete(_ value: Value) -> Bool {
        lock.lock(); let callback = self.callback; self.callback = nil; lock.unlock()
        callback?(value); return callback != nil
    }
}

@MainActor final class EngineWorkerClient {
    private var connection: NSXPCConnection?
    private var captureConnection: NSXPCConnection?
    private func connected(capture: Bool) throws -> NSXPCConnection {
        if let connection = capture ? captureConnection : connection { return connection }
        let name = capture ? "CaptureWorker" : "EngineWorker"
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/XPCServices/\(name).xpc")
        let connection = NSXPCConnection(serviceName: "com.overflowbar.mac26.v6.\(name)")
        connection.remoteObjectInterface = NSXPCInterface(with: EngineWorkerProtocol.self)
        connection.setCodeSigningRequirement(try PeerSigning.requirement(for: url))
        connection.invalidationHandler = { [weak self, weak connection] in Task { @MainActor in
            if capture { if self?.captureConnection === connection { self?.captureConnection = nil } }
            else if self?.connection === connection { self?.connection = nil }
        } }
        connection.resume(); if capture { self.captureConnection = connection } else { self.connection = connection }; return connection
    }
    func cancel() { connection?.invalidate(); connection = nil; captureConnection?.invalidate(); captureConnection = nil }
    private func request(capture: Bool = false, _ operation: @escaping (EngineWorkerProtocol, @escaping (Data?, String?) -> Void) -> Void) async -> (Data?, String?) {
        do {
            let connection = try connected(capture: capture)
            return await withCheckedContinuation { continuation in
                let gate = WorkerReplyGate<(Data?, String?)> { continuation.resume(returning: $0) }
                let timeout = DispatchWorkItem {
                    if gate.complete((nil, "Native helper timed out")) { connection.invalidate() }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: timeout)
                guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in timeout.cancel(); gate.complete((nil, error.localizedDescription)) }) as? EngineWorkerProtocol else {
                    timeout.cancel(); gate.complete((nil, "Native helper unavailable")); return
                }
                operation(proxy) { data, error in
                    timeout.cancel()
                    if let data, data.count > 24 * 1024 * 1024 { gate.complete((nil, "Native helper response exceeded bounds")); return }
                    gate.complete((data, error))
                }
            }
        } catch { return (nil, "Native helper signature could not be validated: \(error.localizedDescription)") }
    }
    func discover() async throws -> [EngineItemRecord] {
        for attempt in 0..<2 {
            let (data, error) = await request { $0.discover($1) }
            if let data { return try JSONDecoder().decode([EngineItemRecord].self, from: data) }
            guard attempt == 0 else { throw EngineError.helper(error ?? "Discovery failed") }
            connection?.invalidate(); connection = nil
        }
        throw EngineError.helper("Discovery failed")
    }
    func resolve(_ target: EngineItemRecord) async throws -> EngineItemRecord {
        let requestData = try JSONEncoder().encode(target)
        let (data, _) = await request { $0.resolve(requestData, reply: $1) }
        guard let data, let matches = try? JSONDecoder().decode([EngineItemRecord].self, from: data), matches.count == 1, let item = matches.first else { throw EngineError.unresolved }
        return item
    }
    func capture(_ ids: [UInt32]) async -> [EngineCaptureFrame] {
        for attempt in 0..<2 {
            let (data, _) = await request(capture: true) { $0.capture(ids.prefix(64).map { NSNumber(value: $0) }, reply: $1) }
            if let data, let frames = try? JSONDecoder().decode([EngineCaptureFrame].self, from: data) {
                guard frames.count <= 64, frames.reduce(0, { $0 + $1.pixels.count }) <= 16 * 1024 * 1024 else { return [] }
                return frames.filter { ids.contains($0.windowID) && EngineCaptureFrame.isValid(width: $0.width, height: $0.height, bytesPerRow: $0.bytesPerRow, count: $0.pixels.count) }
            }
            if attempt == 0 { captureConnection?.invalidate(); captureConnection = nil }
        }
        return []
    }
    func press(_ item: EngineItemRecord) async -> Bool? {
        guard let data = try? JSONEncoder().encode(item) else { return nil }
        let (result, error) = await request { proxy, reply in
            proxy.press(data) { success, error in reply(Data([success ? 1 : 0]), error) }
        }
        guard error == nil, let value = result?.first else { return nil }
        return value == 1
    }
}

enum EngineError: Error, LocalizedError {
    case helper(String), unsupportedOS, unresolved, controlsUnavailable, permission, busy, moveFailed, deadline
    var errorDescription: String? {
        switch self {
        case .helper(let message): return message
        case .unsupportedOS: return "Native menu-bar management is supported on macOS 15 through 26. Icons remain accessible on this system."
        case .unresolved: return "The native target could not be resolved uniquely. It was left visible."
        case .controlsUnavailable: return "OverflowBar’s native arrow/divider could not be located. Reveal and retry setup."
        case .permission: return "Enable Accessibility to arrange or activate the selected icons."
        case .busy: return "A native operation is already running. Wait or cancel it."
        case .moveFailed: return "macOS did not confirm the native icon move. The group was left visible."
        case .deadline: return "The native operation reached its deadline. The group was left visible."
        }
    }
}
