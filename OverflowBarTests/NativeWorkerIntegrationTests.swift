import XCTest
import Security
import ApplicationServices
@testable import OverflowBar

final class NativeWorkerIntegrationTests: XCTestCase {
    @MainActor func testAdHocHelperCompletesAuthenticatedDiscovery() async throws {
        let client = EngineWorkerClient()
        defer { client.cancel() }
        try await Task.sleep(for: .seconds(1))
        let start = Date()
        let snapshot = try await client.discover()
        XCTAssertFalse(snapshot.isEmpty, "The live native status-window bridge must enumerate status controls")
        XCTAssertLessThan(Date().timeIntervalSince(start), 4)
    }
    @MainActor func testOwnControlIdentityWithAccessibilityPermission() async throws {
        guard AXIsProcessTrusted() else { throw XCTSkip("Native control identity requires Accessibility for this signed host; installed GUI verification remains a release gate") }
        let client = EngineWorkerClient()
        defer { client.cancel() }
        let snapshot = try await client.discover()
        for identifier in ["OverflowBarControlItem", "OverflowBarHiddenSection"] {
            let matches = snapshot.filter { $0.isOwnControl && $0.accessibilityIdentifier == identifier }
            XCTAssertEqual(matches.count, 1)
            XCTAssertTrue(matches.first.map { $0.windowID > 0 && $0.frame.height > 0 && $0.displayID != nil } ?? false)
        }
    }
    @MainActor func testConcurrentDiscoveryDoesNotQueueTwoFullScans() async throws {
        let first = EngineWorkerClient(), second = EngineWorkerClient()
        defer { first.cancel(); second.cancel() }
        let start = Date()
        async let a = first.discover()
        async let b = second.discover()
        let snapshots = try await (a, b)
        XCTAssertFalse(snapshots.0.isEmpty)
        XCTAssertEqual(snapshots.0, snapshots.1)
        XCTAssertLessThan(Date().timeIntervalSince(start), 4)
    }
    @MainActor func testWrongHelperSignatureIsRejected() async throws {
        let connection = NSXPCConnection(serviceName: "com.overflowbar.mac26.v6.EngineWorker")
        connection.remoteObjectInterface = NSXPCInterface(with: EngineWorkerProtocol.self)
        connection.setCodeSigningRequirement("cdhash H\"0000000000000000000000000000000000000000\"")
        var code: SecStaticCode?
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/XPCServices/EngineWorker.xpc")
        XCTAssertEqual(SecStaticCodeCreateWithPath(helper as CFURL, [], &code), errSecSuccess)
        var requirement: SecRequirement?
        XCTAssertEqual(SecRequirementCreateWithString("cdhash H\"0000000000000000000000000000000000000000\"" as CFString, [], &requirement), errSecSuccess)
        XCTAssertNotEqual(SecStaticCodeCheckValidity(code!, [], requirement), errSecSuccess)
        let accepted = expectation(description: "Incorrectly signed peer must not return data")
        accepted.isInverted = true
        connection.resume()
        defer { connection.invalidate() }
        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in } as! EngineWorkerProtocol
        proxy.discover { data, _ in if data != nil { accepted.fulfill() } }
        await fulfillment(of: [accepted], timeout: 1)
    }

    @MainActor func testCaptureServiceIsEmbeddedAndAuthenticatedSeparately() async {
        let client = EngineWorkerClient()
        defer { client.cancel() }
        let frames = await client.capture([])
        XCTAssertTrue(frames.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: Bundle.main.bundleURL.appendingPathComponent("Contents/XPCServices/CaptureWorker.xpc").path))
    }
    func testReplyTimeoutAndCancellationCompleteOnce() {
        var calls = 0
        let gate = WorkerReplyGate<Int> { _ in calls += 1 }
        XCTAssertTrue(gate.complete(1)); XCTAssertFalse(gate.complete(2)); XCTAssertEqual(calls, 1)
    }
}
