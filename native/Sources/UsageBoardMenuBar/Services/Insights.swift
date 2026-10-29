import Foundation

struct Recommendation {
    var account: UsageAccount
    var remaining: Double
    var limitingWindow: String
}
enum Insights {
    static func recommend(_ accounts: [UsageAccount], provider: String, window: String = "All limits") -> Recommendation? {
        let shared: Set<String> = ["session", "5-hour", "weekly", "daily", "monthly", "all models"]
        return accounts.filter { $0.provider == provider && $0.current && $0.requiresSignIn != true && $0.issue.isEmpty }
            .compactMap { account -> Recommendation? in
                let quotas = window == "All limits" ? account.quotas : account.quotas.filter {
                    let label = $0.label.lowercased()
                    let explicitlyScoped = label.contains(" only") || (label.hasPrefix("model ") && label != "model limit")
                    return $0.label == window || shared.contains(label) || !explicitlyScoped
                }
                guard window == "All limits" || account.quotas.contains(where: { $0.label == window }) else { return nil }
                guard !quotas.isEmpty, !quotas.contains(where: \.awaiting),
                      let minimum = quotas.min(by: { $0.remaining < $1.remaining }), minimum.remaining > 0 else { return nil }
                return Recommendation(account: account, remaining: minimum.remaining, limitingWindow: minimum.label)
            }.sorted { $0.remaining > $1.remaining }.first
    }
    static func history(_ previous: [HistoryPoint], accounts: [UsageAccount], now: Date = Date()) -> [HistoryPoint] {
        var result = previous.filter { now.timeIntervalSince($0.date) < 7 * 86400 && $0.date <= now.addingTimeInterval(60) }
        var seen = Set(result.map(\.id))
        for account in accounts where account.current {
            guard let date = parsedDate(account.observedAt) else { continue }
            for quota in account.quotas where !quota.awaiting {
                let point = HistoryPoint(accountID: account.id, label: quota.label, date: date,
                                         remaining: quota.remaining, reset: quota.resetsAt ?? "unknown")
                if seen.insert(point.id).inserted { result.append(point) }
            }
        }
        return Array(result.sorted { $0.date < $1.date }.suffix(100_000))
    }
    static func supportReport(_ accounts: [UsageAccount], native: Bool, helperAvailable: Bool) -> String {
        // Deliberate allowlist: no emails, account IDs, aliases, machines, balances or raw errors.
        let knownProviders = Set(["Codex", "Claude", "Antigravity", "Claude Platform"])
        let rows = accounts.map { ["provider": knownProviders.contains($0.provider) ? $0.provider : "Other",
                                  "status": $0.requiresSignIn == true ? "Sign in required" : $0.current ? "Reading available" : "Needs a reading",
                                  "fresh": String($0.current), "quotaCount": String($0.quotas.count)] }
        let payload: [String: Any] = ["app": "OVRCAST", "version": "0.3.3",
            "collection": native ? "native" : "existing collector", "helperAvailable": helperAvailable, "accounts": rows]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else { return "Report unavailable" }
        return String(decoding: data, as: UTF8.self)
    }
}
struct UsageAlert: Equatable {
    var id: String
    var title: String
    var body: String
}
enum AlertRules {
    static func quiet(hour: Int, start: Int, end: Int) -> Bool {
        if start == end { return false }
        return start < end ? (start..<end).contains(hour) : hour >= start || hour < end
    }
    static func changes(from previous: [UsageAccount], to current: [UsageAccount], threshold: Double, now: Date = Date()) -> [UsageAlert] {
        var alerts: [UsageAlert] = []
        for account in current where account.current && account.requiresSignIn != true && account.issue.isEmpty {
            for pool in account.credits {
                if let expiry = parsedDate(pool.expiresAt), expiry > now, expiry.timeIntervalSince(now) <= 86400,
                   let range = pool.value.range(of: #"[0-9]+(?:\.[0-9]+)?"#, options: .regularExpression),
                   let amount = Double(pool.value[range]), amount > 0 {
                    alerts.append(UsageAlert(id: account.id + "|expiry|" + pool.name + "|" + (pool.expiresAt ?? ""),
                                             title: "\(account.provider) credits expire soon", body: "The provider reports a credit expiry within 24 hours. Open OVRCAST for details."))
                }
            }
            guard let old = previous.first(where: { $0.id == account.id }),
                  let before = parsedDate(old.observedAt), let after = parsedDate(account.observedAt), after > before else { continue }
            for quota in account.quotas where !quota.awaiting {
                guard let prior = old.quotas.first(where: { $0.label == quota.label }) else { continue }
                let key = account.id + "|" + quota.label + "|" + (quota.resetsAt ?? "unknown")
                if prior.remaining > threshold && quota.remaining <= threshold {
                    alerts.append(UsageAlert(id: key + "|low", title: "\(account.provider) is running low",
                                             body: "\(quota.label) has \(Int(quota.remaining))% left. Open OVRCAST for alternatives."))
                }
                if let priorReset = parsedDate(prior.resetsAt), let nextReset = parsedDate(quota.resetsAt),
                   priorReset <= now, nextReset > priorReset, quota.remaining > prior.remaining + 5 {
                    alerts.append(UsageAlert(id: key + "|reset", title: "\(account.provider) allowance refreshed",
                                             body: "A new reading confirms more \(quota.label.lowercased()) capacity is available."))
                }
            }
        }
        return alerts
    }
}
