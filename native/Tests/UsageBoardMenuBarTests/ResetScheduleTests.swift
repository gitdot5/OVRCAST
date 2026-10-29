import XCTest
@testable import UsageBoardMenuBar

final class ResetScheduleTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func account(_ quotas: [Quota], fresh: Bool = true, observed: Date? = nil) -> UsageAccount {
        UsageAccount(id: "fixture", provider: "Codex", email: "example@example.invalid", plan: "Test", machines: ["Mini"],
                     severity: "good", status: "Available", fresh: fresh,
                     observedAt: ISO8601DateFormatter().string(from: observed ?? now), source: "Test", issue: "",
                     quotas: quotas, resetDetails: [], credits: [])
    }
    func quota(_ label: String, _ offset: Double, passed: Bool = false) -> Quota {
        Quota(label: label, remaining: 50, resetsAt: ISO8601DateFormatter().string(from: now.addingTimeInterval(offset)), resetPassed: passed)
    }
    func testEarliestReportedWindowIsSelected() {
        let row = account([quota("Weekly", 86400), quota("Session", 3600), quota("Model", 7200)])
        XCTAssertEqual(ResetSchedule.next(for: row, now: now), .scheduled(window: "Session", date: now.addingTimeInterval(3600)))
    }
    func testUnknownOrMalformedTimesStayUnavailable() {
        let q = Quota(label: "Weekly", remaining: 50, resetsAt: "invalid", resetPassed: false)
        XCTAssertEqual(ResetSchedule.next(for: account([q]), now: now), .unavailable)
        XCTAssertEqual(ResetSchedule.next(for: account([]), now: now), .unavailable)
    }
    func testPassedTimeDoesNotClaimRefilledAllowance() {
        XCTAssertEqual(ResetSchedule.next(for: account([quota("Session", -1), quota("Weekly", 86400)]), now: now), .awaitingReading)
        XCTAssertEqual(ResetSchedule.next(for: account([quota("Session", 3600, passed: true)]), now: now), .awaitingReading)
    }
    func testStaleOrFailedReadingsDoNotAdvertiseReset() {
        XCTAssertEqual(ResetSchedule.next(for: account([quota("Session", 3600)], fresh: false), now: now), .stale)
        XCTAssertEqual(ResetSchedule.next(for: account([quota("Session", 3600)], observed: now.addingTimeInterval(-601)), now: now), .stale)
    }
    func testSignInRequiredDoesNotAdvertiseReset() {
        var row = account([quota("Session", 3600)]); row.requiresSignIn = true
        XCTAssertEqual(ResetSchedule.next(for: row, now: now), .unavailable)
    }
    func testFutureUnderOneMinuteIsNotPending() {
        XCTAssertEqual(resetCountdown(until: now.addingTimeInterval(20), now: now), "in 1m")
        XCTAssertEqual(resetCountdown(until: now, now: now), "Awaiting new reading")
        XCTAssertEqual(resetCountdown(until: now.addingTimeInterval(7260), now: now), "in 2h 1m")
    }
    func testExactTimeUsesSelectedTimeZoneAcrossDayBoundary() {
        let date = parsedDate("2026-10-30T00:30:00Z")!
        let local = resetLocalTime(date, timeZone: TimeZone(identifier: "America/New_York")!, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(local.contains("Oct 29")); XCTAssertTrue(local.contains("8:30")); XCTAssertTrue(local.contains("EDT"))
    }
}
