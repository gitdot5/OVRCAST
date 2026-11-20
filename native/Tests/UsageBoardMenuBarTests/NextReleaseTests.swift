import XCTest
import AppKit
@testable import UsageBoardMenuBar

final class NextReleaseTests: XCTestCase {
    @MainActor func testUpdaterDelegateDisablesSystemProfileFieldsAndReceivesCompletion() {
        XCTAssertTrue(AppUpdates.shared.responds(to: NSSelectorFromString("allowedSystemProfileKeysForUpdater:")))
        XCTAssertTrue(AppUpdates.shared.responds(to: NSSelectorFromString("updater:didFinishUpdateCycleForUpdateCheck:error:")))
    }
    func testHealthBackoffCapsAndManualSuccessRestoresNormalPolling() {
        var health = ConnectionHealth()
        let now = Date()
        for failure in 1...8 {
            health.finish([], now: now)
            XCTAssertEqual(health.failures, failure)
            XCTAssertEqual(health.retryAt!.timeIntervalSince(now), min(1800, 180 * pow(2, Double(failure - 1))))
            XCTAssertFalse(health.due(now: now))
            XCTAssertTrue(health.due(now: health.retryAt!))
        }
        health.finish([DemoData.snapshot().accounts[0]], now: now)
        XCTAssertEqual(health.failures, 0); XCTAssertNotNil(health.lastSuccess)
        XCTAssertEqual(health.retryAt!.timeIntervalSince(now), 180)
        XCTAssertEqual(health.displayState(now: now.addingTimeInterval(700)), .stale)
    }
    func testOpeningSignInOrStaleQuotaCannotVerifySetup() {
        let failure = NativeCollector.failure(provider: "Claude", machine: "Test", issue: "Sign in", signIn: true)
        XCTAssertEqual(ConnectionHealth.classify([failure]), .signInRequired)
        var stale = DemoData.snapshot().accounts[0]; stale.fresh = false
        XCTAssertEqual(ConnectionHealth.classify([stale]), .unavailable)
        XCTAssertEqual(ConnectionHealth.classify([DemoData.snapshot().accounts[0], failure]), .partial)
    }
    @MainActor func testSetupNeedsActualCurrentUsageAndDoesNotAcceptASignInLaunch() {
        let store = UsageStore(demo: true); store.preferences.providers = ["Codex"]; store.preferences.machineName = "MacBook"
        store.finishSetup(); XCTAssertFalse(store.preferences.setupComplete)
        store.accounts = [NativeCollector.failure(provider: "Codex", machine: "MacBook", issue: "Sign in", signIn: true)]
        XCTAssertFalse(store.canFinishSetup)
        store.accounts = DemoData.snapshot().accounts.filter { $0.provider == "Codex" }
        XCTAssertTrue(store.canFinishSetup); store.finishSetup(); XCTAssertTrue(store.preferences.setupComplete)
    }
    @MainActor func testLocalPublishesBeforeSlowRemoteFinishesAndFailuresAreIsolated() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = UsageStore(root: folder, dataDirectory: folder.appendingPathComponent("App"), demo: false)
        store.preferences.providers = ["Codex"]; store.preferences.machineName = "MacBook"
        store.preferences.remotes = [RemoteMachine(name: "Test mini", sshAlias: "test-mini")]
        let gate = DispatchSemaphore(value: 0), remoteStarted = expectation(description: "Remote started")
        store.refreshNative(helper: "/fixture", collect: { _,_,_ in DemoData.snapshot().accounts.filter { $0.provider == "Codex" } }, remote: { _ in
            remoteStarted.fulfill(); _ = gate.wait(timeout: .now() + 5); throw CocoaError(.fileReadUnknown)
        })
        await fulfillment(of: [remoteStarted], timeout: 3)
        for _ in 0..<100 where store.accounts.isEmpty { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(store.accounts.isEmpty); XCTAssertTrue(store.refreshing)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("native-overview.json").path))
        gate.signal()
        for _ in 0..<100 where store.refreshing { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(store.refreshing); XCTAssertTrue(store.accounts.contains(where: \.current))
        XCTAssertEqual(store.health["Codex"]?.state, .connected)
        XCTAssertEqual(store.health["remote:" + store.preferences.remotes[0].id]?.state, .unavailable)
    }
    @MainActor func testBackoffSuppressesAutomaticAttemptButManualRetryBypassesIt() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = UsageStore(root: folder, dataDirectory: folder.appendingPathComponent("App"), demo: false)
        store.preferences.providers = ["Codex"]
        var health = ConnectionHealth(); health.finish([]); store.health["Codex"] = health
        store.refreshNative(helper: "/fixture", force: false) { _,_,_ in XCTFail("Automatic attempt must wait"); return [] }
        XCTAssertFalse(store.refreshing)
        let called = expectation(description: "Manual retry")
        store.refreshNative(helper: "/fixture") { _,_,_ in called.fulfill(); return [] }
        await fulfillment(of: [called], timeout: 3)
        for _ in 0..<100 where store.refreshing { try await Task.sleep(nanoseconds: 10_000_000) }
    }
    func testFailedRemoteCannotReplaceUsableLocalReadingOfSameAccount() {
        let local = DemoData.snapshot().accounts[0]
        var failed = local; failed.fresh = false; failed.machines = ["Other Mac"]
        failed.observedAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(30)); failed.issue = "Unavailable"
        for rows in [[local, failed], [failed, local]] {
            let merged = NativeCollector.merge(rows)
            XCTAssertEqual(merged.count, 1); XCTAssertTrue(merged[0].current); XCTAssertTrue(merged[0].issue.isEmpty)
            XCTAssertTrue(merged[0].machines.contains("Other Mac"))
        }
    }
    func testSafeReportExcludesRawAccountAndMachineMaterialEvenInFailure() throws {
        var account = DemoData.snapshot().accounts[0]
        let marker = "PRIVATE_TEST_MARKER"
        account.id = marker; account.email = marker; account.issue = marker; account.machines = [marker]; account.plan = marker
        let text = SupportReport.text(accounts: [account], providers: ["Codex", marker], health: [marker: ConnectionHealth()], remoteCount: 1, native: true, helperAvailable: true, storageProblem: true)
        XCTAssertFalse(text.contains(marker)); XCTAssertFalse(text.contains("@"))
        let report = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        XCTAssertEqual(report?["storageProblem"] as? Bool, true)
        XCTAssertEqual((report?["connections"] as? [[String: Any]])?.count, 1)
    }
    func testForecastRequiresEnoughRecentContinuousSameWindowData() throws {
        let now = Date(), formatter = ISO8601DateFormatter()
        var account = DemoData.snapshot().accounts[0]
        let reset = formatter.string(from: now.addingTimeInterval(7200))
        account.observedAt = formatter.string(from: now); account.issue = ""; account.requiresSignIn = false; account.fresh = true
        let quota = Quota(label: "Session", remaining: 50, resetsAt: reset, resetPassed: false)
        let points = [(1800.0, 70.0), (900.0, 60.0), (0.0, 50.0)].map { offset, remaining in
            HistoryPoint(accountID: account.id, label: quota.label, date: parsedDate(account.observedAt)!.addingTimeInterval(-offset), remaining: remaining, reset: reset)
        }
        let estimate = try XCTUnwrap(CapacityForecast.estimate(account: account, quota: quota, history: points, now: now))
        XCTAssertEqual(estimate.hours, 1.25, accuracy: 0.01); XCTAssertTrue(estimate.beforeReset)
        XCTAssertNil(CapacityForecast.estimate(account: account, quota: quota, history: Array(points.prefix(2))))
        var resetPoints = points; resetPoints[1].reset = "different"
        XCTAssertNil(CapacityForecast.estimate(account: account, quota: quota, history: resetPoints))
        var increased = points; increased[1].remaining = 80
        XCTAssertNil(CapacityForecast.estimate(account: account, quota: quota, history: increased))
        account.fresh = false
        XCTAssertNil(CapacityForecast.estimate(account: account, quota: quota, history: points))
    }
    @MainActor func testCompactMenuNeverTreatsStaleCapacityAsUsable() {
        let store = UsageStore(demo: true); store.accounts = DemoData.snapshot().accounts
        XCTAssertTrue(store.compactStatus.contains("%"))
        store.accounts = store.accounts.map { old in var copy = old; copy.fresh = false; return copy }
        XCTAssertFalse(store.compactStatus.contains("%")); XCTAssertTrue(store.statusTooltip.contains("No current"))
    }
    func testOldPreferencesKeepNewFeaturesOptIn() throws {
        let prefs = try JSONDecoder().decode(BoardPreferences.self, from: Data(#"{"privacyMode":true,"setupComplete":true}"#.utf8))
        XCTAssertTrue(prefs.setupComplete); XCTAssertTrue(prefs.privacyMode)
        XCTAssertFalse(prefs.compactMenuBar); XCTAssertFalse(prefs.showForecasts)
    }
    @MainActor func testWorkspaceSleepWakeObserversAreInstalledAndRemoved() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = UsageStore(root: folder, dataDirectory: folder, demo: false)
        let lifecycle = RefreshLifecycle(); lifecycle.start(store: store)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(store.sleeping)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertFalse(store.sleeping); XCTAssertFalse(store.refreshing) // Unfinished setup never starts provider calls.
        lifecycle.stop()
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertFalse(store.sleeping)
    }

    @MainActor func testFailedLocalDoesNotRepublishRemoteQuotaAsItsOwnReading() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        var local = DemoData.snapshot().accounts[0]
        local.machines = ["MacBook"]; local.quotas[0].remaining = 80
        var remote = local; remote.machines = ["Other Mac"]; remote.quotas[0].remaining = 10
        remote.observedAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(10))
        try PrivateFiles.write(UsageSnapshot(version: 1, generatedAt: local.observedAt!, accounts: [local]), to: folder.appendingPathComponent("native-overview.json"))
        let store = UsageStore(root: folder, dataDirectory: folder.appendingPathComponent("App"), demo: false)
        store.preferences.providers = [local.provider]; store.preferences.machineName = "MacBook"
        store.accounts = NativeCollector.merge([local, remote])
        store.refreshNative(helper: "/fixture") { provider,machine,_ in [NativeCollector.failure(provider: provider, machine: machine, issue: "Unavailable")] }
        for _ in 0..<100 where store.refreshing { try await Task.sleep(nanoseconds: 10_000_000) }
        let published = try XCTUnwrap(PrivateFiles.read(UsageSnapshot.self, from: folder.appendingPathComponent("native-overview.json")))
        XCTAssertEqual(published.accounts[0].quotas[0].remaining, 80)
        XCTAssertEqual(published.accounts[0].machines, ["MacBook"]); XCTAssertFalse(published.accounts[0].current)
        let restarted = UsageStore(root: folder, dataDirectory: folder.appendingPathComponent("App"), demo: false)
        restarted.preferences = store.preferences
        restarted.refreshNative(helper: "/fixture") { provider,machine,_ in [NativeCollector.failure(provider: provider, machine: machine, issue: "Unavailable")] }
        for _ in 0..<100 where restarted.refreshing { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(restarted.accounts.first?.quotas.first?.remaining, 80)
    }

}
