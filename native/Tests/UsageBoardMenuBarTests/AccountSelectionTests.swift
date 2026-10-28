import XCTest
@testable import UsageBoardMenuBar

final class AccountSelectionTests: XCTestCase {
    func row(_ id: String, machine: String, remaining: Double = 80, fresh: Bool = true) throws -> UsageAccount {
        let data = Data("""
        {"id":"\(id)","provider":"Codex","email":"test@example.invalid","plan":"Test","machines":["\(machine)"],
        "severity":"good","status":"Available","fresh":\(fresh),"observedAt":"\(ISO8601DateFormatter().string(from: Date()))",
        "source":"fixture","issue":"","quotas":[{"label":"Weekly","remaining":\(remaining),"resetsAt":null,"resetPassed":false}],
        "savedResets":null,"resetDetails":[],"credits":[]}
        """.utf8)
        return try JSONDecoder().decode(UsageAccount.self, from: data)
    }
    func testMachineFilterDoesNotCountRetiredDevices() throws {
        var shared = try row("shared", machine: "Studio")
        shared.machines += ["Windows PC (retired)"]
        let rows = [shared, try row("mini", machine: "Mini")]
        XCTAssertEqual(AccountList.apply(rows, machine: "Studio").map(\.id), ["shared"])
        XCTAssertEqual(AccountList.machines(rows), ["Mini", "Studio"])
    }
    func testProviderAndMachineFiltersCombine() throws {
        var claude = try row("claude", machine: "Mini"); claude.provider = "Claude"
        let rows = [claude, try row("codex", machine: "Mini"), try row("studio", machine: "Studio")]
        XCTAssertEqual(AccountList.apply(rows, provider: "Claude", machine: "Mini").map(\.id), ["claude"])
    }
    func testUsageSortKeepsUnknownAndStaleAtBottomBothDirections() throws {
        var unknown = try row("unknown", machine: "Mini"); unknown.quotas = []
        let rows = [unknown, try row("stale", machine: "Studio", remaining: 100, fresh: false),
                    try row("zero", machine: "MacBook", remaining: 0), try row("high", machine: "Mini", remaining: 90)]
        XCTAssertEqual(AccountList.apply(rows, order: .mostLeft).map(\.id), ["high", "zero", "unknown", "stale"])
        XCTAssertEqual(AccountList.apply(rows, order: .leastLeft).map(\.id), ["zero", "high", "unknown", "stale"])
    }
    func testUsageSortUsesTheMostConstrainedModel() throws {
        var capped = try row("capped", machine: "Mini", remaining: 99)
        capped.quotas.append(Quota(label: "Model", remaining: 0, resetsAt: nil, resetPassed: false))
        let rows = [capped, try row("other", machine: "Studio", remaining: 40)]
        XCTAssertEqual(AccountList.apply(rows, order: .mostLeft).map(\.id), ["other", "capped"])
    }
    func testMachineOrderCanStartWithAnyMachine() throws {
        let rows = [try row("macbook", machine: "MacBook"), try row("mini", machine: "Mini"), try row("studio", machine: "Studio")]
        XCTAssertEqual(AccountList.apply(rows, order: .machine, firstMachine: "Studio").map(\.id), ["studio", "macbook", "mini"])
    }
    func testAttentionFilterKeepsUnreadableAccountsVisible() throws {
        let rows = [try row("ready", machine: "Mini"), try row("missing", machine: "Studio", fresh: false)]
        XCTAssertEqual(AccountList.apply(rows, status: .attention).map(\.id), ["missing"])
        XCTAssertEqual(AccountList.apply(rows, status: .available).map(\.id), ["ready"])
    }
    func testNextResetSortKeepsPendingLast() throws {
        var pending = try row("pending", machine: "Mini")
        pending.quotas[0].resetPassed = true
        var future = try row("future", machine: "Studio")
        future.quotas[0].resetsAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(300))
        XCTAssertEqual(AccountList.apply([pending, future], order: .nextReset).map(\.id), ["future", "pending"])
    }
    @MainActor func testPreferencesPersistAndReset() throws {
        let name = "UsageBoardFilterTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = UsageStore(defaults: defaults)
        store.machineFilter = "Studio"; store.accountOrder = .leastLeft; store.statusFilter = .available
        store.firstMachine = "Mini"
        let restored = UsageStore(defaults: defaults)
        XCTAssertEqual(restored.machineFilter, "Studio")
        XCTAssertEqual(restored.accountOrder, .leastLeft)
        XCTAssertEqual(restored.statusFilter, .available)
        XCTAssertEqual(restored.firstMachine, "Mini")
        restored.resetFilters()
        XCTAssertFalse(restored.filtersActive)
        XCTAssertEqual(UsageStore(defaults: defaults).machineFilter, "")
    }
}
