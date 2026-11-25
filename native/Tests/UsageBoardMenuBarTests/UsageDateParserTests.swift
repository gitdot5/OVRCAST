import XCTest
@testable import UsageBoardMenuBar

final class UsageDateParserTests: XCTestCase {
    func testProviderTimestampFormatsAndOffsetsRemainEquivalent() throws {
        let base = try XCTUnwrap(parsedDate("2026-11-06T15:30:00Z"))
        XCTAssertEqual(parsedDate("2026-11-06T10:30:00-05:00"), base)
        XCTAssertEqual(parsedDate("2026-11-06T15:30:00.000Z"), base)
        XCTAssertEqual(try XCTUnwrap(parsedDate("2026-11-06T15:30:00.125Z")).timeIntervalSince(base), 0.125, accuracy: 0.001)
        XCTAssertNil(parsedDate(nil)); XCTAssertNil(parsedDate("not a date")); XCTAssertNil(parsedDate(String(repeating: "x", count: 1000)))
    }
    func testConcurrentProviderReadsUseTheSameInstant() {
        let expected = parsedDate("2026-11-06T15:30:00Z")
        DispatchQueue.concurrentPerform(iterations: 200) { index in
            XCTAssertEqual(parsedDate(index.isMultiple(of: 2) ? "2026-11-06T10:30:00-05:00" : "2026-11-06T15:30:00Z"), expected)
        }
    }
    func testParsingDoesNotTurnAnOldObservationIntoCurrentUsage() {
        var account = DemoData.snapshot().accounts[0]
        account.observedAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        for _ in 0..<10 { _ = parsedDate(account.observedAt) }
        XCTAssertFalse(account.current); XCTAssertFalse(account.available)
    }
}
