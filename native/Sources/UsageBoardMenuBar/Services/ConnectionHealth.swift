import Foundation

enum ConnectionState: String, Codable {
    case notChecked, checking, connected, partial, signInRequired, softwareMissing, unavailable, stale, resetPending
    var title: String {
        switch self {
        case .notChecked: return "Not checked"
        case .checking: return "Checking…"
        case .connected: return "Usage received"
        case .partial: return "Some accounts need attention"
        case .signInRequired: return "Sign-in needed"
        case .softwareMissing: return "Provider software missing"
        case .unavailable: return "Connection unavailable"
        case .stale: return "Reading is old"
        case .resetPending: return "Waiting for reset confirmation"
        }
    }
    var guidance: String {
        switch self {
        case .notChecked: return "Connect your own account, then check for a usage reading."
        case .checking: return "Other connections can finish independently."
        case .connected: return "A current provider reading confirms this connection."
        case .partial: return "Some readings arrived. Open the board to reconnect accounts that still need attention."
        case .signInRequired: return "Complete sign-in in the provider software, then retry."
        case .softwareMissing: return "Install the provider software using Connect, then retry."
        case .unavailable: return "Check the network and provider software. Automatic retries slow down after failures."
        case .stale: return "Last-known readings remain visible. Retry to confirm current capacity."
        case .resetPending: return "A fresh reading must confirm restored allowance."
        }
    }
}

struct ConnectionHealth: Codable {
    var state: ConnectionState = .notChecked
    var checkedAt: Date?
    var lastSuccess: Date?
    var failures = 0
    var retryAt: Date?
    func displayState(now: Date = Date()) -> ConnectionState {
        if [.connected, .partial, .resetPending].contains(state), lastSuccess.map({ now.timeIntervalSince($0) > 600 }) == true { return .stale }
        return state
    }
    static func classify(_ rows: [UsageAccount]) -> ConnectionState {
        if rows.contains(where: { $0.current && !$0.quotas.isEmpty && $0.requiresSignIn != true && $0.issue.isEmpty }) {
            if rows.contains(where: { !$0.current || $0.requiresSignIn == true || !$0.issue.isEmpty }) { return .partial }
            return rows.contains(where: { $0.current && $0.quotas.contains(where: \.awaiting) }) ? .resetPending : .connected
        }
        if rows.contains(where: { $0.requiresSignIn == true }) { return .signInRequired }
        if rows.contains(where: { $0.issue.contains("software needed for this connection is missing") }) { return .softwareMissing }
        return .unavailable
    }
    mutating func finish(_ rows: [UsageAccount], now: Date = Date()) {
        checkedAt = now; state = Self.classify(rows)
        let success = [.connected, .partial, .resetPending].contains(state)
        if success {
            lastSuccess = rows.filter(\.current).compactMap { parsedDate($0.observedAt) }.max()
            failures = 0; retryAt = now.addingTimeInterval(180)
        } else {
            failures = min(10, failures + 1)
            retryAt = now.addingTimeInterval(min(1800, 180 * pow(2, Double(failures - 1))))
        }
    }
    func due(now: Date = Date()) -> Bool { retryAt.map { $0 <= now } ?? true }
}

enum SupportReport {
    static func text(accounts: [UsageAccount], providers: [String], health: [String: ConnectionHealth], remoteCount: Int,
                     native: Bool, helperAvailable: Bool, storageProblem: Bool) -> String {
        // Construct from an allowlist. Never serialize raw errors, IDs, paths or preferences.
        let providers = providers.filter { ["Codex", "Claude", "Antigravity"].contains($0) }
        let rows: [[String: Any]] = providers.map { provider in
            let status = health[provider] ?? ConnectionHealth()
            return ["provider": provider, "state": status.displayState().rawValue,
                    "hasSuccessfulReading": status.lastSuccess != nil, "retryScheduled": status.retryAt != nil]
        }
        let payload: [String: Any] = ["app": "OVRCAST", "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development",
            "osMajor": ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            "collection": native ? "native" : "existing collector", "helperAvailable": helperAvailable,
            "storageProblem": storageProblem, "remoteCount": remoteCount, "connections": rows,
            "readingCount": accounts.count, "currentReadingCount": accounts.filter(\.current).count]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else { return "Report unavailable" }
        return String(decoding: data, as: UTF8.self)
    }
}
