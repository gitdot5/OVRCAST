import XCTest
@testable import CodexBarCore

final class ClaudeQuotaTests: XCTestCase {
    func testWeeklyOnlyPlanDoesNotInventASessionLimit() throws {
        let parsed = try ClaudeStatusProbe.parse(text: """
        Settings  Status  Config  Usage  Stats
        Current week (all models)
        37% used
        Resets Sun at 5am (UTC)
        Current week (Fable)
        9% used
        Resets Sun at 5am (UTC)
        Session
        Estimated cost: $0.0000
        Usage: 0 input, 0 output
        """)
        XCTAssertNil(parsed.sessionPercentLeft)
        XCTAssertEqual(parsed.weeklyPercentLeft, 63)
        let snapshot = try ClaudeUsageFetcher.makeSnapshot(from: parsed)
        XCTAssertNil(snapshot.primary)
        XCTAssertEqual(snapshot.secondary?.remainingPercent, 63)
        XCTAssertEqual(snapshot.secondary?.windowMinutes, 7 * 24 * 60)
        XCTAssertEqual(snapshot.extraRateWindows.first?.window.remainingPercent, 91)
    }

    func testSessionAndWeeklyValuesStayWithTheirLabels() throws {
        let parsed = try ClaudeStatusProbe.parse(text: """
        Current session
        17% used
        Current week (all models)
        59% used
        Current week (Fable)
        88% used
        """)
        let snapshot = try ClaudeUsageFetcher.makeSnapshot(from: parsed)
        XCTAssertEqual(snapshot.primary?.remainingPercent, 83)
        XCTAssertEqual(snapshot.primary?.windowMinutes, 5 * 60)
        XCTAssertEqual(snapshot.secondary?.remainingPercent, 41)
        XCTAssertEqual(snapshot.extraRateWindows.first?.window.remainingPercent, 12)
    }

    func testSessionOnlyPlanKeepsWeeklyUnknown() throws {
        let parsed = try ClaudeStatusProbe.parse(text: "Current session\n17% used")
        let snapshot = try ClaudeUsageFetcher.makeSnapshot(from: parsed)
        XCTAssertEqual(snapshot.primary?.remainingPercent, 83)
        XCTAssertNil(snapshot.secondary)
    }

    func testModelOnlyQuotaDoesNotInventSharedLimits() throws {
        let parsed = try ClaudeStatusProbe.parse(text: "Current week (Fable)\n23% used")
        let snapshot = try ClaudeUsageFetcher.makeSnapshot(from: parsed)
        XCTAssertNil(snapshot.primary); XCTAssertNil(snapshot.secondary)
        XCTAssertEqual(snapshot.extraRateWindows.first?.window.remainingPercent, 77)
    }

    func testLoadingSessionCannotBorrowAWeeklyPercentage() {
        assertLoading("Current session\nLoading…\nCurrent week (all models)\n11% used")
    }

    func testLoadingWeeklyCannotBorrowAScopedPercentage() {
        assertLoading("Current session\n17% used\nCurrent week (all models)\nLoading…\nCurrent week (Fable)\n23% used")
    }

    func testLoadingScopedWindowCannotBeDroppedFromAnOtherwiseCurrentReading() {
        assertLoading("Current week (all models)\n11% used\nCurrent week (Fable)\nLoading…")
    }

    func testLoadingQuotaCannotBorrowAUsageCreditPercentage() {
        assertLoading("Current week (all models)\nLoading…\nUsage credits\n0% used")
        assertLoading("Current week (Fable)\nLoading…\nUsage credits\n20% used")
    }

    func testSessionStatisticsAndContextMetersAreNotQuotaData() {
        XCTAssertThrowsError(try ClaudeStatusProbe.parse(text: "Session\nEstimated cost: $0.0000\nContext window: 0% used"))
    }

    func testCaptureCompletesForWeeklyOnlyAndKeepsUnrelatedPercentagesOut() {
        XCTAssertTrue(ClaudeStatusProbe.usageCaptureHasQuotaValue("currentweek(allmodels)11%usedcurrentweek(fable)4%used"))
        XCTAssertTrue(ClaudeStatusProbe.usageCaptureHasQuotaValue("currentsession17%usedcurrentweek(allmodels)59%used"))
        XCTAssertFalse(ClaudeStatusProbe.usageCaptureHasQuotaValue("currentsessionloadingcurrentweek(allmodels)11%used"))
        XCTAssertFalse(ClaudeStatusProbe.usageCaptureHasQuotaValue("currentweek(allmodels)loadingusagecredits0%used"))
        XCTAssertFalse(ClaudeStatusProbe.usageCaptureHasQuotaValue("sessionestimatedcost:0%used"))
    }

    private func assertLoading(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try ClaudeStatusProbe.parse(text: text), file: file, line: line) { error in
            XCTAssertTrue(ClaudeUsageFetcher.isRetryableCLIProbeError(error), file: file, line: line)
        }
    }
}
