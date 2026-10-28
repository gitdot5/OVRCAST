import XCTest
@testable import UsageBoardMenuBar

final class RemoteReconnectTests: XCTestCase {
    func testRemoteClaudeUsesExistingUsageHelperAndPreservesPinnedOptions() throws {
        let ssh = ["-F", "/dev/null", "-o", "StrictHostKeyChecking=yes", "mini"]
        let action = try XCTUnwrap(RemoteReconnect.make(provider: "Claude", ssh: ssh))
        XCTAssertEqual(action.ssh, ssh)
        XCTAssertTrue(action.command.contains("Reconnect Claude.command"))
        XCTAssertTrue(action.command.contains("open -a Terminal"))
        XCTAssertFalse(action.command.contains("auth login"))
        XCTAssertNil(RemoteReconnect.make(provider: "Unsupported", ssh: ssh))
        XCTAssertNil(RemoteReconnect.make(provider: "Claude", ssh: []))
    }
    func testScreenSharingUsesResolvedHostAndRejectsURLInjection() {
        XCTAssertEqual(RemoteReconnect.screenSharingURL(Data("host mini\nhostname mini.example.com\nuser example\n".utf8))?.host, "mini.example.com")
        XCTAssertNil(RemoteReconnect.screenSharingURL(Data("hostname host/path?query\n".utf8)))
        XCTAssertNil(RemoteReconnect.screenSharingURL(Data("user example\n".utf8)))
    }
    func testRemoteActionsRequireKnownHostsAndDisableForwarding() {
        for option in ["StrictHostKeyChecking=yes", "ClearAllForwardings=yes", "ForwardAgent=no", "ForwardX11=no", "PermitLocalCommand=no"] {
            XCTAssertTrue(RemoteReconnect.connectionOptions.contains(option))
        }
    }
}
