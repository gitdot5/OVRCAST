import Foundation

enum DemoData {
    static func snapshot(stale: Bool = false) -> UsageSnapshot {
        let now = Date(), stamp = ISO8601DateFormatter()
        let specs: [(String, String, String, Double)] = [
            ("Codex", "Personal", "MacBook", 82), ("Codex", "Work", "Mac Studio 1", 43), ("Codex", "Lab", "Mac Studio 2", 94),
            ("Claude", "Personal", "MacBook", 31), ("Claude", "Work", "Mac Studio 1", 76), ("Claude", "Lab", "Mac Studio 2", 12),
            ("Antigravity", "Personal", "MacBook", 100)]
        let rows = specs.enumerated().map { index, spec in
            UsageAccount(id: "demo-\(index)", provider: spec.0, email: spec.1 + "@example.com", plan: "Example plan", machines: [spec.2],
                         severity: spec.3 > 40 ? "good" : "warning", status: spec.3 > 40 ? "Available" : "Running low", fresh: !stale,
                         observedAt: stamp.string(from: stale ? now.addingTimeInterval(-3600) : now), source: "Demo", issue: stale ? "Example connection unavailable" : "", quotas: [
                            Quota(label: "Session", remaining: min(100, spec.3 + 5), resetsAt: stamp.string(from: now.addingTimeInterval(7200)), resetPassed: false),
                            Quota(label: "Weekly", remaining: spec.3, resetsAt: stamp.string(from: now.addingTimeInterval(3 * 86400)), resetPassed: false)],
                         savedResets: spec.0 == "Codex" ? 1 : nil, resetDetails: [], credits: [CreditPool(name: "Cloud credits", value: "Unknown", detail: "Example data")])
        }
        return UsageSnapshot(version: 1, generatedAt: stamp.string(from: now), accounts: rows)
    }
    static func tokenActivity() -> TokenActivityLedger {
        let now = Date(), stamp = ISO8601DateFormatter().string(from: Date())
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current; formatter.dateFormat = "yyyy-MM-dd"
        let rows = ["MacBook", "Mac Studio 1", "Mac Studio 2"].enumerated().map { index, machine in
            TokenMachine(machine: machine, harnesses: TokenActivityCollector.providers.enumerated().map { offset, provider in
                TokenHarness(schemaVersion: 1, provider: provider, generatedAt: stamp, timeZone: TimeZone.current.identifier,
                    historyComplete: offset != 2, days: (0..<7).map { day in
                        let input = (index + 1) * (offset + 1) * (day + 1) * 1000
                        return TokenDay(date: formatter.string(from: Calendar.current.date(byAdding: .day, value: -day, to: now)!),
                                        input: input, output: input / 4, cacheRead: input / 2, cacheWrite: nil, total: input + input / 4 + input / 2)
                    })
            })
        }
        return TokenActivityLedger(generatedAt: stamp, machines: rows)
    }
}
