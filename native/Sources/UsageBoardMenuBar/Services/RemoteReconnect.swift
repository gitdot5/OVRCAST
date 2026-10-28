import Foundation

struct RemoteReconnect {
    static let connectionOptions = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
                                    "-o", "StrictHostKeyChecking=yes", "-o", "ClearAllForwardings=yes",
                                    "-o", "ForwardAgent=no", "-o", "ForwardX11=no", "-o", "PermitLocalCommand=no"]
    let ssh: [String]
    let command: String

    static func make(provider: String, ssh: [String]) -> RemoteReconnect? {
        guard !ssh.isEmpty else { return nil }
        let command: String
        switch provider {
        case "Claude":
            // Keep authentication on the remote Mac and in its existing usage profile.
            command = #"test -f "$HOME/Library/Application Support/UsageBoard/Reconnect Claude.command" && /usr/bin/open -a Terminal "$HOME/Library/Application Support/UsageBoard/Reconnect Claude.command""#
        case "Codex": command = "/usr/bin/open -a Codex"
        case "Antigravity": command = "/usr/bin/open -a Antigravity"
        default: return nil
        }
        return RemoteReconnect(ssh: ssh, command: command)
    }

    static func screenSharingURL(_ configuration: Data) -> URL? {
        guard let text = String(data: configuration, encoding: .utf8),
              let line = text.split(separator: "\n").first(where: { $0.hasPrefix("hostname ") }) else { return nil }
        let host = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty, host.range(of: "^[A-Za-z0-9.:%_-]+$", options: .regularExpression) != nil else { return nil }
        var url = URLComponents(); url.scheme = "vnc"; url.host = host
        return url.url
    }

    func open() -> (URL?, Bool) {
        // Resolve the configured alias locally; preserve pinned SSH options for the connection.
        let config = try? CommandRunner.run("/usr/bin/ssh", ["-G"] + Self.connectionOptions + ssh, timeout: 10)
        let url = config.flatMap { $0.code == 0 ? Self.screenSharingURL($0.data) : nil }
        let result = try? CommandRunner.run("/usr/bin/ssh", Self.connectionOptions + ssh + [command], timeout: 20)
        return (url, result?.code == 0)
    }
}
