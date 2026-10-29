import XCTest
@testable import UsageBoardMenuBar

final class ReleaseFeaturesTests: XCTestCase {
    func row(_ remaining: Double = 80, id: String = "one", fresh: Bool = true, stamp: Date = Date(), reset: Date = Date().addingTimeInterval(3600)) -> UsageAccount {
        UsageAccount(id: id, provider: "Codex", email: "person@example.com", plan: "Example", machines: ["MacBook"], severity: "good", status: "Available",
                     fresh: fresh, observedAt: ISO8601DateFormatter().string(from: stamp), source: "fixture", issue: "", quotas: [Quota(label: "Weekly", remaining: remaining,
                         resetsAt: ISO8601DateFormatter().string(from: reset), resetPassed: false)], resetDetails: [], credits: [])
    }
    func testRecommendationRejectsStaleExhaustedSignedOutAndFutureReadings() {
        var signedOut = row(99, id: "signed-out"); signedOut.requiresSignIn = true
        let accounts = [row(100, id: "stale", fresh: false), row(0, id: "empty"), signedOut,
                        row(100, id: "future", stamp: Date().addingTimeInterval(900)), row(45, id: "usable")]
        XCTAssertEqual(Insights.recommend(accounts, provider: "Codex")?.account.id, "usable")
        XCTAssertNil(Insights.recommend(accounts, provider: "Claude"))
    }
    func testRecommendationHonorsSharedLimitWhenChoosingModel() {
        var a = row(8)
        a.quotas.append(Quota(label: "Model A", remaining: 99, resetPassed: false))
        a.quotas.append(Quota(label: "Model B", remaining: 0, resetPassed: false))
        XCTAssertEqual(Insights.recommend([a], provider: "Codex", window: "Model A")?.remaining, 8)
        XCTAssertNil(Insights.recommend([a], provider: "Codex"))
        XCTAssertNil(Insights.recommend([a], provider: "Codex", window: "Unknown model"))
    }
    func testUnrecognizedSharedConstraintStillLimitsRecommendation() {
        var account = row(90)
        account.quotas.append(Quota(label: "Rolling allowance", remaining: 0, resetPassed: false))
        account.quotas.append(Quota(label: "Model A", remaining: 80, resetPassed: false))
        XCTAssertNil(Insights.recommend([account], provider: "Codex", window: "Model A"))
    }
    func testDuplicateAccountAcrossMachinesKeepsOneQuotaAndNewestReading() {
        let a = row(40, stamp: Date().addingTimeInterval(-60))
        var b = row(30); b.machines = ["Mini"]
        let result = NativeCollector.merge([a, b])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].quotas[0].remaining, 30)
        XCTAssertEqual(result[0].machines, ["MacBook", "Mini"])
    }
    func testNativeParserPreservesZeroAndRejectsMalformedQuota() throws {
        let json = """
        [{"provider":"codex","credits":{"remaining":0,"balanceReadSucceeded":true},"usage":{"accountEmail":"person@example.com","updatedAt":"2026-10-27T12:00:00Z",
        "primary":{"usedPercent":false},"secondary":{"usedPercent":0},"tertiary":{"usedPercent":101}}}]
        """
        let a = try NativeCollector.parse(Data(json.utf8), provider: "Codex", machine: "This Mac")[0]
        XCTAssertEqual(a.quotas.count, 1)
        XCTAssertEqual(a.quotas[0].remaining, 100)
        XCTAssertEqual(a.credits[0].value, "0.00 credits")
        XCTAssertNil(a.savedResets)
    }
    func testPayloadWithCredentialIsRejectedBeforeParsing() {
        let token = "sk-ant-" + String(repeating: "X", count: 25)
        XCTAssertFalse(NativeCollector.safePayload(Data("{\"unexpected\":\"\(token)\"}".utf8)))
        XCTAssertThrowsError(try NativeCollector.parse(Data("[]".utf8), provider: "Codex", machine: "This Mac"))
    }
    func testMissingTimestampDoesNotBecomeFresh() throws {
        let json = #"[{"usage":{"primary":{"usedPercent":10}}}]"#
        let a = try NativeCollector.parse(Data(json.utf8), provider: "Claude", machine: "This Mac")[0]
        XCTAssertFalse(a.current)
        XCTAssertFalse(a.available)
        XCTAssertNil(Insights.recommend([a], provider: "Claude"))
    }
    func testLowAlertIsATransitionAndDuplicateReadingsDoNotAlert() {
        let old = row(20, stamp: Date().addingTimeInterval(-60)), new = row(10)
        XCTAssertEqual(AlertRules.changes(from: [old], to: [new], threshold: 15).count, 1)
        XCTAssertTrue(AlertRules.changes(from: [new], to: [new], threshold: 15).isEmpty)
        var stale = new; stale.fresh = false
        XCTAssertTrue(AlertRules.changes(from: [old], to: [stale], threshold: 15).isEmpty)
    }
    func testResetNeedsNewReadingNewWindowAndRestoredCapacity() {
        let now = Date()
        let old = row(1, stamp: now.addingTimeInterval(-120), reset: now.addingTimeInterval(-60))
        let new = row(100, stamp: now, reset: now.addingTimeInterval(3600))
        XCTAssertEqual(AlertRules.changes(from: [old], to: [new], threshold: 15).first?.title, "Codex allowance refreshed")
        XCTAssertTrue(AlertRules.changes(from: [old], to: [old], threshold: 15).isEmpty)
    }
    func testCreditExpiryRequiresPositiveBalanceAndExplicitUpcomingDate() {
        var account = row()
        let expiry = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        account.credits = [CreditPool(name: "Cloud credits", value: "$5.00", detail: "Reported", expiresAt: expiry)]
        XCTAssertEqual(AlertRules.changes(from: [], to: [account], threshold: 15).count, 1)
        account.credits[0].value = "0"
        XCTAssertTrue(AlertRules.changes(from: [], to: [account], threshold: 15).isEmpty)
        account.credits[0].value = "Unknown"
        XCTAssertTrue(AlertRules.changes(from: [], to: [account], threshold: 15).isEmpty)
        account.credits[0].value = "$5.00"; account.credits[0].expiresAt = nil
        XCTAssertTrue(AlertRules.changes(from: [], to: [account], threshold: 15).isEmpty)
    }
    func testQuietHoursAcrossMidnight() {
        XCTAssertTrue(AlertRules.quiet(hour: 23, start: 22, end: 8))
        XCTAssertTrue(AlertRules.quiet(hour: 7, start: 22, end: 8))
        XCTAssertFalse(AlertRules.quiet(hour: 8, start: 22, end: 8))
        XCTAssertFalse(AlertRules.quiet(hour: 23, start: 8, end: 8))
    }
    func testHistoryDeduplicatesObservationsAndDoesNotInventReadings() {
        let account = row()
        let first = Insights.history([], accounts: [account])
        XCTAssertEqual(Insights.history(first, accounts: [account]).count, 1)
        XCTAssertEqual(Insights.history([], accounts: [row(fresh: false)]).count, 0)
        var expired = first[0]; expired.date = Date().addingTimeInterval(-8 * 86400)
        XCTAssertTrue(Insights.history([expired], accounts: []).isEmpty)
    }
    func testSupportReportOmitsIdentifiersAndRawErrorText() {
        var account = row(); account.issue = "private diagnostic"; account.status = "private status"; account.provider = "private provider"
        let text = Insights.supportReport([account], native: true, helperAvailable: true)
        for privateValue in [account.email, "MacBook", "private", "Example"] { XCTAssertFalse(text.contains(privateValue)) }
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(text.utf8)))
    }
    func testSSHOnlyAcceptsPlainAliases() {
        for value in ["-oProxyCommand=bad", "host;touch", "user@host", "$(x)", "host name"] {
            XCTAssertFalse(RemoteMachine(name: "Remote", sshAlias: value).valid)
        }
        XCTAssertTrue(RemoteMachine(name: "Remote", sshAlias: "my-mac-mini").valid)
    }
    func testPrivateFilesStayOwnerOnlyAfterReplacement() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("settings.json")
        try PrivateFiles.write(["value": 1], to: url)
        try PrivateFiles.write(["value": 2], to: url)
        XCTAssertEqual(PrivateFiles.read([String: Int].self, from: url)?["value"], 2)
        let mode = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(mode, 0o600)
    }
    @MainActor func testFreshInstallHasNoDevelopmentFolderDependencyAndPrivacyHidesAliases() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = UsageStore(defaults: defaults, root: folder.appendingPathComponent("no-source"), dataDirectory: folder.appendingPathComponent("data"), demo: false)
        XCTAssertTrue(store.nativeMode)
        XCTAssertFalse(store.preferences.setupComplete)
        let account = row()
        store.accounts = [account]
        store.preferences.aliases[account.id] = "Private alias"
        store.preferences.privacyMode = true
        XCTAssertEqual(store.accountName(account), "Account 1")
        XCTAssertEqual(store.machineName("MacBook"), "MacBook")
    }
}
