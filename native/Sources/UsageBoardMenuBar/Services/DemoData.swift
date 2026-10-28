import Foundation

enum DemoData {
    static func snapshot() -> UsageSnapshot {
        let now = Date(), stamp = ISO8601DateFormatter()
        let specs: [(String, String, String, Double)] = [
            ("Codex", "Personal", "MacBook", 82), ("Codex", "Work", "Studio", 43), ("Codex", "Lab", "Mini", 94),
            ("Claude", "Personal", "MacBook", 31), ("Claude", "Work", "Studio", 76), ("Claude", "Lab", "Mini", 12),
            ("Antigravity", "Personal", "MacBook", 100)]
        let rows = specs.enumerated().map { index, spec in
            UsageAccount(id: "demo-\(index)", provider: spec.0, email: spec.1 + "@example.com", plan: "Example plan", machines: [spec.2],
                         severity: spec.3 > 40 ? "good" : "warning", status: spec.3 > 40 ? "Available" : "Running low", fresh: true,
                         observedAt: stamp.string(from: now), source: "Demo", issue: "", quotas: [
                            Quota(label: "Session", remaining: min(100, spec.3 + 5), resetsAt: stamp.string(from: now.addingTimeInterval(7200)), resetPassed: false),
                            Quota(label: "Weekly", remaining: spec.3, resetsAt: stamp.string(from: now.addingTimeInterval(3 * 86400)), resetPassed: false)],
                         savedResets: spec.0 == "Codex" ? 1 : nil, resetDetails: [], credits: [CreditPool(name: "Cloud credits", value: "Unknown", detail: "Example data")])
        }
        return UsageSnapshot(version: 1, generatedAt: stamp.string(from: now), accounts: rows)
    }
}
