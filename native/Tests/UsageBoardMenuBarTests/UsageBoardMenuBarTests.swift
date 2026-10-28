import XCTest
@testable import UsageBoardMenuBar

final class UsageBoardMenuBarTests: XCTestCase {
    func account(fresh: Bool = true, observed: Date = Date(), status: String = "Available", resets: String = "null") throws -> UsageAccount {
        let stamp = ISO8601DateFormatter().string(from: observed)
        let data = Data("""
        {"id":"test","provider":"Codex","email":"test@example.invalid","plan":"Test","machines":["Mini"],
        "severity":"good","status":"\(status)","fresh":\(fresh),"observedAt":"\(stamp)","source":"fixture","issue":"",
        "quotas":[{"label":"Weekly","remaining":80,"resetPassed":false}],"savedResets":\(resets),"resetDetails":[],"credits":[{"name":"Cloud credits","value":"Unknown","detail":"Not reported"}]}
        """.utf8)
        return try JSONDecoder().decode(UsageAccount.self, from: data)
    }
    func testUnknownResetsAreNotZero() throws { XCTAssertNil(try account().savedResets) }
    func testReportedZeroSurvivesDecoding() throws { XCTAssertEqual(try account(resets: "0").savedResets, 0) }
    func testOldReadingIsNeverRecommended() throws { XCTAssertFalse(try account(observed: Date().addingTimeInterval(-900)).available) }
    func testFailedReadingIsNeverRecommended() throws { XCTAssertFalse(try account(fresh: false).available) }
    func testUnknownBalanceKeepsItsLabel() throws { XCTAssertEqual(try account().credits.first?.value, "Unknown") }
    func testFreshAccountAvailable() throws { XCTAssertTrue(try account().available) }
    func testDatesWithFractionalSecondsParse() { XCTAssertNotNil(parsedDate("2026-10-27T12:00:00.123Z")) }
}
