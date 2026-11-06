import Foundation

/// Cache timestamps, never freshness decisions. The clock is still checked by each caller.
final class UsageDateParser: @unchecked Sendable {
    static let shared = UsageDateParser()
    private let cache = NSCache<NSString, NSDate>()
    private let lock = NSLock()
    private let seconds = ISO8601DateFormatter()
    private let fractional = ISO8601DateFormatter()
    private init() {
        fractional.formatOptions.insert(.withFractionalSeconds)
        cache.countLimit = 2048
    }
    func parse(_ text: String?) -> Date? {
        guard let text, !text.isEmpty, text.utf8.count <= 128 else { return nil }
        let key = text as NSString
        if let date = cache.object(forKey: key) { return date as Date }
        lock.lock(); defer { lock.unlock() }
        if let date = cache.object(forKey: key) { return date as Date }
        guard let date = seconds.date(from: text) ?? fractional.date(from: text) else { return nil }
        cache.setObject(date as NSDate, forKey: key)
        return date
    }
}
