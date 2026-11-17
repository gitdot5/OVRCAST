import XCTest
@testable import UsageBoardMenuBar

final class TokenActivityTests: XCTestCase {
    let now = ISO8601DateFormatter().date(from: "2026-11-17T18:00:00Z")!
    func harness(complete: Bool = true, days: [TokenDay] = []) -> TokenHarness {
        TokenHarness(schemaVersion: 1, provider: "codex", generatedAt: "2026-11-17T18:00:00Z", timeZone: "America/New_York", historyComplete: complete, days: days)
    }
    func day(_ date: String, input: Int? = 10, output: Int? = 5, total: Int? = 15) -> TokenDay {
        TokenDay(date: date, input: input, output: output, cacheRead: nil, cacheWrite: nil, total: total)
    }
    func testDailyAndSevenDayWindowsIncludeTodayAndExcludeOlderAndFutureRows() {
        let row = harness(days: [day("2026-11-10", total: 1000), day("2026-11-11", total: 1), day("2026-11-16", total: 2), day("2026-11-17", total: 3), day("2026-11-18", total: 1000)])
        XCTAssertEqual(row.summary(days: 1, now: now)?.total, 3)
        XCTAssertEqual(row.summary(days: 7, now: now)?.total, 6)
    }
    func testSourceTimezoneControlsDayBoundaryAcrossDST() {
        let row = harness(days: [day("2026-11-16", total: 30), day("2026-11-17", total: 90)])
        let beforeLocalMidnight = ISO8601DateFormatter().date(from: "2026-11-17T04:30:00Z")!
        XCTAssertEqual(row.summary(days: 1, now: beforeLocalMidnight)?.total, 30)
        XCTAssertEqual(row.summary(days: 1, now: now)?.total, 90)
    }
    func testMissingCountersAndPartialEmptyHistoryAreUnknownInsteadOfZero() {
        XCTAssertNil(harness(complete: false).summary(days: 1, now: now))
        let row = harness(complete: false, days: [day("2026-11-17", input: nil)])
        XCTAssertNil(row.summary(days: 7, now: now)?.input)
        XCTAssertNil(row.summary(days: 7, now: now)?.cacheRead)
        XCTAssertEqual(row.summary(days: 7, now: now)?.total, 15)
    }
    func testEstablishedEmptyHistoryIsZeroButOldEmptyHistoryCannotClaimToday() {
        XCTAssertEqual(harness().summary(days: 1, now: now)?.total, 0)
        var old = harness(); old.generatedAt = "2026-11-16T18:00:00Z"
        XCTAssertNil(old.summary(days: 1, now: now))
        old.error = "local_history_unavailable"
        XCTAssertNil(old.summary(days: 7, now: now))
    }
    func testOverflowCannotProduceANegativeOrSmallerTotal() {
        let row = harness(days: [day("2026-11-16", total: Int.max), day("2026-11-17", total: 1)])
        XCTAssertNil(row.summary(days: 7, now: now)?.total)
    }
    func testOptOutCancelsTheActualScopedSubprocessRatherThanOnlyItsResult() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let marker = folder.appendingPathComponent("started"), group = UUID().uuidString
        let child = Task.detached {
            try CommandRunner.run("/bin/sh", ["-c", ": > \"$1\"; exec /bin/sleep 30", "token-fixture", marker.path], timeout: 10, cancellationGroup: group)
        }
        for _ in 0..<500 where !FileManager.default.fileExists(atPath: marker.path) { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        let start = Date(); CommandRunner.cancel(group: group)
        let result = try await child.value
        XCTAssertNotEqual(result.code, 0); XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }
    func testMalformedDuplicateNegativeAndUnknownProviderDataAreRejected() throws {
        var row = harness(days: [day("2026-11-17")])
        func valid(_ value: TokenHarness) -> Bool {
            let ledger = TokenActivityLedger(generatedAt: "2026-11-17T18:00:00Z", machines: [TokenMachine(machine: "Mac Studio", harnesses: [value])])
            return (try? TokenActivityLedger.decode(JSONEncoder().encode(ledger))) != nil
        }
        XCTAssertTrue(valid(row))
        row.days[0].total = -1; XCTAssertFalse(valid(row))
        row = harness(days: [day("2026-11-17"), day("2026-11-17")]); XCTAssertFalse(valid(row))
        row = harness(); row.provider = "PRIVATE_PROVIDER"; XCTAssertFalse(valid(row))
        row = harness(); row.timeZone = "PRIVATE_ZONE"; XCTAssertFalse(valid(row))
        row = harness(); row.error = "PRIVATE_ERROR"; XCTAssertFalse(valid(row))
    }
    func testAgentOutputRedactsMachineNamesAndKeepsComputersSeparate() throws {
        let row = harness(days: [day("2026-11-17", total: 25)])
        let ledger = TokenActivityLedger(generatedAt: "2026-11-17T18:00:00Z", machines: [
            TokenMachine(machine: "Mac Studio PRIVATE_ONE", harnesses: [row]), TokenMachine(machine: "Mac Studio PRIVATE_TWO", harnesses: [row])])
        let result = AgentCLI.tokenReport(ledger, provider: "Codex", machine: nil, now: now)
        let text = String(decoding: result.data, as: UTF8.self)
        XCTAssertFalse(text.contains("PRIVATE_")); XCTAssertFalse(text.contains("50"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: result.data) as? [String: Any])
        XCTAssertEqual((object["machines"] as? [[String: Any]])?.count, 2)
        XCTAssertTrue(object["fleetTotal"] is NSNull)
        XCTAssertEqual(AgentCLI.tokenReport(ledger, provider: nil, machine: "mac-3", now: now).code, 64)
    }
    @MainActor func testTokenHistoryRequiresOptInAndDisablingRemovesPublishedCounters() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let folder = home.appendingPathComponent("Library/Application Support/UsageBoard/App")
        let store = UsageStore(root: home.appendingPathComponent("usage_board"), dataDirectory: folder, demo: false)
        XCTAssertFalse(store.preferences.tokenHistory)
        store.tokenActivity = DemoData.tokenActivity(); store.preferences.privacyMode = true
        XCTAssertNotEqual(store.machineName("Mac Studio 1"), store.machineName("Mac Studio 2"))
        store.preferences.agentAccess = true
        XCTAssertEqual(AgentCLI.run(["tokens"], home: home, now: now).code, 77)
        store.preferences.tokenHistory = true
        let ledger = TokenActivityLedger(generatedAt: "2026-11-17T18:00:00Z", machines: [TokenMachine(machine: "Mac Studio", harnesses: [harness()])])
        let published = folder.deletingLastPathComponent().appendingPathComponent("token-activity.json")
        try PrivateFiles.write(ledger, to: published); try PrivateFiles.write(ledger, to: folder.appendingPathComponent("token-activity.json"))
        XCTAssertEqual(AgentCLI.run(["tokens"], home: home, now: now).code, 0)
        store.setTokenHistory(false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: published.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("token-activity.json").path))
        XCTAssertEqual(AgentCLI.run(["tokens"], home: home, now: now).code, 77)
    }
}
