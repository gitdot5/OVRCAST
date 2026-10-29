import AppKit

/// Sign-in stays with provider software. No credentials are copied from another app.
enum ProviderConnection {
    static func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'" }
    static func claudeLoginScript(executable: String) -> String { "#!/bin/zsh\nexec " + shellQuote(executable) + " auth login\n" }
    static func claudeExecutable(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        let fm = FileManager.default
        var paths = [home.appendingPathComponent(".local/bin/claude"), URL(fileURLWithPath: "/opt/homebrew/bin/claude"), URL(fileURLWithPath: "/usr/local/bin/claude")]
        let installs = home.appendingPathComponent("Library/Application Support/Claude/claude-code")
        let versions = (try? fm.contentsOfDirectory(at: installs, includingPropertiesForKeys: nil)) ?? []
        for version in versions.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).prefix(20) {
            let platforms = (try? fm.contentsOfDirectory(at: version, includingPropertiesForKeys: nil)) ?? []
            paths += platforms.map { $0.appendingPathComponent("claude.app/Contents/MacOS/claude") }
        }
        return paths.first { fm.isExecutableFile(atPath: $0.path) }
    }
    static func open(_ provider: String) -> String {
        if provider == "Claude" {
            guard let executable = claudeExecutable() else {
                NSWorkspace.shared.open(URL(string: "https://code.claude.com/docs/en/setup")!)
                return "Install Claude Code and complete its sign-in, then check the connection."
            }
            let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/UsageBoard/Connections")
            let script = folder.appendingPathComponent("Connect Claude.command")
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let contents = claudeLoginScript(executable: executable.path)
                try contents.write(to: script, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
                guard NSWorkspace.shared.open(script) else { return "Open Claude Code and run claude auth login, then check again." }
                return "Complete Claude Code sign-in in Terminal, then check the connection."
            } catch { return "Open Claude Code and run claude auth login, then check again." }
        }
        let ids = ["Codex": "com.openai.codex", "Antigravity": "com.google.antigravity"]
        if let id = ids[provider], let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.open(app)
            return "Complete \(provider) sign-in, then check the connection."
        }
        let urls = ["Codex": "https://openai.com/codex/", "Antigravity": "https://antigravity.google/"]
        if let text = urls[provider], let url = URL(string: text) { NSWorkspace.shared.open(url) }
        return "Install or open \(provider), connect your account, then check again."
    }
}
