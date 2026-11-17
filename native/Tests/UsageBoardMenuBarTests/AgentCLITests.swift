import XCTest
@testable import UsageBoardMenuBar

final class AgentCLITests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    func account(_ id: String = "codex:person@example.com", provider: String = "Codex", remaining: Double = 70) -> UsageAccount {
        UsageAccount(id: id, provider: provider, email: "person@example.com", plan: "PRIVATE_PLAN", machines: ["Mac Studio PRIVATE_HOST"],
                     severity: "good", status: "PRIVATE_STATUS", requiresSignIn: false, fresh: true, observedAt: iso(now),
                     source: "PRIVATE_SOURCE", issue: "", quotas: [Quota(label: "PRIVATE_WINDOW", remaining: remaining,
                     resetsAt: iso(now.addingTimeInterval(3600)), resetPassed: false)], resetDetails: [], credits: [])
    }
    func snapshot(_ accounts: [UsageAccount]) -> UsageSnapshot { UsageSnapshot(version: 1, generatedAt: iso(now), accounts: accounts) }
    func object(_ result: AgentCLI.Result) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: result.data) as? [String: Any])
    }
    func testAllowlistExcludesIdentitiesUntrustedLabelsAndCredentials() throws {
        var row = account(); row.credits = [CreditPool(name: "PRIVATE_CREDIT", value: "12345", detail: "PRIVATE_DETAIL")]
        let result = AgentCLI.report(snapshot([row]), command: "status", now: now)
        let text = String(decoding: result.data, as: UTF8.self)
        for marker in ["person@", "PRIVATE_", "codex:person", "12345"] { XCTAssertFalse(text.contains(marker), marker) }
        let report = try object(result)
        XCTAssertEqual(report["costDataAvailable"] as? Bool, false)
        XCTAssertEqual(report["automaticExecution"] as? Bool, false)
        XCTAssertEqual(report["mode"] as? String, "read_only")
    }
    func testUnsafeOrUnknownCapacityNeverProducesARecommendation() throws {
        for variant in ["stale", "future", "sign-in", "issue", "unknown", "reset", "passed", "zero", "below", "retired"] {
            var row = account()
            switch variant {
            case "stale": row.observedAt = iso(now.addingTimeInterval(-601))
            case "future": row.observedAt = iso(now.addingTimeInterval(61))
            case "sign-in": row.requiresSignIn = true
            case "issue": row.issue = "PRIVATE_ERROR"
            case "unknown": row.quotas = []
            case "reset": row.quotas[0].resetsAt = iso(now)
            case "passed": row.quotas[0].resetPassed = true
            case "zero": row.quotas[0].remaining = 0
            case "below": row.quotas[0].remaining = 14
            default: row.machines = ["Windows PC (retired)"]
            }
            let result = AgentCLI.report(snapshot([row]), command: "recommend", now: now)
            XCTAssertEqual(result.code, 2, variant)
            XCTAssertEqual((try object(result))["decision"] as? String, "no_eligible_capacity", variant)
        }
    }
    func testStaleSnapshotCannotMakeARecentAccountRoutable() {
        var snap = snapshot([account()]); snap.generatedAt = iso(now.addingTimeInterval(-601))
        XCTAssertEqual(AgentCLI.report(snap, command: "recommend", now: now).code, 2)
        snap.generatedAt = "unparseable"
        XCTAssertEqual(AgentCLI.report(snap, command: "recommend", now: now).code, 2)
    }
    func testSharedQuotaIsCountedOnceAndLowestWindowWins() throws {
        var shared = account(); shared.machines = ["Mac Studio 1", "Mac Studio 2"]
        shared.quotas.append(Quota(label: "Weekly", remaining: 20, resetsAt: nil, resetPassed: false))
        let alternative = account("codex:second@example.com", remaining: 50)
        let report = try object(AgentCLI.report(snapshot([shared, alternative]), command: "recommend", now: now))
        let recommendations = try XCTUnwrap(report["recommendations"] as? [[String: Any]])
        XCTAssertEqual(recommendations.count, 1)
        XCTAssertEqual(recommendations[0]["minimumRemainingPercent"] as? Double, 50)
        let rows = try XCTUnwrap(report["accounts"] as? [[String: Any]])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.first?["minimumRemainingPercent"] as? Double, 20)
    }
    func testProvidersAreSeparateOptionsAndMachineFilterDoesNotFabricateRoutes() throws {
        let report = try object(AgentCLI.report(snapshot([account(), account("claude:person@example.com", provider: "Claude", remaining: 90)]), command: "recommend", now: now))
        XCTAssertEqual((report["recommendations"] as? [[String: Any]])?.count, 2)
        XCTAssertEqual(AgentCLI.report(snapshot([account()]), command: "recommend", machine: "mac-2", now: now).code, 64)
    }
    func testOptInDefaultsOffAndRevocationTakesEffectImmediatelyWithoutWriting() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let folder = home.appendingPathComponent("Library/Application Support/UsageBoard/App")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let prefs = folder.appendingPathComponent("preferences.json"), snap = folder.appendingPathComponent("overview.json")
        let oldBytes = Data(#"{"nativeCollection":true}"#.utf8)
        try oldBytes.write(to: prefs); try JSONEncoder().encode(snapshot([account()])).write(to: snap)
        XCTAssertEqual(AgentCLI.run(["status"], home: home, now: now).code, 77)
        XCTAssertEqual(try Data(contentsOf: prefs), oldBytes)
        var preferences = BoardPreferences(); preferences.agentAccess = true
        try JSONEncoder().encode(preferences).write(to: prefs)
        let before = try Data(contentsOf: snap)
        XCTAssertEqual(AgentCLI.run(["recommend"], home: home, now: now).code, 0)
        XCTAssertEqual(try Data(contentsOf: snap), before)
        preferences.agentAccess = false; try JSONEncoder().encode(preferences).write(to: prefs)
        XCTAssertEqual(AgentCLI.run(["status"], home: home, now: now).code, 77)
    }
    func testArgumentErrorsDoNotEchoInputOrReadData() {
        for args in [["execute"], ["recommend", "--minimum-remaining", "nan"], ["recommend", "--minimum-remaining", "101"],
                     ["status", "--provider", "PRIVATE_INPUT"], ["status", "--machine", "PRIVATE_INPUT"],
                     ["status", "--provider"], ["status", "--provider", "Claude", "--provider", "Codex"]] {
            let result = AgentCLI.run(args)
            XCTAssertEqual(result.code, 64)
            XCTAssertFalse(String(decoding: result.data, as: UTF8.self).contains("PRIVATE_INPUT"))
        }
    }
    func testMissingMalformedAndSymlinkSnapshotsFailClosedAndRespectGuiSource() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let folder = home.appendingPathComponent("Library/Application Support/UsageBoard/App")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var prefs = BoardPreferences(); prefs.agentAccess = true
        try JSONEncoder().encode(prefs).write(to: folder.appendingPathComponent("preferences.json"))
        XCTAssertEqual(AgentCLI.run(["status"], home: home, now: now).code, 66)
        let snap = folder.appendingPathComponent("overview.json")
        try Data("broken".utf8).write(to: snap)
        XCTAssertEqual(AgentCLI.run(["status"], home: home, now: now).code, 65)
        try FileManager.default.removeItem(at: snap)
        let actual = home.appendingPathComponent("actual.json")
        try JSONEncoder().encode(snapshot([account()])).write(to: actual)
        try FileManager.default.createSymbolicLink(at: snap, withDestinationURL: actual)
        XCTAssertEqual(AgentCLI.run(["status"], home: home, now: now).code, 65)
        let legacy = home.appendingPathComponent("usage_board/state")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: home.appendingPathComponent("usage_board/config.local.json"))
        try JSONEncoder().encode(snapshot([account()])).write(to: legacy.appendingPathComponent("overview.json"))
        XCTAssertEqual(AgentCLI.run(["status"], home: home, now: now).code, 0)
    }
}
