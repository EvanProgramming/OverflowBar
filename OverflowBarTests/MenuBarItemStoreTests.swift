import AppKit
import XCTest
@testable import OverflowBar

@MainActor
final class MenuBarItemStoreTests: XCTestCase {
    func testFirstInventorySeedsKnownItemsInsteadOfSelectingEverything() async {
        let (preferences, suite) = makePreferences()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.layoutManagementEnabled = true
        let engine = StoreTestEngine(items: [item("existing")])
        let store = MenuBarItemStore(preferences: preferences, engine: engine)

        store.refresh()
        await waitUntil { preferences.knownNativeItems != nil }

        XCTAssertEqual(preferences.knownNativeItems, ["existing"])
        XCTAssertTrue(store.selectedIDs.isEmpty)
        XCTAssertTrue(engine.appliedSelections.isEmpty)
    }

    func testSavedVerifiedOrderIdentifiesNewItemsAndPersistsKnowledge() async {
        let (preferences, suite) = makePreferences()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.layoutManagementEnabled = true
        preferences.verifiedNativeOrder = ["existing"]
        let engine = StoreTestEngine(items: [item("existing"), item("new")])
        let store = MenuBarItemStore(preferences: preferences, engine: engine)

        store.refresh()
        await waitUntil { engine.appliedSelections.count == 1 }

        XCTAssertEqual(store.selectedIDs, ["new"])
        XCTAssertEqual(preferences.selectedNativeItems, ["new"])
        XCTAssertEqual(preferences.knownNativeItems, ["existing", "new"])
        XCTAssertEqual(engine.appliedSelections, [["new"]])

        let relaunchedEngine = StoreTestEngine(items: [item("existing"), item("new")])
        let relaunchedStore = MenuBarItemStore(preferences: preferences, engine: relaunchedEngine)
        relaunchedStore.refresh()
        await waitUntil { relaunchedStore.items.count == 2 }
        XCTAssertTrue(relaunchedEngine.appliedSelections.isEmpty)
    }

    func testItemsDiscoveredWhileHidingIsOffAreRecordedButNotSelectedLater() async {
        let (preferences, suite) = makePreferences()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let engine = StoreTestEngine(items: [item("existing")])
        let store = MenuBarItemStore(preferences: preferences, engine: engine)
        store.refresh()
        await waitUntil { preferences.knownNativeItems != nil }

        engine.items = [item("existing"), item("visible-new-item")]
        store.refresh()
        await waitUntil { preferences.knownNativeItems?.contains("visible-new-item") == true }

        XCTAssertFalse(store.selectedIDs.contains("visible-new-item"))
        XCTAssertTrue(engine.appliedSelections.isEmpty)
    }

    func testNewUnprotectedStableItemsAreSelectedWhenHidingIsEnabled() async {
        let (preferences, suite) = makePreferences()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.layoutManagementEnabled = true
        let engine = StoreTestEngine(items: [item("existing")])
        let store = MenuBarItemStore(preferences: preferences, engine: engine)
        store.refresh()
        await waitUntil { preferences.knownNativeItems != nil }

        engine.items = [item("existing"), item("new"), item(nil), item("protected", title: "Item-11", bundle: "com.apple.controlcenter")]
        store.refresh()
        await waitUntil { engine.appliedSelections.count == 1 }

        XCTAssertEqual(store.selectedIDs, ["new"])
        XCTAssertEqual(preferences.knownNativeItems, ["existing", "new"])
        XCTAssertEqual(engine.appliedSelections, [["new"]])
    }

    func testRetryCancelsTheCurrentLayoutAndReappliesSavedSelectionOnce() async {
        let (preferences, suite) = makePreferences()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.selectedNativeItems = ["selected"]
        preferences.layoutManagementEnabled = true
        let engine = StoreTestEngine(items: [])
        engine.waitForCancel = true
        let store = MenuBarItemStore(preferences: preferences, engine: engine)

        store.setLayoutManagementEnabled(true)
        await waitUntil { engine.applyCount == 1 }
        store.retryHidingSelectedIcons()
        await waitUntil { engine.applyCount == 2 && store.canRetryHiding }

        XCTAssertEqual(engine.appliedSelections, [["selected"], ["selected"]])
        XCTAssertEqual(engine.maximumConcurrentApplies, 1)
        XCTAssertEqual(preferences.selectedNativeItems, ["selected"])
        XCTAssertTrue(preferences.layoutManagementEnabled)
    }

    private func makePreferences() -> (PreferencesStore, String) {
        let suite = "OverflowBarTests.\(UUID().uuidString)"
        return (PreferencesStore(defaults: UserDefaults(suiteName: suite)!), suite)
    }

    private func item(_ id: String?, title: String = "Example", bundle: String = "com.example.app") -> EngineItemRecord {
        EngineItemRecord(persistentID: id, title: title, bundleIdentifier: bundle, sourcePID: 1, ownerPID: 1, windowID: UInt32(abs(id?.hashValue ?? 1) % Int(UInt32.max)), frame: .zero, displayID: 1, accessibilityIdentifier: nil, supportsPress: false, isElectron: false, isOwnControl: false)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<1000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for the store")
    }
}

@MainActor
private final class StoreTestEngine: MenuBarEngine {
    var items: [EngineItemRecord]
    private(set) var records: [EngineItemRecord] = []
    private(set) var appliedSelections: [[String]] = []
    private(set) var applyCount = 0
    private(set) var maximumConcurrentApplies = 0
    private var activeApplies = 0
    var waitForCancel = false
    private var applyContinuation: CheckedContinuation<Void, Never>?
    var visibility: ((Bool) -> Void)?
    var message: ((String) -> Void)?
    var progress: ((String?) -> Void)?
    var recoveryRequired: (() -> Void)?

    init(items: [EngineItemRecord]) { self.items = items }
    func discover() async throws -> [EngineItemRecord] { records = items; return items }
    func apply(selected: [String], hidden: Bool, automatic: Bool) async throws {
        applyCount += 1
        activeApplies += 1
        maximumConcurrentApplies = max(maximumConcurrentApplies, activeApplies)
        appliedSelections.append(hidden ? selected : [])
        if waitForCancel && applyCount == 1 { await withCheckedContinuation { applyContinuation = $0 } }
        activeApplies -= 1
        visibility?(hidden)
    }
    func capture(_ items: [EngineItemRecord]) async -> [EngineCaptureFrame] { [] }
    func activate(_ id: String, button: CGMouseButton) async -> MenuBarActivationResult { .activated }
    func cancel() { applyContinuation?.resume(); applyContinuation = nil; visibility?(false) }
}
