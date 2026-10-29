import XCTest
@testable import UsageBoardMenuBar

final class MachineLabelsTests: XCTestCase {
    func testPrivacyShowsDistinctMacTypesInsteadOfNumberedMacs() {
        let names = ["MacBook", "Mini", "Studio"]
        XCTAssertEqual(names.map { MachineLabels.label($0, machines: names, privacy: true) }, ["MacBook", "Mac mini", "Mac Studio"])
    }
    func testPrivacyHidesCustomNamesAndDisambiguatesTheSameType() {
        let names = ["Office MacBook Pro", "Home MacBook Pro", "Private name"]
        XCTAssertEqual(MachineLabels.label(names[0], machines: names, privacy: true), "MacBook Pro 2")
        XCTAssertEqual(MachineLabels.label(names[1], machines: names, privacy: true), "MacBook Pro 1")
        XCTAssertEqual(MachineLabels.label(names[2], machines: names, privacy: true), "Mac")
        XCTAssertEqual(MachineLabels.label(names[0], machines: names, privacy: false), names[0])
        XCTAssertEqual(MachineLabels.label("MacBook 2", machines: ["MacBook 2"], privacy: false), "MacBook 2")
    }
    func testLocalHardwareFamilyDoesNotGuessTheRemoteType() {
        XCTAssertEqual(MachineLabels.label("This Mac", machines: ["This Mac", "Remote"], privacy: true, localMachine: "This Mac", localFamily: "MacBook Pro"), "MacBook Pro")
        XCTAssertEqual(MachineLabels.label("Remote", machines: ["This Mac", "Remote"], privacy: true, localMachine: "This Mac", localFamily: "MacBook Pro"), "Mac")
        XCTAssertEqual(MachineLabels.label("Mini", machines: ["Mini"], privacy: false), "Mac mini")
    }
    func testHardwareReportKeepsOnlyTheRecognizedFamily() {
        let data = Data(#"{"SPHardwareDataType":[{"machine_name":"MacBook Pro","serial_number":"private-hardware-value"}]}"#.utf8)
        XCTAssertEqual(MachineLabels.hardwareFamily(data), "MacBook Pro")
        XCTAssertNil(MachineLabels.hardwareFamily(Data("invalid".utf8)))
        XCTAssertNil(MachineLabels.hardwareFamily(Data(#"{"SPHardwareDataType":[{"machine_name":"Unrecognized"}]}"#.utf8)))
    }
    func testSymbolsMatchVisibleHardwareFamilies() {
        XCTAssertEqual(MachineLabels.symbol("MacBook Pro 2"), "laptopcomputer")
        XCTAssertEqual(MachineLabels.symbol("Mac mini"), "macmini")
        XCTAssertEqual(MachineLabels.symbol("Mac Studio"), "macstudio")
    }
}
