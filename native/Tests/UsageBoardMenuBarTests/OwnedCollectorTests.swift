import XCTest
@testable import UsageBoardMenuBar

final class OwnedCollectorTests: XCTestCase {
    func testOnlyTheExecutableInsideTheSuppliedAppIsResolved() throws {
        let app = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".app")
        defer { try? FileManager.default.removeItem(at: app) }
        XCTAssertNil(NativeCollector.bundledHelper(in: app))
        let helper = app.appendingPathComponent("Contents/Helpers/OVRCASTCollector")
        try FileManager.default.createDirectory(at: helper.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: helper)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: helper.path)
        XCTAssertNil(NativeCollector.bundledHelper(in: app))
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
        XCTAssertEqual(NativeCollector.bundledHelper(in: app), helper.path)
    }
    func testLoginScriptPreservesLiteralShellMetacharacters() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let executable = folder.appendingPathComponent("provider ' $(touch injected) `echo nope`")
        // The fixture prints its arguments; it never contacts a provider or signs in.
        try Data("#!/bin/sh\nprintf '%s\\n' \"$@\"\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let pipe = Pipe(), process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", ProviderConnection.claudeLoginScript(executable: executable.path)]
        process.currentDirectoryURL = folder; process.standardOutput = pipe
        try process.run(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8), "auth\nlogin\n")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("injected").path))
    }
}
