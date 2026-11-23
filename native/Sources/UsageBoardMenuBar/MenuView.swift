import SwiftUI

struct Logo: View {
    let name: String
    var device = false
    var size: CGFloat = 24
    var body: some View {
        Group {
            if device {
                Image(systemName: MachineLabels.symbol(name))
                    .resizable().scaledToFit().fontWeight(.medium)
                    .symbolRenderingMode(.monochrome).foregroundStyle(.secondary)
            } else if let image = artwork(name) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Text(["Codex": "Cx", "Claude": "Cl", "Antigravity": "Ag"][name] ?? String(name.prefix(2)))
                    .font(.system(size: size * 0.4, weight: .semibold)).frame(width: size, height: size)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: size * 0.2))
            }
        }.frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: device ? 0 : size * 0.2)).accessibilityHidden(true)
    }
}
struct QuotaBar: View {
    let quota: Quota
    var compact = false
    var current = true
    private var presentation: QuotaPresentation { QuotaPresentation(quota, current: current) }
    private var tint: Color {
        guard presentation.state == .current else { return .secondary.opacity(0.65) }
        return quota.remaining < 15 ? .red : quota.remaining <= 40 ? .orange : .green
    }
    private var accessibilitySummary: String {
        guard !compact && current else { return presentation.accessibilityValue }
        let reset = resetLabel(quota.resetsAt)
        if let date = parsedDate(quota.resetsAt), !quota.awaiting {
            return "\(presentation.accessibilityValue); \(reset); \(resetLocalTime(date))"
        }
        return "\(presentation.accessibilityValue); \(reset)"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 7) {
            HStack {
                Text(quota.label).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 3)
                Text(presentation.value).fontWeight(.semibold).monospacedDigit().fixedSize()
                    .foregroundStyle(current ? Color.primary : Color.primary.opacity(0.72))
            }.font(.system(size: compact ? 10 : 11))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.07))
                    Capsule().fill(tint).frame(width: proxy.size.width * presentation.fraction)
                }
            }.frame(height: compact ? 5 : 6)
            if !compact && current {
                Text(resetLabel(quota.resetsAt)).font(.system(size: 10)).foregroundStyle(.secondary)
                if let date = parsedDate(quota.resetsAt), !quota.awaiting {
                    Text(resetLocalTime(date)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel(quota.label).accessibilityValue(accessibilitySummary)
            .help(current ? "Reported remaining allowance" : "Remaining allowance at the last reading; refresh before relying on it")
    }
}
struct AccountRow: View {
    let account: UsageAccount
    @ObservedObject var store: UsageStore
    var expanded = false
    private var historical: Bool { !account.current && !account.quotas.isEmpty }
    private var statusText: String {
        if historical { return "Last known · " + age(account.observedAt) }
        if account.current && !account.quotas.isEmpty { return account.shortStatus + " · " + age(account.observedAt) }
        return account.quotas.isEmpty && account.requiresSignIn != true ? "No reading" : account.shortStatus
    }
    private var devices: String { account.activeMachines.map(store.machineName).joined(separator: ", ") }
    private var statusColor: Color {
        guard account.current else { return .secondary }
        if account.requiresSignIn == true { return .orange }
        if account.quotas.isEmpty || account.quotas.contains(where: \.awaiting) { return .secondary }
        return account.color
    }
    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 11 : 9) {
            HStack(alignment: .top, spacing: 9) {
                Logo(name: account.provider, size: 24).padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.provider).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(store.accountName(account)).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        if let first = account.activeMachines.first { Logo(name: store.machineName(first), device: true, size: 12) }
                        Text(devices).lineLimit(1).truncationMode(.tail)
                    }.font(.system(size: 10)).foregroundStyle(.secondary).help(devices)
                    HStack(spacing: 4) {
                        if historical { Image(systemName: "clock").accessibilityHidden(true) }
                        Text(statusText)
                    }.font(.system(size: 9, weight: .medium)).monospacedDigit()
                        .foregroundStyle(statusColor)
                }.frame(maxWidth: 190, alignment: .trailing)
            }
            if expanded {
                ForEach(Array(account.quotas.enumerated()), id: \.offset) { _, quota in QuotaBar(quota: quota, current: account.current) }
                HStack {
                    Text(store.preferences.privacyMode ? "Plan hidden" : account.plan).lineLimit(1)
                    Spacer()
                    Text("Resets: \(account.savedResets.map(String.init) ?? "Unknown")")
                }.font(.system(size: 10)).foregroundStyle(.secondary)
            } else if account.quotas.count > 2 {
                VStack(spacing: 8) {
                    ForEach(Array(account.quotas.prefix(3).enumerated()), id: \.offset) { _, quota in
                        QuotaBar(quota: quota, compact: true, current: account.current)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(Array(account.quotas.prefix(3).enumerated()), id: \.offset) { _, quota in
                        QuotaBar(quota: quota, compact: true, current: account.current).frame(maxWidth: .infinity)
                    }
                    if account.quotas.isEmpty { Text("No quota reading").font(.system(size: 10)).foregroundStyle(.secondary) }
                }
            }
            if historical && account.requiresSignIn == true {
                Label("Sign in to refresh this account", systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 9)).foregroundStyle(.orange)
            } else if !expanded && account.current { ResetScheduleView(account: account) }
        }.padding(.horizontal, 13).padding(.vertical, expanded ? 13 : 9)
        .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06)))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
