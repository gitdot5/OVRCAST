import XCTest
@testable import UsageBoardMenuBar

final class CollectorIntegrationTests: XCTestCase {
    let usage = Data(#"[{"usage":{"accountEmail":"test@example.invalid","updatedAt":"2026-10-29T16:00:00Z","primary":{"usedPercent":20,"resetsAt":"2026-10-29T18:00:00Z"}}}]"#.utf8)
    func noAccounts(_ provider: String) -> Data {
        Data("[{\"error\":{\"kind\":\"provider\",\"message\":\"No token accounts configured for \(provider).\"}}]".utf8)
    }
    func testDefaultAntigravityConnectionWorksWithoutTokenAccounts() {
        var calls: [[String]] = []
        let rows = NativeCollector.collect(provider: "Antigravity", machine: "Test", helper: "/test/helper") { _, args in
            calls.append(args)
            return CommandOutput(data: calls.count == 1 ? self.noAccounts("antigravity") : self.usage, code: calls.count == 1 ? 1 : 0)
        }
        XCTAssertEqual(calls.count, 2)
        XCTAssertTrue(calls[0].contains("--all-accounts")); XCTAssertFalse(calls[1].contains("--all-accounts"))
        XCTAssertFalse(calls[1].contains("--source"))
        XCTAssertEqual(rows.first?.quotas.first?.remaining, 80)
    }
    func testClaudeUsesSupportedOAuthSourceAndDefaultFallback() {
        var calls: [[String]] = []
        let rows = NativeCollector.collect(provider: "Claude", machine: "Test", helper: "/test/helper") { _, args in
            calls.append(args)
            return CommandOutput(data: calls.count == 1 ? self.noAccounts("claude") : self.usage, code: 0)
        }
        XCTAssertEqual(calls.count, 2)
        XCTAssertTrue(calls.allSatisfy { $0.contains("oauth") && !$0.contains("cli") })
        XCTAssertEqual(rows.count, 1)
    }
    func testSuccessfulMultiAccountReadingDoesNotFallback() {
        var count = 0
        let rows = NativeCollector.collect(provider: "Codex", machine: "Test", helper: "/test/helper") { _, args in
            count += 1; XCTAssertTrue(args.contains("cli")); XCTAssertTrue(args.contains("--all-accounts"))
            return CommandOutput(data: self.usage, code: 0)
        }
        XCTAssertEqual(count, 1); XCTAssertEqual(rows.first?.quotas.count, 1)
    }
    func testMissingOAuthCredentialsAreSignInRequiredWithoutRetryLoop() {
        var count = 0
        let data = Data(#"[{"error":{"kind":"provider","message":"Claude OAuth credentials not found. Run `claude` to authenticate."}}]"#.utf8)
        let rows = NativeCollector.collect(provider: "Claude", machine: "Test", helper: "/test/helper") { _, _ in
            count += 1; return CommandOutput(data: data, code: 1)
        }
        XCTAssertEqual(count, 1); XCTAssertEqual(rows.first?.requiresSignIn, true)
        XCTAssertTrue(rows.first?.quotas.isEmpty == true)
    }
    func testFallbackOnlyAcceptsTheExactNoConfiguredAccountsError() {
        XCTAssertFalse(NativeCollector.defaultAccountFallback(noAccounts("claude"), provider: "Codex"))
        XCTAssertFalse(NativeCollector.defaultAccountFallback(Data("[]".utf8), provider: "Claude"))
        XCTAssertFalse(NativeCollector.defaultAccountFallback(Data("invalid".utf8), provider: "Claude"))
        XCTAssertFalse(NativeCollector.defaultAccountFallback(usage, provider: "Claude"))
    }
    @MainActor func testWindowPreferencesUseTheInjectedStore() throws {
        let a = "OVRCAST-window-test-\(UUID().uuidString)", b = "OVRCAST-window-test-\(UUID().uuidString)"
        let first = try XCTUnwrap(UserDefaults(suiteName: a)), second = try XCTUnwrap(UserDefaults(suiteName: b))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { first.removePersistentDomain(forName: a); second.removePersistentDomain(forName: b); try? FileManager.default.removeItem(at: folder) }
        let one = UsageStore(defaults: first, root: folder, dataDirectory: folder.appendingPathComponent("one"), demo: false)
        let two = UsageStore(defaults: second, root: folder, dataDirectory: folder.appendingPathComponent("two"), demo: false)
        one.floatingBoard = true
        XCTAssertTrue(one.floatingBoard); XCTAssertFalse(two.floatingBoard)
        XCTAssertTrue(UsageStore(defaults: first, root: folder, dataDirectory: folder.appendingPathComponent("one"), demo: false).floatingBoard)
    }
}
