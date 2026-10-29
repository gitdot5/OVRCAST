import Foundation

/// Provider-reported schedule only. A passed timestamp never confirms a refill.
enum ResetSchedule: Equatable {
    case scheduled(window: String, date: Date)
    case awaitingReading
    case unavailable
    case stale

    static func next(for account: UsageAccount, now: Date = Date()) -> ResetSchedule {
        guard account.fresh, let observed = parsedDate(account.observedAt),
              (-60...600).contains(now.timeIntervalSince(observed)) else { return .stale }
        guard account.requiresSignIn != true, !account.quotas.isEmpty else { return .unavailable }
        if account.quotas.contains(where: { $0.resetPassed || parsedDate($0.resetsAt).map { $0 <= now } == true }) {
            return .awaitingReading
        }
        let next = account.quotas.compactMap { quota -> (String, Date)? in
            guard let date = parsedDate(quota.resetsAt), date > now else { return nil }
            return (quota.label, date)
        }.min { $0.1 < $1.1 }
        return next.map { .scheduled(window: $0.0, date: $0.1) } ?? .unavailable
    }
}

func resetCountdown(until date: Date, now: Date = Date()) -> String {
    let seconds = date.timeIntervalSince(now)
    guard seconds > 0 else { return "Awaiting new reading" }
    let minutes = max(1, Int(ceil(seconds / 60)))
    if minutes >= 1440 { return "in \(minutes / 1440)d \((minutes % 1440) / 60)h" }
    if minutes >= 60 { return "in \(minutes / 60)h \(minutes % 60)m" }
    return "in \(minutes)m"
}

func resetLocalTime(_ date: Date, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.setLocalizedDateFormatFromTemplate("EEE MMM d h:mm a z")
    return formatter.string(from: date)
}
