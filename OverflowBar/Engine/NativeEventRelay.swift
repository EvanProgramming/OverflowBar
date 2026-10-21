// Copyright (Ice) © 2023–2025 Jordan Baird
// Copyright (Thaw) © 2026 Toni Förster
// Port of the Ice/Thaw event barrier and scromble transport; GPL-3.0.
import AppKit

private final class NativeTap {
    var port: CFMachPort?
    var source: CFRunLoopSource?
    let handler: (CGEventType, CGEvent) -> CGEvent?
    init(pid: Int32?, type: CGEventType, passive: Bool, handler: @escaping (CGEventType, CGEvent) -> CGEvent?) {
        self.handler = handler
        let mask: CGEventMask = 1 << type.rawValue
        let callback: CGEventTapCallBack = { _, type, event, pointer in
            guard let pointer else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<NativeTap>.fromOpaque(pointer).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let port = tap.port { CGEvent.tapEnable(tap: port, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            return tap.handler(type, event).map { Unmanaged.passUnretained($0) }
        }
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let options: CGEventTapOptions = passive ? .listenOnly : .defaultTap
        if let pid { port = CGEvent.tapCreateForPid(pid: pid, place: passive ? .tailAppendEventTap : .headInsertEventTap, options: options, eventsOfInterest: mask, callback: callback, userInfo: pointer) }
        else { port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: passive ? .tailAppendEventTap : .headInsertEventTap, options: options, eventsOfInterest: mask, callback: callback, userInfo: pointer) }
        if let port {
            source = CFMachPortCreateRunLoopSource(nil, port, 0)
            if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
            CGEvent.tapEnable(tap: port, enable: true)
        }
    }
    func invalidate() {
        if let port { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil; port = nil
    }
    deinit { invalidate() }
}

@MainActor final class NativeEventRelay {
    private var taps: [NativeTap] = []
    private var continuation: CheckedContinuation<Void, Error>?
    private var timeout: DispatchWorkItem?
    func cancel() { finish(.failure(CancellationError())) }
    private func finish(_ result: Result<Void, Error>) {
        guard let continuation else { return }
        self.continuation = nil; timeout?.cancel(); timeout = nil
        taps.forEach { $0.invalidate() }; taps.removeAll()
        continuation.resume(with: result)
    }
    static func event(type: CGEventType, point: CGPoint, window: UInt32, pid: Int32, command: Bool, button: CGMouseButton = .left, moving: Bool = false) throws -> CGEvent {
        guard let session = CGEventSource(stateID: .combinedSessionState), let source = CGEventSource(stateID: .hidSystemState), let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button) else { throw EngineError.moveFailed }
        let allowed: CGEventFilterMask = [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents]
        for state in [CGEventSuppressionState.eventSuppressionStateRemoteMouseDrag, .eventSuppressionStateSuppressionInterval] {
            session.setLocalEventsFilterDuringSuppressionState(allowed, state: state)
        }
        source.localEventsSuppressionInterval = 0
        event.flags = command ? .maskCommand : []
        event.setIntegerValueField(.eventSourceUserData, value: Int64.random(in: 1...Int64.max))
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        let isDown = type == .leftMouseDown || type == .rightMouseDown
        event.setIntegerValueField(.mouseEventClickState, value: !moving && isDown ? 1 : 0)
        for field in [CGEventField.mouseEventWindowUnderMousePointer, .mouseEventWindowUnderMousePointerThatCanHandleThisEvent] { event.setIntegerValueField(field, value: Int64(window)) }
        if moving { event.setIntegerValueField(CGEventField(rawValue: 0x33)!, value: Int64(window)) }
        return event
    }
    func post(_ event: CGEvent, pid: Int32, moving: Bool, seconds: Double = 0.5) async throws {
        try Task.checkCancellation()
        guard continuation == nil else { throw EngineError.busy }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                guard let marker = CGEvent(source: nil) else { finish(.failure(EngineError.moveFailed)); return }
                let token = Int64.random(in: 1...Int64.max)
                marker.type = .null; marker.setIntegerValueField(.eventSourceUserData, value: token)
                let eventToken = event.getIntegerValueField(.eventSourceUserData)
                let window = event.getIntegerValueField(.mouseEventWindowUnderMousePointer)
                taps.append(NativeTap(pid: pid, type: .null, passive: false) { [weak self] _, received in
                    guard received.getIntegerValueField(.eventSourceUserData) == token else { return received }
                    guard self?.continuation != nil else { return nil }
                    event.post(tap: .cgSessionEventTap)
                    return nil
                })
                taps.append(NativeTap(pid: nil, type: event.type, passive: false) { [weak self] _, received in
                    guard received.getIntegerValueField(.eventSourceUserData) == eventToken else { return received }
                    if received.getIntegerValueField(.mouseEventWindowUnderMousePointer) != window {
                        self?.finish(.failure(EngineError.unresolved)); return nil
                    }
                    return received
                })
                taps.append(NativeTap(pid: nil, type: event.type, passive: true) { [weak self] _, received in
                    guard received.getIntegerValueField(.eventSourceUserData) == eventToken else { return received }
                    guard received.getIntegerValueField(.mouseEventWindowUnderMousePointer) == window else { self?.finish(.failure(EngineError.unresolved)); return received }
                    if moving { event.postToPid(pid) }
                    else { self?.finish(.success(())) }
                    return received
                })
                if moving {
                    taps.append(NativeTap(pid: pid, type: event.type, passive: true) { [weak self] _, received in
                        if received.getIntegerValueField(.eventSourceUserData) == eventToken { self?.finish(.success(())) }
                        return received
                    })
                }
                guard taps.allSatisfy({ $0.port != nil }) else { finish(.failure(EngineError.permission)); return }
                let timer = DispatchWorkItem { [weak self] in self?.finish(.failure(EngineError.deadline)) }
                timeout = timer
                DispatchQueue.main.asyncAfter(deadline: .now() + max(0.01, seconds), execute: timer)
                marker.postToPid(pid)
            }
        } onCancel: { Task { @MainActor in self.cancel() } }
    }
    static func release(point: CGPoint, window: UInt32, pid: Int32, button: CGMouseButton = .left) {
        guard let event = try? event(type: button == .right ? .rightMouseUp : .leftMouseUp, point: point, window: window, pid: pid, command: false, button: button) else { return }
        event.postToPid(pid); event.post(tap: .cgSessionEventTap)
    }
}
