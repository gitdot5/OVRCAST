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
        let profile = folder.appendingPathComponent("profile ' $(touch injected) `echo nope`").path
        // The fixture prints its arguments; it never contacts a provider or signs in.
        try Data("#!/bin/sh\nprintf '%s\\n' \"$CLAUDE_CONFIG_DIR\" \"$@\"\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let pipe = Pipe(), process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", ProviderConnection.claudeLoginScript(executable: executable.path, environment: ["CLAUDE_CONFIG_DIR": profile])]
        process.currentDirectoryURL = folder; process.standardOutput = pipe
        try process.run(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8), profile + "\nauth\nlogin\n")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("injected").path))
    }
    func testExistingOVRCASTProfileMigratesWithoutImportingOtherLaunchAgentSettings() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let agent = home.appendingPathComponent("Library/LaunchAgents/com.weekthink.usageboard.collect.plist")
        try FileManager.default.createDirectory(at: agent.deletingLastPathComponent(), withIntermediateDirectories: true)
        let profile = home.appendingPathComponent("a profile").path
        let settings: [String: Any] = ["Label": "com.weekthink.usageboard.collect", "EnvironmentVariables": [
            "CLAUDE_CONFIG_DIR": profile, "PATH": "/untrusted-bin", "ANTHROPIC_API_KEY": "fixture-only", "UNRELATED": "ignored"]]
        try PropertyListSerialization.data(fromPropertyList: settings, format: .xml, options: 0).write(to: agent)
        let migrated = ClaudeConnectionContext.environment(inherited: ["HOME": home.path], home: home)
        XCTAssertEqual(migrated["CLAUDE_CONFIG_DIR"], profile)
        XCTAssertEqual(migrated["HOME"], home.path)
        XCTAssertNil(migrated["ANTHROPIC_API_KEY"]); XCTAssertNil(migrated["UNRELATED"])
        XCTAssertFalse(migrated["PATH"]!.contains("untrusted"))
        for explicit in ["", home.appendingPathComponent("explicit").path] {
            let selected = ClaudeConnectionContext.environment(inherited: ["CLAUDE_CONFIG_DIR": explicit], home: home)
            XCTAssertEqual(selected["CLAUDE_CONFIG_DIR"], explicit)
        }
        var unrelated = settings; unrelated["Label"] = "other.collector"
        try PropertyListSerialization.data(fromPropertyList: unrelated, format: .xml, options: 0).write(to: agent)
        XCTAssertNil(ClaudeConnectionContext.environment(inherited: [:], home: home)["CLAUDE_CONFIG_DIR"])
    }
    func testFreshInstallDoesNotSelectAnotherClaudeProfile() {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertNil(ClaudeConnectionContext.environment(inherited: [:], home: home)["CLAUDE_CONFIG_DIR"])
    }
    func testExistingOwnedCLIMatchesTheConnectionAndCollectionPaths() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let cli = home.appendingPathComponent("Library/Application Support/UsageBoard/bin/claude")
        try FileManager.default.createDirectory(at: cli.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: cli)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: cli.path)
        let environment = ClaudeConnectionContext.environment(inherited: [:], home: home)
        XCTAssertEqual(environment["PATH"]?.components(separatedBy: ":").first, cli.deletingLastPathComponent().path)
        XCTAssertEqual(ProviderConnection.claudeExecutable(home: home, environment: environment), cli)
        let explicit = home.appendingPathComponent("explicit-claude")
        try FileManager.default.copyItem(at: cli, to: explicit)
        XCTAssertEqual(ProviderConnection.claudeExecutable(home: home, environment: ["CLAUDE_CLI_PATH": explicit.path]), explicit)
    }
}
