import AppKit
import Combine

@MainActor final class MenuBarItemStore: ObservableObject {
    @Published private(set) var items: [MenuBarItem] = []
    @Published var lastActivationError: String?
    @Published private(set) var groupHidden = false
    @Published private(set) var layoutManagementEnabled = false
    @Published private(set) var layoutOperationMessage: String?
    @Published private(set) var iconCaptureMessage: String?
    @Published private(set) var operationProgress: String?
    var nativeOperationInProgress: Bool { operationProgress != nil || activationTask != nil }
    @Published private(set) var selectedIDs: [String]
    private let preferences: PreferencesStore
    private let engine: MenuBarEngine
    private var records: [String: EngineItemRecord] = [:]
    private var dividerFrame: CGRect?
    private var refreshTask: Task<Void, Never>?
    private var captureTask: Task<Void, Never>?
    private var activationTask: Task<Void, Never>?
    var onControlsRecoveryRequested: (() -> Void)?
    var onShowPanelRequested: (() -> Void)?
    private var layoutTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private let captureCallbacks = CaptureCompletionQueue()
    private var captureGeneration = 0
    private var refreshRequested = false
    private var discoveryFailed = false
    private var needsReapply = true
    private var automaticManagementSuspended = false
    private var previousSignature: Set<String> = []
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    var onLayoutStateChanged: (() -> Void)?
    init(preferences: PreferencesStore = PreferencesStore(), engine: MenuBarEngine? = nil) {
        self.preferences = preferences
        self.engine = engine ?? NativeMenuBarEngine()
        selectedIDs = preferences.selectedNativeItems
        layoutManagementEnabled = preferences.layoutManagementEnabled
        self.engine.visibility = { [weak self] hidden in
            self?.groupHidden = hidden; self?.onLayoutStateChanged?()
        }
        self.engine.message = { [weak self] text in self?.lastActivationError = text }
        self.engine.progress = { [weak self] text in self?.operationProgress = text }
        self.engine.recoveryRequired = { [weak self] in self?.automaticManagementSuspended = true }
    }
    var preferencesExplanationPending: Bool { false }
    var canRetryHiding: Bool { layoutManagementEnabled && !selectedIDs.isEmpty && activationTask == nil && retryTask == nil }
    var overflowItems: [MenuBarItem] { selectedIDs.compactMap { id in items.first { $0.id == id && $0.nativeRecord?.persistentID != nil } } }
    func startMonitoring() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.requestAutomaticReapply() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.requestAutomaticReapply(resetDividerFrame: true) }
        })
    }
    private func requestAutomaticReapply(resetDividerFrame: Bool = false) {
        if resetDividerFrame { dividerFrame = nil }
        needsReapply = true; previousSignature = []; refresh()
    }
    func refresh() {
        guard refreshTask == nil, layoutTask == nil, operationProgress == nil else { refreshRequested = true; return }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.engine.discover()
                if self.discoveryFailed { self.layoutOperationMessage = nil; self.discoveryFailed = false }
                self.update(snapshot)
                let eligibleIDs = snapshot.compactMap { record -> String? in
                    guard let id = record.persistentID, !record.isOwnControl,
                          !MenuBarSystemItemClassifier.isProtected(record.title, owner: record.bundleIdentifier) else { return nil }
                    return id
                }
                let savedKnownIDs = self.preferences.knownNativeItems
                let priorOrder = self.preferences.verifiedNativeOrder
                var knownIDs = Set(savedKnownIDs ?? (priorOrder.isEmpty ? eligibleIDs : priorOrder))
                let newIDs = savedKnownIDs == nil && priorOrder.isEmpty ? [] : eligibleIDs.filter { !knownIDs.contains($0) }
                knownIDs.formUnion(eligibleIDs)
                if knownIDs != Set(savedKnownIDs ?? []) { self.preferences.knownNativeItems = knownIDs.sorted() }
                let newlySelected = newIDs.filter { self.preferences.layoutManagementEnabled && !self.selectedIDs.contains($0) }
                if !newlySelected.isEmpty {
                    self.selectedIDs.append(contentsOf: newlySelected)
                    self.preferences.selectedNativeItems = self.selectedIDs
                    self.needsReapply = false
                    self.applyLayout(automatic: true)
                }
                let signature = Set(snapshot.map { "\($0.windowID)|\($0.persistentID ?? "?")|\(Int($0.frame.minX))|\(Int($0.frame.minY))" })
                if signature == self.previousSignature, self.preferences.nativeSelectionMigrationPending,
                   let divider = snapshot.first(where: { $0.isOwnControl && $0.accessibilityIdentifier == "OverflowBarHiddenSection" }),
                   snapshot.filter({ !$0.isOwnControl && $0.displayID == divider.displayID }).allSatisfy({ $0.persistentID != nil }) {
                    let group = snapshot.filter { !$0.isOwnControl && !MenuBarSystemItemClassifier.isProtected($0.title, owner: $0.bundleIdentifier) && $0.displayID == divider.displayID && $0.frame.maxX <= divider.frame.minX }.sorted { $0.frame.minX < $1.frame.minX }.map(\.id)
                    self.preferences.importNativeSelection(resolvedIDs: Set(snapshot.compactMap(\.persistentID)), observedGroup: group)
                    self.selectedIDs = self.preferences.selectedNativeItems
                }
                let resolvedIDs = Set(snapshot.compactMap(\.persistentID))
                let hasDivider = snapshot.contains { $0.isOwnControl && $0.accessibilityIdentifier == "OverflowBarHiddenSection" }
                let hasArrow = snapshot.contains { $0.isOwnControl && $0.accessibilityIdentifier == "OverflowBarControlItem" }
                if self.layoutTask == nil, self.needsReapply && signature == self.previousSignature && !signature.isEmpty,
                   let divider = snapshot.first(where: { $0.isOwnControl && $0.accessibilityIdentifier == "OverflowBarHiddenSection" }),
                   NativeLayoutPolicy.isReadyToReapply(selected: Set(self.selectedIDs), resolved: resolvedIDs, hasDivider: hasDivider, hasArrow: hasArrow) {
                    self.needsReapply = false
                    let items = snapshot.filter { !$0.isOwnControl && $0.displayID == divider.displayID }.map { (id: $0.id, frame: $0.frame) }
                    let dividerFrame = MenuBarGroupGeometry.membershipFrame(compactFrame: self.dividerFrame, currentFrame: divider.frame) ?? divider.frame
                    let layoutStillHidden = NativeLayoutPolicy.hiddenPlacementIsVerified(groupHidden: self.groupHidden, items: items, divider: dividerFrame, selected: Set(self.selectedIDs))
                    if !layoutStillHidden && !self.automaticManagementSuspended && self.preferences.layoutManagementEnabled && !self.selectedIDs.isEmpty { self.applyLayout(automatic: true) }
                }
                self.previousSignature = signature
                if self.layoutOperationMessage == nil { self.layoutOperationMessage = self.groupHidden ? "Selected icons are in the second row." : "Choose the icons to place in the second row." }
            } catch { self.discoveryFailed = true; self.layoutOperationMessage = error.localizedDescription }
            self.refreshTask = nil
            if self.refreshRequested { self.refreshRequested = false; self.refresh() }
        }
    }
    private func update(_ snapshot: [EngineItemRecord]) {
        let old = Dictionary(items.map { ($0.id, $0.iconImage) }, uniquingKeysWith: { first, _ in first })
        let publicItems = snapshot.filter { !$0.isOwnControl }
        records = Dictionary(snapshot.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        items = publicItems.map { record in
            let app = record.sourcePID.flatMap(NSRunningApplication.init(processIdentifier:))
            let ownerName = app?.localizedName ?? (record.persistentID == nil ? "Unknown item" : record.bundleIdentifier.map { String($0.split(separator: ".").last ?? "App").capitalized } ?? "macOS")
            let item = MenuBarItem(id: record.id, title: record.title, ownerName: ownerName, bundleIdentifier: record.bundleIdentifier, frame: record.frame, axElement: nil, iconImage: old[record.id] ?? nil, applicationIcon: app?.icon, supportsPressAction: record.supportsPress, windowID: record.windowID, ownerPID: record.ownerPID, isProtectedSystemItem: MenuBarSystemItemClassifier.isProtected(record.title, owner: record.bundleIdentifier))
            item.nativeRecord = record
            return item
        }.sorted { $0.frame.minX < $1.frame.minX }
    }
    func setSelected(_ item: MenuBarItem, selected: Bool) {
        guard layoutTask == nil, operationProgress == nil, item.nativeRecord?.persistentID != nil, !item.isProtectedSystemItem else { return }
        if selected { if !selectedIDs.contains(item.id) { selectedIDs.append(item.id) } }
        else { selectedIDs.removeAll { $0 == item.id } }
        preferences.selectedNativeItems = selectedIDs
        if layoutManagementEnabled { applyLayout(automatic: false) }
    }
    func configureSelection(_ ids: [String], hideSelectedIcons: Bool) {
        guard layoutTask == nil, operationProgress == nil else { return }
        selectedIDs = ids
        preferences.selectedNativeItems = ids
        layoutManagementEnabled = hideSelectedIcons && !ids.isEmpty
        preferences.layoutManagementEnabled = layoutManagementEnabled
        automaticManagementSuspended = !layoutManagementEnabled
        if layoutManagementEnabled || groupHidden { applyLayout(automatic: false) }
        else { layoutOperationMessage = "Choose the icons to place in the second row." }
    }
    func setLayoutManagementEnabled(_ enabled: Bool) {
        if !enabled { cancelOperation() }
        layoutManagementEnabled = enabled && !selectedIDs.isEmpty
        automaticManagementSuspended = !layoutManagementEnabled
        preferences.layoutManagementEnabled = layoutManagementEnabled
        applyLayout(automatic: false)
    }
    private func applyLayout(automatic: Bool) {
        guard layoutTask == nil else { layoutOperationMessage = "A layout operation is already running. Cancel it before changing selection."; return }
        operationProgress = "Finding menu bar icons"
        let selection = selectedIDs
        let hidden = preferences.layoutManagementEnabled && !selection.isEmpty
        layoutTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.engine.apply(selected: selection, hidden: hidden, automatic: automatic)
                self.update(self.engine.records)
                self.layoutOperationMessage = hidden ? "Selected icons are in the second row." : "Menu bar icons are visible."
            } catch { self.automaticManagementSuspended = true; self.layoutOperationMessage = error.localizedDescription }
            self.layoutTask = nil; self.operationProgress = nil
            if self.refreshRequested { self.refreshRequested = false; self.refresh() }
        }
    }
    func retryHidingSelectedIcons() {
        guard canRetryHiding else { return }
        retryTask = Task { [weak self] in
            guard let self else { return }
            let currentLayout = self.layoutTask
            currentLayout?.cancel()
            self.engine.cancel()
            await currentLayout?.value
            self.automaticManagementSuspended = false
            self.applyLayout(automatic: false)
            let retryLayout = self.layoutTask
            await retryLayout?.value
            self.retryTask = nil
        }
    }
    func cancelOperation() {
        automaticManagementSuspended = true
        activationTask?.cancel(); layoutTask?.cancel(); captureTask?.cancel(); engine.cancel()
        layoutOperationMessage = "Canceled. Menu bar icons are visible."
    }
    func restoreAllAndDisable() {
        cancelOperation(); onControlsRecoveryRequested?(); preferences.resetLayoutState(); preferences.selectedNativeItems = []; selectedIDs = []
        setLayoutManagementEnabled(false)
    }
    func prepareForTermination(completion: @escaping () -> Void) {
        activationTask?.cancel(); layoutTask?.cancel(); refreshTask?.cancel(); engine.cancel(); cancelPendingCapture()
        completion()
    }
    func cancelPendingCapture() {
        captureGeneration += 1; captureTask?.cancel(); captureTask = nil; captureCallbacks.cancel()
    }
    func refreshImages(completion: (() -> Void)? = nil) {
        captureCallbacks.append(completion)
        guard captureTask == nil else { return }
        let selected = overflowItems.compactMap(\.nativeRecord)
        guard !selected.isEmpty else { captureCallbacks.complete(); return }
        captureGeneration += 1; let generation = captureGeneration
        captureTask = Task { [weak self] in
            guard let self else { return }
            let frames = await self.engine.capture(selected)
            guard self.captureGeneration == generation else { return }
            self.captureTask = nil
            for frame in frames {
                guard let provider = CGDataProvider(data: frame.pixels as CFData),
                      let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { continue }
                let captured = NSImage(cgImage: image, size: CGSize(width: Double(frame.width) / frame.scale, height: Double(frame.height) / frame.scale))
                captured.isTemplate = EngineCaptureFrame.isMonochrome(frame.pixels)
                self.items.first { $0.windowID == frame.windowID }?.iconImage = captured
            }
            self.iconCaptureMessage = frames.count == selected.count ? "Live icon previews are ready." : "Some live previews are unavailable. Enable Screen Recording or use the available app icons."
            self.objectWillChange.send(); self.captureCallbacks.complete()
        }
    }
    func activate(_ item: MenuBarItem, mouseButton: CGMouseButton = .left, completion: ((MenuBarActivationResult) -> Void)? = nil) {
        lastActivationError = nil
        guard activationTask == nil else { lastActivationError = "A menu bar action is already running."; return }
        activationTask = Task { [weak self] in
            guard let self else { return }
            defer { self.activationTask = nil }
            let result = await self.engine.activate(item.id, button: mouseButton)
            if result != .activated { self.automaticManagementSuspended = true }
            if let message = result.layoutMessage(groupHidden: self.groupHidden) { self.layoutOperationMessage = message }
            if result == .unobserved { self.lastActivationError = "OverflowBar couldn't confirm that this icon opened. It's still available in the menu bar; open it there." }
            if result == .awaitingManualInterface { self.lastActivationError = "Open this icon from the menu bar. OverflowBar will put it back after its menu closes." }
            completion?(result)
        }
    }
    func revealOriginals() { setLayoutManagementEnabled(false) }
    func refreshIfWindowSetChanged(immediate: Bool = false) { refresh() }
    func nativeControlFrame(_ name: String) -> CGRect? {
        guard let item = engine.records.first(where: { $0.isOwnControl && $0.accessibilityIdentifier == name }),
              let display = item.displayID,
              let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display }) else { return nil }
        let bounds = CGDisplayBounds(display)
        return CGRect(x: screen.frame.minX + item.frame.minX - bounds.minX, y: screen.frame.maxY - item.frame.maxY + bounds.minY, width: item.frame.width, height: item.frame.height)
    }
    func updateDividerFrame(_ frame: CGRect?) { dividerFrame = frame }
    func updateStatusItemWindowIDs(control: CGWindowID?, hidden: CGWindowID?) { refresh() }
    func showManualGroupingExplanation() { }
    deinit {
        timer?.invalidate()
        for observer in observers { NotificationCenter.default.removeObserver(observer); NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
}
