import Foundation

struct RemoteMachine: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name: String
    var sshAlias: String
    var status = "Not checked"
    var checkedAt: String?
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
