import CoreGraphics

/// Relays a synthetic event through the same WindowServer path used by a real
/// menu-bar interaction. The two taps are short-lived and never move the cursor.
final class MenuBarEventRelay {
    private let event: CGEvent
    private let pid: pid_t
    private let completion: (Bool) -> Void
    private let nullMarker = Int64.random(in: 1...Int64.max)
    private var pidTap: CFMachPort?
    private var sessionTap: CFMachPort?
    private var pidSource: CFRunLoopSource?
    private var sessionSource: CFRunLoopSource?
    private var finished = false

    init?(event: CGEvent, pid: pid_t, completion: @escaping (Bool) -> Void) {
        self.event = event
        self.pid = pid
        self.completion = completion

        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let pidTap = CGEvent.tapCreateForPid(
            pid: pid,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: 1 << CGEventType.null.rawValue,
            callback: Self.callback,
            userInfo: info
        ), let sessionTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: 1 << event.type.rawValue,
            callback: Self.callback,
            userInfo: info
        ) else { return nil }

        self.pidTap = pidTap
        self.sessionTap = sessionTap
        pidSource = CFMachPortCreateRunLoopSource(nil, pidTap, 0)
        sessionSource = CFMachPortCreateRunLoopSource(nil, sessionTap, 0)
    }

    func start() {
        guard let pidTap, let sessionTap, let pidSource, let sessionSource else {
            finish(false)
            return
        }
        let runLoop = CFRunLoopGetMain()
        CFRunLoopAddSource(runLoop, pidSource, .commonModes)
        CFRunLoopAddSource(runLoop, sessionSource, .commonModes)
        CGEvent.tapEnable(tap: pidTap, enable: true)
        CGEvent.tapEnable(tap: sessionTap, enable: true)

        let nullEvent = CGEvent(source: nil)!
        nullEvent.setIntegerValueField(.eventSourceUserData, value: nullMarker)
        nullEvent.postToPid(pid)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.finish(false) }
    }

    private static let callback: CGEventTapCallBack = { _, type, incoming, pointer in
        guard let pointer else { return Unmanaged.passUnretained(incoming) }
        let relay = Unmanaged<MenuBarEventRelay>.fromOpaque(pointer).takeUnretainedValue()
        if type == .null, incoming.getIntegerValueField(.eventSourceUserData) == relay.nullMarker {
            if let pidTap = relay.pidTap { CGEvent.tapEnable(tap: pidTap, enable: false) }
            relay.event.post(tap: .cgSessionEventTap)
            return nil
        }
        if type == relay.event.type,
           incoming.getIntegerValueField(.eventSourceUserData) == relay.event.getIntegerValueField(.eventSourceUserData) {
            if let sessionTap = relay.sessionTap { CGEvent.tapEnable(tap: sessionTap, enable: false) }
            relay.event.postToPid(relay.pid)
            DispatchQueue.main.async { relay.finish(true) }
        }
        return Unmanaged.passUnretained(incoming)
    }

    private func finish(_ success: Bool) {
        guard !finished else { return }
        finished = true
        let runLoop = CFRunLoopGetMain()
        if let source = pidSource { CFRunLoopRemoveSource(runLoop, source, .commonModes) }
        if let source = sessionSource { CFRunLoopRemoveSource(runLoop, source, .commonModes) }
        if let tap = pidTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let tap = sessionTap { CGEvent.tapEnable(tap: tap, enable: false) }
        completion(success)
    }
}
