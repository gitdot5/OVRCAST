import XCTest
@testable import UsageBoardMenuBar

final class SnapshotValidationTests: XCTestCase {
    func testValidDemoPassesAndExtremePercentagesAreRejected() throws {
        var snapshot = DemoData.snapshot()
        XCTAssertTrue(SnapshotValidation.valid(snapshot))
        snapshot.accounts[0].quotas[0].remaining = 1e300
        XCTAssertThrowsError(try SnapshotValidation.decode(JSONEncoder().encode(snapshot)))
        snapshot.accounts[0].quotas[0].remaining = -1
        XCTAssertFalse(SnapshotValidation.valid(snapshot))
    }
    func testDuplicateIdentityAndOverflowingResetTotalsAreRejected() {
        var snapshot = DemoData.snapshot()
        snapshot.accounts.append(snapshot.accounts[0])
        XCTAssertFalse(SnapshotValidation.valid(snapshot))
        snapshot = DemoData.snapshot()
        snapshot.accounts[0].savedResets = Int.max
        XCTAssertFalse(SnapshotValidation.valid(snapshot))
    }
    func testOversizedAndCredentialPayloadsAreRejected() {
        XCTAssertThrowsError(try SnapshotValidation.decode(Data(repeating: 32, count: 4_000_001)))
        var snapshot = DemoData.snapshot()
        snapshot.accounts[0].issue = "Bearer " + String(repeating: "x", count: 25)
        XCTAssertThrowsError(try SnapshotValidation.decode(JSONEncoder().encode(snapshot)))
    }
}
