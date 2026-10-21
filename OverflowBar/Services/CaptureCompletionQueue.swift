@MainActor
final class CaptureCompletionQueue {
    private var callbacks: [() -> Void] = []

    func append(_ callback: (() -> Void)?) {
        if let callback { callbacks.append(callback) }
    }

    func complete() {
        let pending = callbacks
        callbacks.removeAll()
        pending.forEach { $0() }
    }

    func cancel() { complete() }
}
