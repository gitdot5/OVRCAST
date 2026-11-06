import XCTest
@testable import UsageBoardMenuBar

final class RecoveryCoordinatorTests: XCTestCase {
    @MainActor func testNetworkRestorationDuringWakeRefreshIsDeferredNotLost() async {
        var busy = false, calls = 0
        let retry = expectation(description: "Restored connection checked after wake attempt")
        let recovery = RecoveryCoordinator(minimumInterval: 0.05, eligible: { true }, busy: { busy }) {
            calls += 1; if calls == 2 { retry.fulfill() }
        }
        defer { recovery.stop() }
        recovery.request(); XCTAssertEqual(calls, 1)
        busy = true; recovery.request(); recovery.request(); recovery.request()
        busy = false; recovery.finished()
        XCTAssertEqual(calls, 1)
        await fulfillment(of: [retry], timeout: 2)
        XCTAssertEqual(calls, 2)
    }
    @MainActor func testRepeatedNetworkEventsAfterFastFailureCoalesceIntoOneRetry() async {
        var calls = 0
        let retry = expectation(description: "One deferred retry")
        let recovery = RecoveryCoordinator(minimumInterval: 0.05, eligible: { true }, busy: { false }) {
            calls += 1; if calls == 2 { retry.fulfill() }
        }
        defer { recovery.stop() }
        recovery.request()
        for _ in 0..<20 { recovery.request() }
        await fulfillment(of: [retry], timeout: 2)
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(calls, 2)
    }
    @MainActor func testDisabledCollectionAndStoppedCoordinatorDoNotRetry() async {
        var eligible = true, calls = 0
        let recovery = RecoveryCoordinator(minimumInterval: 0.04, eligible: { eligible }, busy: { false }) { calls += 1 }
        recovery.request(); recovery.request(); eligible = false
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(calls, 1)
        eligible = true; recovery.request(); recovery.request(); recovery.stop()
        let before = calls
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(calls, before)
    }
}
