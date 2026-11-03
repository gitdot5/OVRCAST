import XCTest
@testable import UsageBoardMenuBar

final class ReliabilityTests: XCTestCase {
    func testOlderPreferencesRetainPrivacyAliasesAndRemoteConnections() throws {
        let json = #"{"privacyMode":true,"aliases":{"account":"My label"},"remotes":[{"name":"Mac mini","sshAlias":"test-mini"}]}"#
        let prefs = try JSONDecoder().decode(BoardPreferences.self, from: Data(json.utf8))
        XCTAssertTrue(prefs.privacyMode); XCTAssertEqual(prefs.aliases["account"], "My label")
        XCTAssertEqual(prefs.providers, ["Codex", "Claude"])
        XCTAssertEqual(prefs.remotes.first?.sshAlias, "test-mini"); XCTAssertEqual(prefs.remotes.first?.status, "Not checked")
        XCTAssertEqual(try JSONDecoder().decode(BoardPreferences.self, from: JSONEncoder().encode(prefs)).remotes.first?.id, prefs.remotes.first?.id)
    }
    func testInvalidPreferenceRangesAndUnknownProvidersAreNormalized() throws {
        let prefs = try JSONDecoder().decode(BoardPreferences.self, from: Data(#"{"providers":["Codex","unexpected","Codex","Claude"],"lowThreshold":500,"quietStart":-4,"quietEnd":60,"machineName":"  "}"#.utf8))
        XCTAssertEqual(prefs.providers, ["Codex", "Claude"]); XCTAssertEqual(prefs.lowThreshold, 100)
        XCTAssertEqual(prefs.quietStart, 0); XCTAssertEqual(prefs.quietEnd, 23); XCTAssertEqual(prefs.machineName, "This Mac")
    }
    @MainActor func testDamagedPreferencesArePreservedBeforeDefaultsCanBeSaved() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let original = Data("damaged settings".utf8)
        try original.write(to: folder.appendingPathComponent("preferences.json"))
        let store = UsageStore(root: folder.appendingPathComponent("no-source"), dataDirectory: folder, demo: false)
        XCTAssertTrue(store.message?.contains("recovery copy") == true)
        XCTAssertTrue(store.preferences.privacyMode)
        store.accounts = DemoData.snapshot().accounts
        XCTAssertFalse(store.accountName(store.accounts[0]).contains("@"))
        let backups = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("preferences-recovery-") }
        XCTAssertEqual(backups.count, 1); XCTAssertEqual(try Data(contentsOf: backups[0]), original)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: backups[0].path)[.posixPermissions] as? Int, 0o600)
        store.preferences.privacyMode = true
        XCTAssertEqual(PrivateFiles.read(BoardPreferences.self, from: folder.appendingPathComponent("preferences.json"))?.privacyMode, true)
    }
    @MainActor func testWriteFailureIsVisibleInsteadOfReportingSavedSettings() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("not a directory".utf8).write(to: file)
        let store = UsageStore(root: file, dataDirectory: file, demo: false)
        store.preferences.privacyMode = true
        XCTAssertNotNil(store.storageIssue); XCTAssertTrue(store.message?.contains("Could not save") == true)
    }
    @MainActor func testRemovedProviderDoesNotLeaveTheBoardOnAnEmptyTab() {
        let store = UsageStore(demo: true)
        store.selectedProvider = "Codex"
        var snapshot = DemoData.snapshot(); snapshot.accounts.removeAll { $0.provider == "Codex" }
        store.apply(snapshot)
        XCTAssertEqual(store.selectedProvider, "Overview"); XCTAssertFalse(store.visibleAccounts.isEmpty)
    }
    @MainActor func testNoSelectedProvidersPreservesExistingAccountsWithoutSpawningACollector() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = UsageStore(root: folder, dataDirectory: folder, demo: false)
        store.accounts = DemoData.snapshot().accounts; store.preferences.providers = []
        store.refreshNative(helper: "/fixture") { _,_,_ in XCTFail("Must not collect an empty provider selection"); return [] }
        XCTAssertFalse(store.refreshing); XCTAssertFalse(store.accounts.isEmpty)
        XCTAssertTrue(store.message?.contains("Choose at least one") == true)
    }
    @MainActor func testChangedConnectionsDiscardInFlightResultsWithoutPublishingThem() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = UsageStore(root: folder, dataDirectory: folder.appendingPathComponent("App"), demo: false)
        store.preferences.providers = ["Codex"]
        let started = expectation(description: "collector started"), gate = DispatchSemaphore(value: 0)
        store.refreshNative(helper: "/fixture") { _,_,_ in
            started.fulfill(); _ = gate.wait(timeout: .now() + 5)
            return DemoData.snapshot().accounts.filter { $0.provider == "Codex" }
        }
        await fulfillment(of: [started], timeout: 3)
        store.preferences.providers = ["Claude"]; gate.signal()
        for _ in 0..<100 where store.refreshing { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(store.refreshing); XCTAssertTrue(store.accounts.isEmpty)
        XCTAssertTrue(store.message?.contains("Connections changed") == true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("native-overview.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("App/overview.json").path))
    }
    @MainActor func testProviderFailureKeepsLastReadingButExcludesItFromAvailability() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = UsageStore(root: folder, dataDirectory: folder.appendingPathComponent("App"), demo: false)
        let previous = DemoData.snapshot().accounts.filter { $0.provider == "Codex" }
        store.accounts = previous; store.preferences.providers = ["Codex"]; store.preferences.machineName = "MacBook"
        store.refreshNative(helper: "/fixture") { provider, machine, _ in
            [NativeCollector.failure(provider: provider, machine: machine, issue: "Sign in through the provider.", signIn: true)]
        }
        for _ in 0..<100 where store.refreshing { try await Task.sleep(nanoseconds: 10_000_000) }
        let retained = try XCTUnwrap(store.accounts.first { $0.id == previous[0].id })
        XCTAssertEqual(retained.quotas.first?.remaining, previous[0].quotas.first?.remaining)
        XCTAssertFalse(retained.current); XCTAssertFalse(retained.available); XCTAssertEqual(retained.requiresSignIn, true)
        XCTAssertNil(Insights.recommend(store.accounts, provider: "Codex"))
        XCTAssertTrue(store.message?.contains("need attention") == true)
    }
    func testTimedOutHelperDoesNotLeaveARefreshWaitingIndefinitely() {
        let start = Date()
        XCTAssertThrowsError(try CommandRunner.run("/bin/sh", ["-c", "exec sleep 5"], timeout: 0.05))
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testMissingProviderToolGivesAnActionWithoutRequestingCredentials() throws {
        let data = Data(#"[{"error":{"kind":"provider","message":"Codex CLI not found in PATH"}}]"#.utf8)
        let rows = try NativeCollector.parse(data, provider: "Codex", machine: "Test")
        XCTAssertTrue(rows[0].issue.contains("Connect Codex")); XCTAssertEqual(rows[0].requiresSignIn, false)
        XCTAssertTrue(rows[0].quotas.isEmpty)
    }
    func testTimeoutExplainsTheFailureWithoutInventingAReading() {
        let rows = NativeCollector.collect(provider: "Codex", machine: "Test", helper: "/fixture") { _,_ in
            throw NSError(domain: "UsageBoard", code: 1)
        }
        XCTAssertTrue(rows[0].issue.contains("did not respond in time")); XCTAssertFalse(rows[0].available)
        XCTAssertTrue(rows[0].quotas.isEmpty)
    }

}
