import Foundation

struct CapacityForecast {
    var hours: Double
    var beforeReset: Bool
    static func estimate(account: UsageAccount, quota: Quota, history: [HistoryPoint], now: Date = Date()) -> CapacityForecast? {
        guard account.current, !quota.awaiting, account.issue.isEmpty, account.requiresSignIn != true,
              let observed = parsedDate(account.observedAt), let reset = quota.resetsAt,
              let resetDate = parsedDate(reset), resetDate > now, quota.remaining > 0 else { return nil }
        let rows = history.filter { $0.accountID == account.id && $0.label == quota.label && $0.reset == reset &&
            $0.date <= observed && $0.date >= observed.addingTimeInterval(-7200) }.sorted { $0.date < $1.date }
        guard rows.count >= 3, let first = rows.first, let last = rows.last,
              last.date.timeIntervalSince(first.date) >= 900, observed.timeIntervalSince(last.date) <= 300,
              abs(last.remaining - quota.remaining) < 0.1 else { return nil }
        for (a, b) in zip(rows, rows.dropFirst()) {
            guard b.date > a.date, b.date.timeIntervalSince(a.date) <= 900, b.remaining <= a.remaining else { return nil }
        }
        let consumed = first.remaining - last.remaining
        guard consumed >= 1 else { return nil }
        let hours = quota.remaining / (consumed / (last.date.timeIntervalSince(first.date) / 3600))
        guard hours.isFinite, hours > 0, hours < 168 else { return nil }
        return CapacityForecast(hours: hours, beforeReset: hours * 3600 < resetDate.timeIntervalSince(now))
    }
    var label: String {
        "Estimate at recent pace: about " + (hours < 1 ? "\(max(1, Int(hours * 60))) min" : String(format: "%.1f h", hours)) + " of capacity" + (beforeReset ? " · may run out before reset" : "")
    }
}
