import XCTest
@testable import UsageBoardMenuBar

final class ProviderContractTests: XCTestCase {
    struct Fixture: Decodable {
        var name: String
        var provider: String
        var remaining: [Double]
        var state: ConnectionState
        var signIn: Bool
    }
    func fixtures() throws -> [(Fixture, Data)] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "provider-contracts", withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        let metadata = try JSONDecoder().decode([Fixture].self, from: data)
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let formatter = ISO8601DateFormatter()
        return try zip(metadata, objects).map { fixture, object in
            var text = String(decoding: try JSONSerialization.data(withJSONObject: object["response"]!), as: UTF8.self)
            text = text.replacingOccurrences(of: "NOW", with: formatter.string(from: Date()))
                .replacingOccurrences(of: "FUTURE", with: formatter.string(from: Date().addingTimeInterval(3600)))
            return (fixture, Data(text.utf8))
        }
    }
    func testProviderResponsesPreserveMeaningAcrossAdapters() throws {
        for (fixture, data) in try fixtures() {
            let rows = try NativeCollector.parse(data, provider: fixture.provider, machine: "Fixture Mac")
            XCTAssertEqual(rows.flatMap(\.quotas).map(\.remaining), fixture.remaining, fixture.name)
            XCTAssertEqual(rows.first?.requiresSignIn, fixture.signIn, fixture.name)
            XCTAssertEqual(ConnectionHealth.classify(rows), fixture.state, fixture.name)
            if fixture.remaining.isEmpty { XCTAssertFalse(rows.contains(where: \.available), fixture.name) }
        }
    }
    func testFailuresDoNotSilentlyRetryWithDifferentCredentialsOrSources() throws {
        for (fixture, data) in try fixtures() where fixture.remaining.isEmpty {
            var calls = 0
            _ = NativeCollector.collect(provider: fixture.provider, machine: "Fixture Mac", helper: "/fixture") { _,_ in
                calls += 1; return CommandOutput(data: data, code: 1)
            }
            XCTAssertEqual(calls, 1, fixture.name)
        }
    }
    func testUnreadableClaudeConnectionGivesActionableSanitizedHelp() throws {
        let (_, data) = try XCTUnwrap(fixtures().first { $0.0.name == "claude-unreadable-connection" })
        let row = try XCTUnwrap(NativeCollector.parse(data, provider: "Claude", machine: "Fixture Mac").first)
        XCTAssertTrue(row.issue.contains("Connect Claude")); XCTAssertTrue(row.issue.contains("not deleted or replaced"))
        XCTAssertTrue(row.quotas.isEmpty)
    }
    func testUnexpectedCredentialEchoIsRejectedRatherThanStoredAsAnError() throws {
        let dummy = "sk-" + String(repeating: "A", count: 32)
        let data = try JSONSerialization.data(withJSONObject: [["error": ["kind": "provider", "message": dummy]]])
        XCTAssertThrowsError(try NativeCollector.parse(data, provider: "Claude", machine: "Fixture Mac"))
        let rows = NativeCollector.collect(provider: "Claude", machine: "Fixture Mac", helper: "/fixture") { _,_ in CommandOutput(data: data, code: 1) }
        XCTAssertFalse(rows[0].issue.contains(dummy)); XCTAssertTrue(rows[0].quotas.isEmpty)
    }
    func testLocalAccessAndRateLimitsDoNotAskForNewSignInEvenWithBroadErrorKind() throws {
        for message in ["Claude Keychain access was denied.", "HTTP 429: too many requests."] {
            let data = try JSONSerialization.data(withJSONObject: [["error": ["kind": "authentication", "message": message]]])
            let rows = try NativeCollector.parse(data, provider: "Claude", machine: "Fixture Mac")
            XCTAssertEqual(rows[0].requiresSignIn, false)
            XCTAssertNotEqual(ConnectionHealth.classify(rows), .signInRequired)
        }
    }
}
