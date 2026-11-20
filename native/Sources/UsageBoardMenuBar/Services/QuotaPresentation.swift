import Foundation

/// A historical value stays visible even after its old reset time has passed.
/// Only a current reading may describe a reset as pending.
struct QuotaPresentation {
    enum State { case current, lastKnown, resetPending, unavailable }
    let state: State
    let fraction: Double
    let value: String
    let accessibilityValue: String

    init(_ quota: Quota, current: Bool, now: Date = Date()) {
        guard quota.remaining.isFinite, (0...100).contains(quota.remaining) else {
            state = .unavailable; fraction = 0; value = "Unavailable"; accessibilityValue = "Allowance unavailable"
            return
        }
        let percent = Int(quota.remaining.rounded())
        if current && (quota.resetPassed || parsedDate(quota.resetsAt).map { $0 <= now } == true) {
            state = .resetPending; fraction = 0; value = "Pending"; accessibilityValue = "Reset pending; a new reading is required"
        } else {
            state = current ? .current : .lastKnown
            fraction = quota.remaining / 100
            value = "\(percent)% left"
            accessibilityValue = "\(percent) percent remaining" + (current ? "" : ", last known")
        }
    }
}
