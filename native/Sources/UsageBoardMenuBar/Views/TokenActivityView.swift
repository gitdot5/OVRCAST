import SwiftUI

struct TokenActivityView: View {
    @ObservedObject var store: UsageStore
    @State private var days = 1
    private func count(_ value: Int?) -> String { store.preferences.privacyMode ? "Hidden" : value.map { $0.formatted() } ?? "Unavailable" }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Token activity").font(.title2.bold())
                Spacer()
                Picker("Period", selection: $days) { Text("Today").tag(1); Text("Last 7 days").tag(7) }.pickerStyle(.segmented).frame(width: 220)
                Button("Refresh") { store.refreshTokenActivity(force: true) }.disabled(store.checkingTokens || !store.preferences.tokenHistory)
            }
            Text("Recorded local usage by harness, separate from account quota and billing. Each computer uses its own timezone.").font(.caption).foregroundStyle(.secondary)
            if !store.preferences.tokenHistory {
                ContentUnavailableView("Token history is off", systemImage: "chart.bar", description: Text("Enable Read local token counters in Settings → Connect."))
                Button("Settings") { store.showSettings = true }
            } else if let ledger = store.tokenActivity {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(ledger.machines.enumerated()), id: \.offset) { _, machine in
                            Text(store.machineName(machine.machine)).font(.headline)
                            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                                GridRow { Text("Harness"); Text("Input"); Text("Output"); Text("Cache read"); Text("Cache write"); Text("Total") }.font(.caption.bold())
                                ForEach(Array(machine.harnesses.enumerated()), id: \.offset) { _, harness in
                                    let summary = harness.summary(days: days)
                                    GridRow {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(harness.title)
                                            Text(harness.error != nil ? "History unavailable" : !harness.current ? "Last known" : harness.historyComplete ? "Scanned local history" : harness.scanComplete == true ? "Recorded local subtotal" : "Partial local history")
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                        Text(count(summary?.input)); Text(count(summary?.output)); Text(count(summary?.cacheRead)); Text(count(summary?.cacheWrite)); Text(count(summary?.total))
                                    }.font(.caption).monospacedDigit().accessibilityElement(children: .combine)
                                }
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            } else { ContentUnavailableView(store.checkingTokens ? "Reading local token counters…" : "No token history yet", systemImage: "chart.bar", description: Text("Missing data is unavailable, not zero.")) }
            Text("Partial figures are recorded subtotals, not complete account totals. Copied sessions may overlap between Macs, so computer totals are not added together. No dollar cost is inferred from tokens.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(22).frame(minWidth: 620, minHeight: 370).preferredColorScheme(store.scheme)
    }
}
