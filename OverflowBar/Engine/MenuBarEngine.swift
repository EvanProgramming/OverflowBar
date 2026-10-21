// Copyright (Ice) © 2023–2025 Jordan Baird
// Copyright (Thaw) © 2026 Toni Förster
// Focused OverflowBar adapter of native layout/move/click/temporary-show primitives; GPL-3.0.
import AppKit
import ApplicationServices
import OSLog

@MainActor protocol MenuBarEngine: AnyObject {
    var records: [EngineItemRecord] { get }
    func discover() async throws -> [EngineItemRecord]
    func apply(selected: [String], hidden: Bool, automatic: Bool) async throws
    func capture(_ items: [EngineItemRecord]) async -> [EngineCaptureFrame]
    func activate(_ id: String, button: CGMouseButton) async -> MenuBarActivationResult
    func cancel()
}

@MainActor final class NativeMenuBarEngine: MenuBarEngine {
    private(set) var records: [EngineItemRecord] = []
    let worker = EngineWorkerClient()
    private let relay = NativeEventRelay()
    private let breaker = MoveCircuitBreaker()
    private var operating = false
    private var operationGeneration = 0
    private var restorations: [String: Task<Void, Never>] = [:]
    private var verifiedHiddenLayout = false
    var visibility: ((Bool) -> Void)?
    var message: ((String) -> Void)?
    var progress: ((String?) -> Void)?
    var recoveryRequired: (() -> Void)?
    private var revealed = true
    func cancel() {
        operationGeneration += 1; relay.cancel(); worker.cancel(); restorations.values.forEach { $0.cancel() }; restorations.removeAll()
        visibility?(false); revealed = true; verifiedHiddenLayout = false
    }
    func discover() async throws -> [EngineItemRecord] {
        records = try await worker.discover()
        return records
    }
    private func own(_ name: String) -> EngineItemRecord? {
        records.first { $0.isOwnControl && $0.accessibilityIdentifier == name }
    }
    private func protected(_ item: EngineItemRecord) -> Bool {
        item.isOwnControl || MenuBarSystemItemClassifier.isProtected(item.title, owner: item.bundleIdentifier)
    }
    private func resolve(_ id: String) async throws -> EngineItemRecord {
        _ = try await discover()
        let matches = records.filter { $0.persistentID == id }
        guard matches.count == 1, let item = matches.first, item.sourcePID != nil else { throw EngineError.unresolved }
        return try await worker.resolve(item)
    }
    private func waitForInput(_ budget: EngineMoveBudget) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while CGEventSource.buttonState(.combinedSessionState, button: .left) || CGEventSource.buttonState(.combinedSessionState, button: .right) || !NSEvent.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            guard ContinuousClock.now < deadline else { throw EngineError.busy }
            try await budget.sleep(for: .milliseconds(25))
        }
    }
    private func move(_ id: String, relativeTo targetID: String, left: Bool, repairingDivider: Bool = false, automatic: Bool = false) async throws {
        try Task.checkCancellation()
        guard !automatic || !breaker.isOpen else { throw EngineError.busy }
        if automatic { breaker.note(.move(identifier: id)) }
        var succeeded = false
        defer {
            if automatic && !succeeded {
                breaker.note(.failedMove)
                if repairingDivider { breaker.noteBulkApplyOutcome(unenactedMoveCount: 1) }
            }
        }
        let budget = EngineMoveBudget(limit: .seconds(15))
        try await waitForInput(budget)
        let item = try await resolve(id)
        guard (!protected(item) || (repairingDivider && item.isOwnControl && ["OverflowBarHiddenSection", "OverflowBarControlItem"].contains(item.accessibilityIdentifier ?? ""))),
              let cachedTarget = records.first(where: { $0.id == targetID }),
              let display = item.displayID, display == cachedTarget.displayID else { throw EngineError.unresolved }
        let target: EngineItemRecord
        if cachedTarget.persistentID != nil { target = try await worker.resolve(cachedTarget) }
        else {
            guard repairingDivider, let row = NativeWindowBridge.descriptions([cachedTarget.windowID]).first,
                  row[kCGWindowOwnerPID as String] as? Int32 == cachedTarget.ownerPID,
                  NativeWindowBridge.bounds(row) == cachedTarget.frame else { throw EngineError.unresolved }
            target = cachedTarget
        }
        let cursor = CGEvent(source: nil)?.location
        var releasePoint = item.frame.origin
        let pid = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 ? item.ownerPID : (item.sourcePID ?? item.ownerPID)
        CGDisplayHideCursor(display)
        defer {
            NativeEventRelay.release(point: releasePoint, window: item.windowID, pid: pid)
            if let cursor { CGWarpMouseCursorPosition(cursor) }
            CGDisplayShowCursor(display)
        }
        for attempt in 0..<3 {
            try Task.checkCancellation(); _ = try budget.remaining()
            guard let sourceFrame = NativeWindowBridge.frame(item.windowID), let targetFrame = NativeWindowBridge.frame(target.windowID) else { throw EngineError.unresolved }
            let bias: CGFloat = target.isOwnControl ? 1 : 0
            var end = CGPoint(x: left ? targetFrame.minX - bias : targetFrame.maxX + bias,
                              y: targetFrame.maxX <= CGDisplayBounds(display).minX ? targetFrame.midY : targetFrame.minY)
            releasePoint = end
            let onScreen = CGDisplayBounds(display).contains(CGPoint(x: sourceFrame.midX, y: sourceFrame.midY))
            let start = CGPoint(x: sourceFrame.midX, y: attempt == 2 ? sourceFrame.minY : sourceFrame.midY)
            if onScreen { CGWarpMouseCursorPosition(start) }
            let down = try NativeEventRelay.event(type: .leftMouseDown, point: start, window: item.windowID, pid: pid, command: true, moving: true)
            do {
                try await relay.post(down, pid: pid, moving: true, seconds: min(3.5, budget.remainingSeconds))
                try await budget.sleep(for: .milliseconds(25))
                if attempt == 2 && onScreen && CGDisplayBounds(display).contains(end) {
                    for step in 1...8 {
                        let fraction = CGFloat(step) / 8
                        let point = CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
                        let event = try NativeEventRelay.event(type: .leftMouseDragged, point: point, window: item.windowID, pid: pid, command: true, moving: true)
                        try await relay.post(event, pid: pid, moving: true, seconds: min(0.3, budget.remainingSeconds))
                    }
                }
                if targetFrame.maxX > CGDisplayBounds(display).minX, let currentTarget = NativeWindowBridge.frame(target.windowID) {
                    end = CGPoint(x: left ? currentTarget.minX - bias : currentTarget.maxX + bias, y: currentTarget.minY)
                }
                releasePoint = end
                let up = try NativeEventRelay.event(type: .leftMouseUp, point: end, window: item.windowID, pid: pid, command: false, moving: true)
                try await relay.post(up, pid: pid, moving: true, seconds: min(3.5, budget.remainingSeconds))
                NativeEventRelay.release(point: end, window: item.windowID, pid: pid)
                var previous: CGRect?
                for _ in 0..<24 {
                    try await budget.sleep(for: .milliseconds(25))
                    guard let current = NativeWindowBridge.frame(item.windowID), let anchor = NativeWindowBridge.frame(target.windowID) else { throw EngineError.unresolved }
                    let correct = left ? current.maxX <= anchor.minX + 2 && anchor.minX - current.maxX <= 32 : current.minX >= anchor.maxX - 2 && current.minX - anchor.maxX <= 32
                    if correct && previous == current { succeeded = true; return }
                    previous = current
                }
            } catch is CancellationError { throw CancellationError() }
            catch { NativeEventRelay.release(point: end, window: item.windowID, pid: pid) }
        }
        throw EngineError.moveFailed
    }
    func apply(selected: [String], hidden: Bool, automatic: Bool) async throws {
        guard MenuBarGroupGeometry.supportsHiding(osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion) else { visibility?(false); throw EngineError.unsupportedOS }
        guard !operating else { throw EngineError.busy }
        guard !automatic || breaker.permitsAutomaticBulkApply else { throw EngineError.busy }
        verifiedHiddenLayout = false
        operating = true; let generation = operationGeneration
        defer { operating = false; progress?(nil) }
        visibility?(false); revealed = true
        if !hidden { return }
        guard restorations.isEmpty else { throw EngineError.busy }
        guard AXIsProcessTrusted() else { throw EngineError.permission }
        try await Task.sleep(for: .milliseconds(150))
        _ = try await discover()
        guard let divider = own("OverflowBarHiddenSection"), let arrow = own("OverflowBarControlItem"), let display = divider.displayID,
              arrow.displayID == display else { throw EngineError.controlsUnavailable }
        var row = records.filter { $0.displayID == display }.sorted { $0.frame.minX < $1.frame.minX }
        // Move only our boundary past unmanaged icons; never guess their source or move them.
        if let firstVisible = row.first(where: { $0.id != divider.id && (!selected.contains($0.id) || protected($0)) }),
           firstVisible.frame.minX < divider.frame.maxX {
            try await move(divider.id, relativeTo: firstVisible.id, left: true, repairingDivider: true, automatic: automatic)
            _ = try await discover()
            row = records.filter { $0.displayID == display }.sorted { $0.frame.minX < $1.frame.minX }
        }
        if let boundary = own("OverflowBarHiddenSection"), let control = own("OverflowBarControlItem"),
           control.frame.minX < boundary.frame.maxX - 2 || !usable(control) {
            guard usable(boundary) else { throw EngineError.controlsUnavailable }
            try await move(control.id, relativeTo: boundary.id, left: false, repairingDivider: true, automatic: automatic)
            _ = try await discover()
            row = records.filter { $0.displayID == display }.sorted { $0.frame.minX < $1.frame.minX }
        }
        guard let boundary = own("OverflowBarHiddenSection"), let control = own("OverflowBarControlItem"),
              control.frame.minX >= boundary.frame.maxX - 2, usable(control) else { throw EngineError.controlsUnavailable }
        let current = row.map(\.id)
        let eligible = row.filter { selected.contains($0.id) && $0.persistentID != nil && !protected($0) }.map(\.id)
        let desired = NativeLayoutPolicy.desiredOrder(current: current, selected: eligible, divider: divider.id)
        let moves = NativeLayoutPolicy.moves(current: current, desired: desired, divider: divider.id)
        guard moves.allSatisfy({ move in row.contains { $0.id == move.item && $0.persistentID != nil && !protected($0) } }) else { throw EngineError.unresolved }
        let batchEnd = ContinuousClock.now.advanced(by: .seconds(60))
        var failures = 0
        for (index, operation) in moves.enumerated() {
            guard generation == operationGeneration else { throw CancellationError() }
            guard ContinuousClock.now < batchEnd else { throw EngineError.deadline }
            if automatic && breaker.isOpen { throw EngineError.busy }
            progress?("Arranging icon \(index + 1) of \(moves.count)")
            do {
                try await move(operation.item, relativeTo: operation.target, left: operation.left, automatic: automatic)
                failures = 0
            } catch {
                failures += 1
                breaker.noteBulkApplyOutcome(unenactedMoveCount: moves.count - index)
                if MoveCircuitBreaker.batchShouldAbandon(consecutiveFailures: failures) { throw error }
            }
        }
        let verificationDeadline = ContinuousClock.now.advanced(by: .seconds(1.5))
        var verified = false
        repeat {
            _ = try await discover()
            guard let boundary = own("OverflowBarHiddenSection") else { throw EngineError.controlsUnavailable }
            let actual = records.filter { $0.displayID == display && !$0.isOwnControl }
            if NativeLayoutPolicy.placementIsVerified(
                items: actual.map { (id: $0.id, frame: $0.frame) },
                divider: boundary.frame,
                selected: Set(eligible)
            ) { verified = true; break }
            guard ContinuousClock.now < verificationDeadline else { break }
            try await Task.sleep(for: .milliseconds(100))
        } while true
        guard verified else { breaker.noteBulkApplyOutcome(unenactedMoveCount: 1); throw EngineError.moveFailed }
        guard generation == operationGeneration else { throw CancellationError() }
        try Task.checkCancellation()
        if !automatic { breaker.noteUserOverride() }
        breaker.noteBulkApplyOutcome(unenactedMoveCount: 0)
        PreferencesStore().verifiedNativeOrder = records.filter { $0.displayID == display }.sorted { $0.frame.minX < $1.frame.minX }.map(\.id)
        visibility?(true); revealed = false; verifiedHiddenLayout = true
    }
    func capture(_ items: [EngineItemRecord]) async -> [EngineCaptureFrame] {
        guard CGPreflightScreenCaptureAccess() else { return [] }
        return await worker.capture(items.map(\.windowID))
    }
    private func usable(_ item: EngineItemRecord) -> Bool {
        guard let display = item.displayID else { return false }
        let bounds = CGDisplayBounds(display)
        guard bounds.contains(item.frame) else { return false }
        guard let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display }) else { return false }
        let segments = [screen.auxiliaryTopLeftArea, screen.auxiliaryTopRightArea].compactMap { $0 }.map { area in
            CGRect(x: bounds.minX + area.minX - screen.frame.minX, y: bounds.minY + screen.frame.maxY - area.maxY, width: area.width, height: area.height)
        }
        return NativeVisibilityPolicy.isUsable(item.frame, display: bounds, segments: segments, accessibilityFrame: item.accessibilityFrame)
    }
    private func onScreenWindows() -> [[String: Any]] {
        (CGWindowListCopyWindowInfo(.optionOnScreenOnly, 0) as? [[String: Any]] ?? []).filter { row in
            guard let frame = NativeWindowBridge.bounds(row) else { return false }
            guard let id = row[kCGWindowNumber as String] as? UInt32 else { return false }
            return frame.width > 0 && frame.height > 0 && !records.contains(where: { $0.windowID == id })
        }
    }
    private func activationWindows(pids: Set<Int32>, anchoredTo item: CGRect) -> [[String: Any]] {
        onScreenWindows().filter { row in
            guard let pid = row[kCGWindowOwnerPID as String] as? Int32,
                  let id = row[kCGWindowNumber as String] as? UInt32,
                  let layer = row[kCGWindowLayer as String] as? Int,
                  let frame = NativeWindowBridge.bounds(row) else { return false }
            return pids.contains(pid) || NativeResponseVerifier.isAnchoredPopup(NativeInterfaceWindow(id: id, pid: pid, layer: layer, frame: frame), to: item)
        }
    }
    func activate(_ id: String, button: CGMouseButton = .left) async -> MenuBarActivationResult {
        guard !operating else { message?(EngineError.busy.localizedDescription); return .unavailable }
        guard restorations.isEmpty else { message?("Close the current native menu before opening another icon, or reveal the group to cancel restoration."); return .unavailable }
        guard AXIsProcessTrusted() else { visibility?(false); revealed = true; message?(EngineError.permission.localizedDescription); return .manualFallback }
        operating = true
        defer { operating = false; progress?(nil) }
        let generation = operationGeneration
        progress?("Opening native menu")
        do {
            let item = try await resolve(id)
            guard !protected(item), item.displayID != nil else { throw EngineError.unresolved }
            let shouldRehide = verifiedHiddenLayout
            let ordered = records.filter { $0.displayID == item.displayID }.sorted { $0.frame.minX < $1.frame.minX }
            let index = ordered.firstIndex { $0.id == item.id }!
            let right = index + 1 < ordered.count ? ordered[index + 1].persistentID : nil
            let left = index > 0 ? ordered[index - 1].persistentID : nil
            var moved = false
            let temporaryReveal = !revealed && !usable(item)
            if temporaryReveal {
                visibility?(false)
                try await Task.sleep(for: .milliseconds(150))
                _ = try await discover()
            }
            let onScreen = usable(try await resolve(id))
            if !onScreen {
                guard let arrow = own("OverflowBarControlItem"), item.displayID == arrow.displayID else { throw EngineError.controlsUnavailable }
                try await move(id, relativeTo: arrow.id, left: true); moved = true
            }
            guard generation == operationGeneration else { throw CancellationError() }
            let live = try await resolve(id)
            guard let display = live.displayID, usable(live) else { throw EngineError.moveFailed }
            let pids = Set([live.ownerPID, live.sourcePID].compactMap { $0 })
            let before = Set(onScreenWindows().compactMap { $0[kCGWindowNumber as String] as? UInt32 })
            let originalFrame = live.frame
            var usedAX = false
            var axResult = "not attempted"
            if button == .left && NativeActivationPolicy.usesAccessibilityPress(isElectron: live.isElectron, supportsPress: live.supportsPress) {
                guard let pressed = await worker.press(live) else { throw EngineError.deadline }
                usedAX = pressed
                axResult = pressed ? "succeeded" : "not resolved"
                if !usedAX { usedAX = activationWindows(pids: pids, anchoredTo: live.frame).contains { row in (row[kCGWindowNumber as String] as? UInt32).map { !before.contains($0) } ?? false } }
            }
            guard generation == operationGeneration else { throw CancellationError() }
            let logger = Logger(subsystem: "com.overflowbar.native", category: "activation")
            logger.info("Activation target window=\(live.windowID, privacy: .public), sourcePID=\(live.sourcePID ?? 0, privacy: .public), ownerPID=\(live.ownerPID, privacy: .public), AX=\(axResult, privacy: .public), nativeEvent=\(!usedAX, privacy: .public), desiredHidden=\(shouldRehide, privacy: .public)")
            if !usedAX {
                let cursor = CGEvent(source: nil)?.location
                let point = CGPoint(x: live.frame.midX, y: live.frame.midY)
                CGDisplayHideCursor(display); CGWarpMouseCursorPosition(point)
                defer { NativeEventRelay.release(point: point, window: live.windowID, pid: live.ownerPID, button: button); if let cursor { CGWarpMouseCursorPosition(cursor) }; CGDisplayShowCursor(display) }
                try await Task.sleep(for: .milliseconds(10))
                let down = try NativeEventRelay.event(type: button == .right ? .rightMouseDown : .leftMouseDown, point: point, window: live.windowID, pid: live.ownerPID, command: false, button: button)
                let up = try NativeEventRelay.event(type: button == .right ? .rightMouseUp : .leftMouseUp, point: point, window: live.windowID, pid: live.ownerPID, command: false, button: button)
                try await relay.post(down, pid: live.ownerPID, moving: false)
                try await relay.post(up, pid: live.ownerPID, moving: false)
            }
            var interface: UInt32?
            var reacted = false
            var finalReaction: NativeResponseVerifier.Reaction = .unobserved
            for _ in 0..<25 {
                let windows = activationWindows(pids: pids, anchoredTo: originalFrame)
                let reaction = NativeResponseVerifier.observe(before: before, windows: windows.compactMap { row in
                    guard let id = row[kCGWindowNumber as String] as? UInt32, let pid = row[kCGWindowOwnerPID as String] as? Int32, let layer = row[kCGWindowLayer as String] as? Int, let frame = NativeWindowBridge.bounds(row) else { return nil }
                    return NativeInterfaceWindow(id: id, pid: pid, layer: layer, frame: frame)
                }, pids: pids, original: originalFrame, current: NativeWindowBridge.frame(live.windowID))
                finalReaction = reaction
                if case let .openedInterface(id) = reaction { interface = id }
                reacted = reaction != .unobserved
                if reacted { break }
                try await Task.sleep(for: .milliseconds(20))
            }
            if !reacted, let updated = try? await resolve(id) {
                finalReaction = NativeResponseVerifier.observe(before: before, windows: [], pids: pids, original: originalFrame, current: updated.frame, originalTitle: live.title, currentTitle: updated.title)
                reacted = finalReaction != .unobserved
            }
            logger.info("Activation response target window=\(live.windowID, privacy: .public), reaction=\(String(describing: finalReaction), privacy: .public), observedWindow=\(interface ?? 0, privacy: .public)")
            guard generation == operationGeneration else { throw CancellationError() }
            if NativeActivationPolicy.shouldRestoreAfterMenu(verifiedHiddenLayout: shouldRehide, moved: moved) {
                if interface != nil || !reacted {
                    if interface == nil { visibility?(false); revealed = true }
                    restorations[id]?.cancel()
                    restorations[id] = Task { [weak self] in
                        guard let self else { return }
                        defer { self.restorations[id] = nil }
                        var lifecycle = NativeInterfaceLifecycle(before: before, interface: interface)
                        for _ in 0..<3_000 {
                            try? await Task.sleep(for: .milliseconds(100))
                            guard !Task.isCancelled else { return }
                            let current = Set(self.activationWindows(pids: pids, anchoredTo: originalFrame).compactMap { $0[kCGWindowNumber as String] as? UInt32 })
                            guard lifecycle.observe(current) else { continue }
                            guard !self.operating else { continue }
                            self.operating = true; self.progress?("Restoring native icon")
                            defer { self.operating = false; self.progress?(nil) }
                            do {
                                _ = try await self.discover()
                                if moved {
                                    if let right, self.records.contains(where: { $0.id == right }) { try await self.move(id, relativeTo: right, left: true) }
                                    else if let left, self.records.contains(where: { $0.id == left }) { try await self.move(id, relativeTo: left, left: false) }
                                    else if let divider = self.own("OverflowBarHiddenSection") { try await self.move(id, relativeTo: divider.id, left: true) }
                                }
                                if shouldRehide { self.visibility?(true); self.revealed = false }
                            } catch { self.visibility?(false); self.revealed = true; self.recoveryRequired?(); self.message?("The item was left accessible because restoring it failed: \(error.localizedDescription)") }
                            return
                        }
                        self.visibility?(false); self.revealed = true; self.recoveryRequired?()
                        self.message?("Menu state remains uncertain. The item was left accessible.")
                    }
                } else {
                    visibility?(false); revealed = true
                }
            }
            return interface != nil ? .activated : reacted ? .itemChanged : restorations[id] == nil ? .unobserved : .awaitingManualInterface
        } catch {
            visibility?(false); revealed = true; message?(error.localizedDescription); return .manualFallback
        }
    }
}

extension EngineMoveBudget {
    var remainingSeconds: Double { max(0.01, Double((try? remaining())?.components.seconds ?? 0) + Double((try? remaining())?.components.attoseconds ?? 0) / 1e18) }
}
