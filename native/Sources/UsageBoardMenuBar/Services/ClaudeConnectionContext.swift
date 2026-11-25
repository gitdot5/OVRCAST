import Foundation

/// Preserve an existing OVRCAST connection without importing credentials or shell settings.
enum ClaudeConnectionContext {
    static func environment(inherited: [String: String] = ProcessInfo.processInfo.environment,
                            home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [String: String] {
        var environment = inherited
        if inherited["CLAUDE_CONFIG_DIR"] == nil {
            let agent = home.appendingPathComponent("Library/LaunchAgents/com.weekthink.usageboard.collect.plist")
            if let data = try? Data(contentsOf: agent),
               let settings = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               settings["Label"] as? String == "com.weekthink.usageboard.collect",
               let values = settings["EnvironmentVariables"] as? [String: String],
               let profile = values["CLAUDE_CONFIG_DIR"], profile.utf8.count <= 4096,
               !profile.contains("\0"), profile.isEmpty || profile.hasPrefix("/") {
                environment["CLAUDE_CONFIG_DIR"] = profile
            }
        }
        let ownedBin = home.appendingPathComponent("Library/Application Support/UsageBoard/bin")
        let prefix = FileManager.default.isExecutableFile(atPath: ownedBin.appendingPathComponent("claude").path) ? ownedBin.path + ":" : ""
        environment["PATH"] = prefix + home.path + "/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        return environment
    }
}
