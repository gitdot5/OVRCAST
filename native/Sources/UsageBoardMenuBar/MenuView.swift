import SwiftUI

struct Logo: View {
    let name: String
    var device = false
    var size: CGFloat = 24
    var body: some View {
        Group {
            if let image = artwork(name, device: device) {
                Image(nsImage: image).resizable().scaledToFit()
            } else if device {
                Image(systemName: ["MacBook": "laptopcomputer", "Mini": "macmini", "Studio": "macstudio"][name] ?? "desktopcomputer").foregroundStyle(.secondary)
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
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack {
                Text(quota.label).lineLimit(1)
                Spacer(minLength: 3)
                Text(quota.awaiting ? "Pending" : "\(Int(quota.remaining.rounded()))% left")
                    .fontWeight(.medium).monospacedDigit()
            }.font(.system(size: compact ? 9 : 11))
            if !quota.awaiting {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule().fill(quota.remaining < 15 ? Color.red : quota.remaining <= 40 ? Color.orange : Color.green)
                            .frame(width: proxy.size.width * max(0, min(100, quota.remaining)) / 100)
                    }
                }.frame(height: compact ? 3 : 5)
            }
            if !compact { Text(resetLabel(quota.resetsAt)).font(.system(size: 10)).foregroundStyle(.secondary) }
        }.accessibilityElement(children: .combine)
    }
}
struct AccountRow: View {
    let account: UsageAccount
    @ObservedObject var store: UsageStore
    var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Logo(name: account.provider, size: 25)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(account.provider).font(.system(size: 11, weight: .semibold))
                        ForEach(account.activeMachines, id: \.self) { machine in
                            Logo(name: machine, device: true, size: expanded ? 19 : 13)
                            Text(store.machineName(machine)).font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 3)
                    }
                    Text(store.accountName(account)).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
                VStack(alignment: .trailing, spacing: 3) {
                    Text(account.shortStatus).font(.system(size: 9, weight: .medium)).foregroundStyle(account.color)
                    Text(account.quotas.isEmpty && !account.current ? "No reading" : age(account.observedAt))
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            if expanded {
                ForEach(Array(account.quotas.enumerated()), id: \.offset) { _, quota in QuotaBar(quota: quota) }
                HStack {
                    Text(store.preferences.privacyMode ? "Plan hidden" : account.plan).lineLimit(1)
                    Spacer()
                    Text("Resets: \(account.savedResets.map(String.init) ?? "Unknown")")
                }.font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(account.quotas.prefix(3).enumerated()), id: \.offset) { _, quota in
                        QuotaBar(quota: quota, compact: true).frame(maxWidth: .infinity)
                    }
                    if account.quotas.isEmpty { Text("No quota reading").font(.system(size: 10)).foregroundStyle(.secondary) }
                }
            }
        }.padding(.horizontal, 12).padding(.vertical, expanded ? 12 : 5)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.06)))
        .contentShape(RoundedRectangle(cornerRadius: 10))
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
                if store.refreshing { ProgressView().controlSize(.small) }
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).help("Refresh usage").accessibilityLabel("Refresh usage")
                Menu {
                    Button("Settings…") { store.showSettings = true }
                    Button("Copy support report") { store.copySupportReport() }
                    Button("Export snapshot…") { store.exportSnapshot() }
                    Divider()
                    Button("Open full board", action: openBoard)
                    Button("Refresh readings") { store.refresh() }
                    Divider()
                    Button("Quit OVRCAST") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize()
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
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 12).padding(.bottom, 11)
            if selected == nil {
                HStack {
                    Label("\(store.visibleAccounts.filter(\.available).count) available", systemImage: "circle.fill").foregroundStyle(.green)
                    Spacer()
                    Text("\(store.visibleAccounts.count) of \(store.accounts.count)").foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(store.visibleResetAccounts.isEmpty ? "Resets unknown" : "\(store.visibleResetTotal) reset\(store.visibleResetTotal == 1 ? "" : "s")")
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
