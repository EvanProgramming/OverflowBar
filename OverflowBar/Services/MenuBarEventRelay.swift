import AppKit
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
        // Some protected macOS owners (notably Control Center) reject a
        // process-level event tap even when the caller has Accessibility
        // permission. Keep the session tap in that case and inject the event
        // directly into it; the session callback still forwards only to the
        // requested PID and consumes the global copy.
        // Control Center advertises a process tap even though it does not
        // deliver the null event used to synchronize that tap. Treat it as a
        // protected owner up front; otherwise the relay waits for a callback
        // that can never arrive and the subsequent drag/click is dropped.
        let isProtectedOwner = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.controlcenter"
        let pidTap = isProtectedOwner ? nil : CGEvent.tapCreateForPid(
            pid: pid,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: 1 << CGEventType.null.rawValue,
            callback: Self.callback,
            userInfo: info
        )
        self.pidTap = pidTap
        if let pidTap {
            pidSource = CFMachPortCreateRunLoopSource(nil, pidTap, 0)
            guard let sessionTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .tailAppendEventTap,
                // Consume the session copy for regular applications, then
                // forward the exact event to the owner process.
                options: .defaultTap,
                eventsOfInterest: 1 << event.type.rawValue,
                callback: Self.callback,
                userInfo: info
            ) else { return nil }
            self.sessionTap = sessionTap
            sessionSource = CFMachPortCreateRunLoopSource(nil, sessionTap, 0)
        }
    }

    func start() {
        // Control Center and a few other protected owners reject process
        // taps. Posting the already-targeted event directly to the session is
        // the only reliable path for those status items; adding a listen-only
        // tap here makes WindowServer swallow the event on recent macOS.
        guard let pidTap, let sessionTap, let sessionSource, let pidSource else {
            event.post(tap: .cgSessionEventTap)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.finish(true)
            }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in self?.finish(false) }
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
            if relay.pidTap != nil {
                // The process tap path must consume the session copy so the
                // synthetic click is not observed by unrelated applications.
                relay.event.postToPid(relay.pid)
                DispatchQueue.main.async { relay.finish(true) }
                return nil
            }
            // Control Center does not allow a process tap. Let the original
            // session event continue through WindowServer; its target PID and
            // window fields deliver it to the status item without a cursor
            // warp or a second synthetic event.
            DispatchQueue.main.async { relay.finish(true) }
            return Unmanaged.passUnretained(incoming)
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
