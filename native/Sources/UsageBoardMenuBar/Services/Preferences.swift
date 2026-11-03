import Foundation

struct RemoteMachine: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name: String
    var sshAlias: String
    var status = "Not checked"
    var checkedAt: String?
    private enum CodingKeys: String, CodingKey { case id, name, sshAlias, status, checkedAt }
    init(id: String = UUID().uuidString, name: String, sshAlias: String, status: String = "Not checked", checkedAt: String? = nil) {
        self.id = id; self.name = name; self.sshAlias = sshAlias; self.status = status; self.checkedAt = checkedAt
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString,
                  name: try values.decode(String.self, forKey: .name), sshAlias: try values.decode(String.self, forKey: .sshAlias),
                  status: try values.decodeIfPresent(String.self, forKey: .status) ?? "Not checked",
                  checkedAt: try values.decodeIfPresent(String.self, forKey: .checkedAt))
    }
    var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        sshAlias.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,100}$", options: .regularExpression) != nil
    }
}
struct BoardPreferences: Codable {
    var setupComplete = false
    var nativeCollection = false
    var providers = ["Codex", "Claude"]
    var machineName = "This Mac"
    var aliases: [String: String] = [:]
    var privacyMode = false
    var shortcutEnabled = true
    var notifications = false
    var lowThreshold = 15.0
    var quietStart = 22
    var quietEnd = 8
    var snoozeUntil: Date?
    var remotes: [RemoteMachine] = []
    var recommendationProvider = "Codex"
    var recommendationWindow = "All limits"

    init() {}
    private enum CodingKeys: String, CodingKey {
        case setupComplete, nativeCollection, providers, machineName, aliases, privacyMode, shortcutEnabled, notifications, lowThreshold, quietStart, quietEnd, snoozeUntil, remotes, recommendationProvider, recommendationWindow
    }
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        setupComplete = try values.decodeIfPresent(Bool.self, forKey: .setupComplete) ?? setupComplete
        nativeCollection = try values.decodeIfPresent(Bool.self, forKey: .nativeCollection) ?? nativeCollection
        providers = try values.decodeIfPresent([String].self, forKey: .providers) ?? providers
        machineName = try values.decodeIfPresent(String.self, forKey: .machineName) ?? machineName
        aliases = try values.decodeIfPresent([String: String].self, forKey: .aliases) ?? aliases
        privacyMode = try values.decodeIfPresent(Bool.self, forKey: .privacyMode) ?? privacyMode
        shortcutEnabled = try values.decodeIfPresent(Bool.self, forKey: .shortcutEnabled) ?? shortcutEnabled
        notifications = try values.decodeIfPresent(Bool.self, forKey: .notifications) ?? notifications
        lowThreshold = try values.decodeIfPresent(Double.self, forKey: .lowThreshold) ?? lowThreshold
        quietStart = try values.decodeIfPresent(Int.self, forKey: .quietStart) ?? quietStart
        quietEnd = try values.decodeIfPresent(Int.self, forKey: .quietEnd) ?? quietEnd
        snoozeUntil = try values.decodeIfPresent(Date.self, forKey: .snoozeUntil)
        remotes = try values.decodeIfPresent([RemoteMachine].self, forKey: .remotes) ?? remotes
        recommendationProvider = try values.decodeIfPresent(String.self, forKey: .recommendationProvider) ?? recommendationProvider
        recommendationWindow = try values.decodeIfPresent(String.self, forKey: .recommendationWindow) ?? recommendationWindow
        var seen: Set<String> = []
        providers = providers.filter { ["Codex", "Claude", "Antigravity"].contains($0) && seen.insert($0).inserted }
        if machineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { machineName = "This Mac" }
        lowThreshold = lowThreshold.isFinite ? min(100, max(0, lowThreshold)) : 15
        quietStart = min(23, max(0, quietStart)); quietEnd = min(23, max(0, quietEnd))
    }
}
struct HistoryPoint: Codable, Identifiable {
    var accountID: String
    var label: String
    var date: Date
    var remaining: Double
    var reset: String
    var id: String { accountID + "|" + label + "|" + String(date.timeIntervalSince1970) }
}
enum PrivateFiles {
    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        let temp = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".tmp")
        // Create owner-only before writing even the first byte.
        guard fm.createFile(atPath: temp.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { try? fm.removeItem(at: temp) }
        let handle = try FileHandle(forWritingTo: temp)
        try handle.write(contentsOf: JSONEncoder().encode(value))
        try handle.close()
        if fm.fileExists(atPath: url.path) { _ = try fm.replaceItemAt(url, withItemAt: temp) }
        else { try fm.moveItem(at: temp, to: url) }
    }
    static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
