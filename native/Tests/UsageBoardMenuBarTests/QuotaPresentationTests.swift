import XCTest
@testable import UsageBoardMenuBar

final class QuotaPresentationTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func testOldResetDoesNotEraseTheHistoricalBar() {
        for passed in [false, true] {
            let quota = Quota(label: "Session", remaining: 87,
                              resetsAt: ISO8601DateFormatter().string(from: now.addingTimeInterval(-60)), resetPassed: passed)
            let display = QuotaPresentation(quota, current: false, now: now)
            XCTAssertEqual(display.state, .lastKnown)
            XCTAssertEqual(display.fraction, 0.87, accuracy: 0.0001)
            XCTAssertEqual(display.value, "87% left")
            XCTAssertTrue(display.accessibilityValue.contains("last known"))
        }
    }
    func testCurrentExpiredWindowCannotLookLikeAConfirmedRefill() {
        for passed in [false, true] {
            let quota = Quota(label: "Session", remaining: 87,
                              resetsAt: ISO8601DateFormatter().string(from: now.addingTimeInterval(passed ? 60 : -60)), resetPassed: passed)
            let display = QuotaPresentation(quota, current: true, now: now)
            XCTAssertEqual(display.state, .resetPending)
            XCTAssertEqual(display.fraction, 0)
            XCTAssertEqual(display.value, "Pending")
        }
    }
    func testMissingResetDoesNotEraseKnownQuotaAndInvalidNumbersStayUnavailable() {
        let quota = Quota(label: "Weekly", remaining: 50, resetsAt: nil, resetPassed: false)
        XCTAssertEqual(QuotaPresentation(quota, current: true, now: now).fraction, 0.5)
        var invalid = quota; invalid.remaining = .nan
        XCTAssertEqual(QuotaPresentation(invalid, current: true, now: now).value, "Unavailable")
    }
}
