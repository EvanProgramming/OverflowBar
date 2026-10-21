import Foundation
import OSLog

// Mutable discovery/capture state is confined to queue; XPC entrypoints enqueue work.
final class Worker: NSObject, NSXPCListenerDelegate, EngineWorkerProtocol, @unchecked Sendable {
    private let discovery = ExtrasDiscovery()
    private let capturer = CaptureWorker()
    private let queue = DispatchQueue(label: "com.overflowbar.worker", qos: .userInitiated)
    private let peerLock = NSLock()
    private var peers: [UUID: NSXPCConnection] = [:]
    private let discoveryReplyLock = NSLock()
    private var discoveryReplies: [(Data?, String?) -> Void] = []
    private let parentRequirement: String
    init(parentRequirement: String) { self.parentRequirement = parentRequirement }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(parentRequirement)
        connection.exportedInterface = NSXPCInterface(with: EngineWorkerProtocol.self)
        connection.exportedObject = self
        let peer = UUID()
        peerLock.lock(); peers[peer] = connection; peerLock.unlock()
        connection.invalidationHandler = { [weak self] in
            guard let self else { return }
            self.peerLock.lock(); self.peers.removeValue(forKey: peer); let empty = self.peers.isEmpty; self.peerLock.unlock()
            if empty { DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.peerLock.lock(); let stillEmpty = self.peers.isEmpty; self.peerLock.unlock()
                if stillEmpty { exit(0) }
            } }
        }
        connection.resume()
        return true
    }
    func resolve(_ request: Data, reply: @escaping (Data?, String?) -> Void) {
        queue.async {
            guard let target = try? JSONDecoder().decode(EngineItemRecord.self, from: request), let pid = target.sourcePID else { reply(nil, "Unresolved source"); return }
            let snapshot = self.discovery.discover(onlyPID: pid)
            let matches = snapshot.filter { $0.windowID == target.windowID && $0.persistentID == target.persistentID && $0.sourcePID == pid }
            do { reply(try JSONEncoder().encode(matches), nil) }
            catch { reply(nil, error.localizedDescription) }
        }
    }
    func discover(_ reply: @escaping (Data?, String?) -> Void) {
        Logger(subsystem: "com.overflowbar.native", category: "worker").info("Discovery request received")
        discoveryReplyLock.lock()
        discoveryReplies.append(reply)
        let startScan = discoveryReplies.count == 1
        discoveryReplyLock.unlock()
        guard startScan else { return }
        queue.async { autoreleasepool {
            let data: Data?; let error: String?
            do { data = try JSONEncoder().encode(self.discovery.discover()); error = nil }
            catch let failure { data = nil; error = failure.localizedDescription }
            self.discoveryReplyLock.lock()
            let replies = self.discoveryReplies; self.discoveryReplies.removeAll()
            self.discoveryReplyLock.unlock()
            Logger(subsystem: "com.overflowbar.native", category: "worker").info("Discovery replies completed: \(replies.count)")
            replies.forEach { $0(data, error) }
        } }
    }
    func capture(_ windowIDs: [NSNumber], reply: @escaping (Data?, String?) -> Void) {
        let requested = windowIDs.prefix(64).map(\.uint32Value)
        Task {
            let onscreen = await capturer.captureOnscreen(requested)
            let captured = Set(onscreen.map(\.windowID))
            queue.async { autoreleasepool {
                let offscreen = self.capturer.capture(requested.filter { !captured.contains($0) }, budget: max(0, 16 * 1024 * 1024 - onscreen.reduce(0, { $0 + $1.pixels.count })))
                do { reply(try JSONEncoder().encode(onscreen + offscreen), nil) }
                catch { reply(nil, error.localizedDescription) }
                if self.capturer.shouldRecycle { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exit(0) } }
            } }
        }
    }

    func press(_ request: Data, reply: @escaping (Bool, String?) -> Void) {
        queue.async {
            guard let item = try? JSONDecoder().decode(EngineItemRecord.self, from: request) else { reply(false, "Invalid target"); return }
            reply(self.discovery.press(item), nil)
        }
    }
    func shutdown(_ reply: @escaping () -> Void) { reply(); DispatchQueue.main.async { exit(0) } }
}

do {
    let parent = try PeerSigning.containingApplication(of: Bundle.main.bundleURL)
    let worker = Worker(parentRequirement: try PeerSigning.requirement(for: parent))
    let listener = NSXPCListener.service()
    listener.delegate = worker
    listener.resume()
} catch {
    fputs("OverflowBar worker rejected an invalid enclosing app signature\n", stderr)
    exit(1)
}