struct AccountDetail: View {
    let account: UsageAccount
    @ObservedObject var store: UsageStore
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Button { store.selectedAccount = nil } label: { Label("Back", systemImage: "chevron.left") }
                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            AccountRow(account: account, store: store, expanded: true)
            if !account.current || account.requiresSignIn == true || account.quotas.contains(where: \.awaiting) {
                ConnectionHelpView(account: account, store: store)
            }
            if store.preferences.showForecasts {
                ForEach(Array(account.quotas.enumerated()), id: \.offset) { _, quota in
                    if let forecast = CapacityForecast.estimate(account: account, quota: quota, history: store.history) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(quota.label + " · " + forecast.label).font(.caption)
                            Text("Based on recent local readings. Your pace can change.").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            AccountHistoryView(points: store.history.filter { $0.accountID == account.id })
            VStack(alignment: .leading, spacing: 8) {
                Text("Saved resets").font(.system(size: 12, weight: .semibold))
                Text(account.savedResets.map(String.init) ?? "Unknown").font(.system(size: 25, weight: .semibold)).monospacedDigit()
                ForEach(store.preferences.privacyMode ? [] : account.resetDetails, id: \.self) { Text($0).font(.system(size: 10)).foregroundStyle(.secondary) }
                if !account.current { Text("Last known inventory").font(.system(size: 10)).foregroundStyle(.secondary) }
            }
            Divider()
            Text("Credits & spending").font(.system(size: 12, weight: .semibold))
            ForEach(Array(account.credits.enumerated()), id: \.offset) { _, pool in
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(pool.name); Spacer(); Text(store.preferences.privacyMode ? "Hidden" : pool.value).fontWeight(.medium).multilineTextAlignment(.trailing) }
                        .font(.system(size: 11))
                    Text(store.preferences.privacyMode ? "Hidden in privacy mode" : pool.detail).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            if !store.preferences.privacyMode, let pace = account.pace { Divider(); Text(pace).font(.system(size: 11)).foregroundStyle(.secondary) }
            if !account.issue.isEmpty { Text(store.preferences.privacyMode ? "Connection needs attention" : account.issue).font(.system(size: 10)).foregroundStyle(.secondary) }
            Divider()
            Text("\(account.source) · \(age(account.observedAt))").font(.system(size: 10)).foregroundStyle(.secondary)
            Text("Saved resets and purchases are managed at the provider.").font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(3)
    }
}
struct MenuView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var updates = AppUpdates.shared
    let openBoard: () -> Void
    var maxHeight: CGFloat = 710
    var floating = false
    var toggleFloating: (() -> Void)? = nil
    private var selected: UsageAccount? { store.accounts.first { $0.id == store.selectedAccount } }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit()
                    .frame(width: 30, height: 30).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("OVRCAST").font(.system(size: 15, weight: .semibold))
                    Text(store.isDemo ? "Demo · example accounts" : floating ? "Drag the title bar to move" : "Every account. Every Mac.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                if let toggleFloating {
                    Button(action: toggleFloating) { Image(systemName: floating ? "pin.fill" : "pin") }
                        .buttonStyle(.plain)
                        .help(floating ? "Return to menu bar" : "Keep board open in a movable window")
                        .accessibilityLabel(floating ? "Return to menu bar" : "Float OVRCAST")
                }
                Button { store.preferences.privacyMode.toggle() } label: { Image(systemName: store.preferences.privacyMode ? "eye.slash.fill" : "eye") }
                    .buttonStyle(.plain).help("Hide account identities and balances").accessibilityLabel("Privacy mode")
                    .accessibilityValue(store.preferences.privacyMode ? "On" : "Off")
                if store.refreshing { ProgressView().controlSize(.small) }
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).help("Refresh usage").accessibilityLabel("Refresh usage")
                    .disabled(store.refreshing).keyboardShortcut("r", modifiers: .command)
                Menu {
                    Button("Check for Updates…") { updates.check() }.disabled(!updates.ready)
                    Button("Settings…") { store.showSettings = true }
                    Button("Token activity…") { store.showTokenActivity = true }
                    Button("Review support report…") { store.copySupportReport() }
                    Button("Export snapshot…") { store.exportSnapshot() }
                    Divider()
                    Button("Open full board", action: openBoard)
                    Button("Refresh readings") { store.refresh() }
                    Divider()
                    Button("Quit OVRCAST") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("More actions")
            }.padding(.horizontal, 17).padding(.top, 16).padding(.bottom, 12)
            HStack(spacing: 3) {
                ForEach(store.providers, id: \.self) { provider in
                    Button {
                        store.selectedProvider = provider
                        store.selectedAccount = nil
                    } label: {
                        HStack(spacing: 4) {
                            if provider != "Overview" { Logo(name: provider, size: 16) }
                            Text(provider).font(.system(size: 10, weight: store.selectedProvider == provider ? .semibold : .regular))
                        }.padding(.vertical, 7).frame(maxWidth: .infinity)
                        .background(store.selectedProvider == provider ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain).accessibilityValue(store.selectedProvider == provider ? "Selected" : "Not selected")
                }
            }.padding(.horizontal, 12).padding(.bottom, 11)
            if selected == nil {
                HStack {
                    let available = store.visibleAccounts.filter(\.available).count
                    Label(available > 0 ? "\(available) available" : store.visibleAccounts.contains(where: \.current) ? "0 available" : "No current readings", systemImage: "circle.fill")
                        .foregroundStyle(available > 0 ? Color.green : Color.secondary)
                    Spacer()
                    Text("\(store.visibleAccounts.count) of \(store.accounts.count)").foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(store.visibleResetAccounts.isEmpty ? "Saved resets unknown" : "\(store.visibleResetTotal) saved reset\(store.visibleResetTotal == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                        .help("\(store.visibleResetAccounts.count) visible accounts report current saved-reset inventory")
                    Menu {
                        Picker("Machine", selection: $store.machineFilter) {
                            Text("All machines").tag("")
                            ForEach(store.machineOptions, id: \.self) { Text(store.machineName($0)).tag($0) }
                        }
                        Picker("Status", selection: $store.statusFilter) {
                            ForEach(AccountFilter.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        Divider()
                        Picker("Sort", selection: $store.accountOrder) {
                            ForEach(AccountOrder.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        if store.accountOrder == .machine {
                            Picker("First machine", selection: $store.firstMachine) {
                                ForEach(store.machineOptions, id: \.self) { Text("\(store.machineName($0)) first").tag($0) }
                            }
                        }
                        Divider()
                        Button("Reset filters & order") { store.resetFilters() }
                            .disabled(!store.filtersActive)
                    } label: {
                        Image(systemName: store.filtersActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(store.filtersActive ? Color.accentColor : .secondary)
                    }.menuStyle(.borderlessButton).fixedSize()
                        .accessibilityLabel("Filter and sort accounts")
                        .help("Filter by machine or status; sort by usage left, machine or next reset")
                }.font(.system(size: 10)).padding(.horizontal, 17).padding(.bottom, 10)
            }
            if selected == nil {
                RecommendationView(store: store).padding(.horizontal, 12).padding(.bottom, 8)
            }
            ScrollView {
                VStack(spacing: 6) {
                    if let selected {
                        AccountDetail(account: selected, store: store)
                    } else if store.visibleAccounts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray").font(.title).foregroundStyle(.secondary)
                            Text(store.accounts.isEmpty ? "Waiting for usage readings" : "No matching accounts").font(.system(size: 12, weight: .medium))
                            if store.accounts.isEmpty {
                                Button("Connect accounts") { store.showSettings = true }.font(.system(size: 11)).foregroundStyle(.secondary)
                            } else {
                                Button("Reset filters") { store.resetFilters(); store.selectedProvider = "Overview" }
                                    .font(.system(size: 11)).buttonStyle(.plain)
                            }
                        }.frame(maxWidth: .infinity).padding(.vertical, 50)
                    } else {
                        ForEach(store.visibleAccounts) { account in
                            Button { store.selectedAccount = account.id } label: {
                                AccountRow(account: account, store: store, expanded: store.selectedProvider != "Overview")
                            }.buttonStyle(.plain).help("Account details for \(store.accountName(account))")
                        }
                    }
                    if let message = store.message, store.accounts.isEmpty {
                        Text(message).font(.system(size: 10)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(5)
                    }
                }.padding(.horizontal, 12).padding(.bottom, 10)
            }.scrollIndicators(.automatic)
            Divider()
            HStack {
                Button(action: openBoard) { Label("Full board", systemImage: "arrow.up.right.square") }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                Spacer()
                Picker("Appearance", selection: $store.theme) {
                    Text("Auto").tag("system"); Text("Day").tag("day"); Text("Night").tag("night")
                }.pickerStyle(.segmented).labelsHidden().frame(width: 135).controlSize(.mini)
                Text(age(store.generatedAt)).font(.system(size: 9)).foregroundStyle(.secondary)
            }.padding(.horizontal, 16).padding(.vertical, 11)
        }.frame(width: 430, height: maxHeight)
        .background(store.theme == "night" ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .controlBackgroundColor))
        .preferredColorScheme(store.scheme)
    }
}
