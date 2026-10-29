import AppKit
import SwiftUI

struct UsageSnapshot: Codable {
    var version: Int
    var generatedAt: String
    var accounts: [UsageAccount]
}
struct Quota: Codable {
    var label: String
    var remaining: Double
    var resetsAt: String?
    var resetPassed: Bool
    var awaiting: Bool { resetPassed || parsedDate(resetsAt).map { $0 <= Date() } == true }
}
struct CreditPool: Codable {
    var name: String
    var value: String
    var detail: String
    var expiresAt: String?
}
struct UsageAccount: Codable, Identifiable {
    var id: String
    var provider: String
    var email: String
    var plan: String
    var machines: [String]
    var severity: String
    var status: String
    var requiresSignIn: Bool?
    var fresh: Bool
    var observedAt: String?
    var source: String
    var issue: String
    var pace: String?
    var quotas: [Quota]
    var savedResets: Int?
    var resetDetails: [String]
    var credits: [CreditPool]
    var current: Bool {
        fresh && parsedDate(observedAt).map { (-60...600).contains(Date().timeIntervalSince($0)) } == true
    }
    var available: Bool { current && severity == "good" && requiresSignIn != true && issue.isEmpty && !quotas.isEmpty && !quotas.contains(where: \.awaiting) }
    var activeMachines: [String] { machines.filter { !$0.lowercased().contains("retired") } }
    var remainingForSort: Double? {
        guard current, !quotas.isEmpty, !quotas.contains(where: \.awaiting) else { return nil }
        return quotas.map(\.remaining).min()
    }
    var color: Color {
        guard current else { return .secondary }
        switch severity { case "critical": return .red; case "warning": return .orange; case "good": return .green; default: return .secondary }
    }
    var shortStatus: String {
        if requiresSignIn == true { return "Sign in required" }
        guard current else { return "Needs a reading" }
        if quotas.contains(where: \.awaiting) { return "Reset pending" }
        switch status {
        case "Model limit reached": return "Model capped"
        case "Included limit reached": return "Limit reached"
        case "At risk before reset": return "Pace risk"
        case "Limited headroom": return "Running low"
        default: return status
        }
    }
}

enum AccountFilter: String, CaseIterable {
    case all, available, attention, unreadable
    var title: String {
        switch self { case .all: return "All statuses"; case .available: return "Available";
        case .attention: return "Needs attention"; case .unreadable: return "Needs a reading" }
    }
}
enum AccountOrder: String, CaseIterable {
    case attention, mostLeft, leastLeft, machine, nextReset
    var title: String {
        switch self { case .attention: return "Attention first"; case .mostLeft: return "Most usage left";
        case .leastLeft: return "Least usage left"; case .machine: return "Machine order";
        case .nextReset: return "Next reset" }
    }
}
enum AccountList {
    static func machines(_ accounts: [UsageAccount]) -> [String] {
        let names = Set(accounts.flatMap(\.activeMachines))
        return ["MacBook", "Mini", "Studio"].filter(names.contains) + names.subtracting(["MacBook", "Mini", "Studio"]).sorted()
    }
    static func apply(_ accounts: [UsageAccount], provider: String = "Overview", machine: String = "",
                      status: AccountFilter = .all, order: AccountOrder = .attention, firstMachine: String = "MacBook") -> [UsageAccount] {
        let filtered = accounts.filter { account in
            (provider == "Overview" || account.provider == provider) &&
            (machine.isEmpty || account.activeMachines.contains(machine)) && {
                switch status {
                case .all: return true
                case .available: return account.available
                case .attention: return !account.available
                case .unreadable: return !account.current || account.quotas.isEmpty || account.quotas.contains(where: \.awaiting)
                }
            }()
        }
        guard order != .attention else { return filtered }
        var machineNames = machines(accounts)
        if let start = machineNames.firstIndex(of: firstMachine) {
            machineNames = Array(machineNames[start...]) + Array(machineNames[..<start])
        }
        func value(_ account: UsageAccount) -> Double? {
            switch order {
            case .mostLeft, .leastLeft: return account.remainingForSort
            case .machine:
                return account.activeMachines.compactMap { machineNames.firstIndex(of: $0) }.min().map(Double.init)
            case .nextReset:
                guard account.current, !account.quotas.contains(where: \.awaiting) else { return nil }
                return account.quotas.filter { !$0.awaiting }.compactMap { parsedDate($0.resetsAt)?.timeIntervalSince1970 }.min()
            case .attention: return nil
            }
        }
        return filtered.enumerated().sorted { lhs, rhs in
            switch (value(lhs.element), value(rhs.element)) {
            case let (a?, b?) where a != b: return order == .mostLeft ? a > b : a < b
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }
}
func parsedDate(_ text: String?) -> Date? {
    guard let text else { return nil }
    let formatter = ISO8601DateFormatter()
    if let date = formatter.date(from: text) { return date }
    formatter.formatOptions.insert(.withFractionalSeconds)
    return formatter.date(from: text)
}
func age(_ text: String?) -> String {
    guard let date = parsedDate(text) else { return "No reading" }
    let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
    return minutes < 1 ? "Just now" : minutes < 60 ? "\(minutes)m ago" : "\(minutes / 60)h ago"
}
func resetLabel(_ text: String?) -> String {
    guard let date = parsedDate(text) else { return "Reset unknown" }
    guard date > Date() else { return "Awaiting new reading" }
    return "Resets \(resetCountdown(until: date))"
}
func artwork(_ name: String, device: Bool = false) -> NSImage? {
    let names = device ? ["MacBook": "macbook", "Mini": "mac-mini", "Studio": "mac-studio"] :
        ["Codex": "codex", "Claude": "claude", "Claude Platform": "claude", "Antigravity": "antigravity"]
    guard let file = names[name], let root = Bundle.main.resourceURL else { return nil }
    let folder = device ? "devices" : "provider-logos"
    return NSImage(contentsOf: root.appendingPathComponent("assets/\(folder)/\(file).png"))
}

