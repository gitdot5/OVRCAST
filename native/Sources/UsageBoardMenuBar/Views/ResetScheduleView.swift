import SwiftUI

struct ResetScheduleView: View {
    let account: UsageAccount
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: "clock.arrow.circlepath")
                switch ResetSchedule.next(for: account, now: context.date) {
                case let .scheduled(window, date):
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next reset · \(window) · \(resetCountdown(until: date, now: context.date))")
                        Text(resetLocalTime(date))
                    }
                case .awaitingReading: Text("Reset due · awaiting new reading")
                case .unavailable: Text("Next reset unavailable")
                case .stale: Text("Reset time unavailable · refresh needed")
                }
            }
            .font(.system(size: 9)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }
}
