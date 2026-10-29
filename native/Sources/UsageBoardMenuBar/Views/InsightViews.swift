import SwiftUI
import Charts

struct RecommendationView: View {
    @ObservedObject var store: UsageStore
    private var provider: String { store.selectedProvider == "Overview" ? store.preferences.recommendationProvider : store.selectedProvider }
    private var windows: [String] { ["All limits"] + Set(store.visibleAccounts.filter { $0.provider == provider }.flatMap(\.quotas).map(\.label)).sorted() }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle").foregroundStyle(.tint)
                Text("Best headroom").fontWeight(.semibold)
                Spacer()
                Menu {
                    Picker("Provider", selection: $store.preferences.recommendationProvider) {
                        ForEach(store.providers.filter { $0 != "Overview" }, id: \.self) { Text($0).tag($0) }
                    }.disabled(store.selectedProvider != "Overview")
                    Picker("Allowance", selection: $store.preferences.recommendationWindow) { ForEach(windows, id: \.self) { Text($0).tag($0) } }
                } label: { Text(provider) }
                .menuStyle(.borderlessButton).fixedSize()
            }.font(.system(size: 10))
            if let best = store.recommendation {
                Button { store.selectedAccount = best.account.id } label: {
                    HStack {
                        Text(store.accountName(best.account)).lineLimit(1)
                        Spacer()
                        Text("\(Int(best.remaining))% left").fontWeight(.semibold).monospacedDigit()
                    }.font(.system(size: 11))
                }.buttonStyle(.plain)
                HStack {
                    Text("\(best.limitingWindow) · \(best.account.activeMachines.map(store.machineName).joined(separator: ", "))").lineLimit(1)
                    Spacer()
                    Text(resetLabel(best.account.quotas.first { $0.label == best.limitingWindow }?.resetsAt)).lineLimit(1)
                }.font(.system(size: 9)).foregroundStyle(.secondary)
            } else { Text("No fresh, usable reading for this selection.").font(.system(size: 10)).foregroundStyle(.secondary) }
        }.padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
            .help("Compares current reported allowance within one provider. Shared quotas are counted once.")
            .onChange(of: provider) { _, _ in store.preferences.recommendationWindow = "All limits" }
    }
}
struct AccountHistoryView: View {
    let points: [HistoryPoint]
    @State private var selected = ""
    private var labels: [String] { Set(points.map(\.label)).sorted() }
    private var active: String { labels.contains(selected) ? selected : labels.first ?? "" }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last 7 days").font(.system(size: 12, weight: .semibold))
                Spacer()
                if labels.count > 1 { Picker("Allowance", selection: $selected) { ForEach(labels, id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(maxWidth: 170) }
            }
            let visible = points.filter { $0.label == active }
            if visible.count < 2 {
                Text("History starts with your next fresh readings. No usage is estimated.").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(visible) { point in
                    LineMark(x: .value("Time", point.date), y: .value("Remaining", point.remaining), series: .value("Window", point.reset))
                        .foregroundStyle(Color.accentColor)
                    PointMark(x: .value("Time", point.date), y: .value("Remaining", point.remaining)).symbolSize(10).foregroundStyle(Color.accentColor)
                }.chartYScale(domain: 0...100).chartYAxisLabel("% left").chartLegend(.hidden).frame(height: 120)
                Text("\(visible.count) readings · gaps and resets can separate lines").font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
    }
}
struct ConnectionHelpView: View {
    let account: UsageAccount
    @ObservedObject var store: UsageStore
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(account.requiresSignIn == true ? "Reconnect this account" : "Check the connection", systemImage: "wrench.and.screwdriver")
                .font(.system(size: 12, weight: .semibold))
            Text(explanation).font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button(store.reconnecting ? "Opening…" : (account.requiresSignIn == true ? "Open sign-in" : "Open provider")) { store.reconnect(account) }
                    .disabled(store.reconnecting)
                Button("Check again") { store.refresh() }.disabled(store.refreshing)
                Button("Setup") { store.showSettings = true }
            }.controlSize(.small)
            if let message = store.message { Text(message).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
    }
    private var explanation: String {
        if account.requiresSignIn == true { return "The usage source is signed out. Complete sign-in on \(account.activeMachines.map(store.machineName).joined(separator: ", ")), then check again." }
        if account.quotas.contains(where: \.awaiting) { return "The reset time has passed. A new provider reading is needed to confirm the allowance." }
        return "The last reading is missing or old. Make sure the listed computer is awake and the provider is connected in CodexBar. Last-known values stay visible with their age."
    }
}
struct FullBoardView: View {
    @ObservedObject var store: UsageStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit()
                    .frame(width: 40, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("OVRCAST").font(.title.bold())
                    Text("\(store.available) available · \(store.nextReset)").foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.preferences.privacyMode.toggle() } label: { Image(systemName: store.preferences.privacyMode ? "eye.slash.fill" : "eye") }.help("Privacy mode")
                Button("Refresh") { store.refresh() }.disabled(store.refreshing)
                Button("Settings") { store.showSettings = true }
            }
            if let id = store.selectedAccount, let account = store.accounts.first(where: { $0.id == id }) {
                ScrollView { AccountDetail(account: account, store: store).frame(maxWidth: 600) }.frame(maxWidth: .infinity)
            } else {
                RecommendationView(store: store).frame(maxWidth: 430)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                        ForEach(store.visibleAccounts) { account in
                            Button { store.selectedAccount = account.id } label: { AccountRow(account: account, store: store, expanded: true) }.buttonStyle(.plain)
                        }
                    }
                    if store.accounts.isEmpty { ContentUnavailableView("Connect your first account", systemImage: "chart.bar", description: Text("Open Settings to choose your providers.")) }
                }
            }
        }.padding(24).frame(minWidth: 700, minHeight: 480).background(.background).preferredColorScheme(store.scheme)

    }
}
