import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var updates = AppUpdates.shared
    @State private var remoteName = ""
    @State private var remoteAlias = ""
    @State private var selectedTab: String = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--settings-tab"), args.indices.contains(i + 1) else { return "connect" }
        return args[i + 1]
    }()
    private var helperAvailable: Bool { NativeCollector.helper != nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit()
                    .frame(width: 44, height: 44).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.preferences.setupComplete ? "Make it yours" : "Welcome to OVRCAST").font(.title2.weight(.semibold))
                    Text("Your AI capacity, at a glance.").foregroundStyle(.secondary).font(.callout)
                }
                Spacer()
                Button { store.showSettings = false } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
                    .accessibilityLabel("Close settings").keyboardShortcut(.cancelAction)
            }
            HStack(spacing: 3) {
                ForEach(["connect", "health", "appearance", "alerts", "computers", "about"], id: \.self) { tab in
                    Button { selectedTab = tab } label: {
                        Text(["health": "Health", "connect": "Connect", "appearance": "Personalize", "alerts": "Alerts", "computers": "Computers", "about": "About"][tab] ?? tab)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain).accessibilityValue(selectedTab == tab ? "Selected" : "")
                }
            }
            Group {
                switch selectedTab {
                case "health": health
                case "appearance": appearance
                case "alerts": alerts
                case "computers": computers
                case "about": about
                default: connection
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            if let issue = store.storageIssue { Label(issue, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange).lineLimit(2) }
            if let message = store.message { Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            HStack {
                Button("Review support report…") { store.copySupportReport() }.controlSize(.small)
                Spacer()
                if !store.preferences.setupComplete {
                    Button("Open my board") { store.finishSetup() }
                        .buttonStyle(.borderedProminent).disabled(!store.canFinishSetup).keyboardShortcut(.defaultAction)
                } else { Button("Done") { store.showSettings = false }.keyboardShortcut(.defaultAction) }
            }
        }.padding(22).frame(width: 540, height: 530).background(.background).preferredColorScheme(store.scheme)
    }
    private var connection: some View {
        Form {
            Section("1 · Choose your providers") {
                HStack(spacing: 18) {
                    ForEach(["Codex", "Claude", "Antigravity"], id: \.self) { provider in
                        Toggle(provider, isOn: Binding(get: { store.preferences.providers.contains(provider) }, set: { on in
                            if on { store.preferences.providers.append(provider) }
                            else { store.preferences.providers.removeAll { $0 == provider } }
                        })).toggleStyle(.checkbox)
                    }
                }
                Text("Each person connects their own accounts. No credentials or usage allowance are supplied with OVRCAST.").font(.caption).foregroundStyle(.secondary)
            }
            Section("2 · Connect and verify") {
                Label(helperAvailable ? "Built-in collector ready" : "Collector missing — reinstall OVRCAST", systemImage: helperAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle")
                    .foregroundStyle(helperAvailable ? .green : .orange)
                ForEach(store.preferences.providers, id: \.self) { provider in
                    HStack {
                        Logo(name: provider, size: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(provider).fontWeight(.medium)
                            Text((store.health[provider] ?? ConnectionHealth()).displayState().title).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Connect") { store.connectProvider(provider) }.controlSize(.small)
                        Button("Check") { store.refresh(provider: provider) }.controlSize(.small).disabled(store.refreshing || !helperAvailable)
                    }
                }
                Text("Complete sign-in in the provider software, then Check. Claude requires Claude Code OAuth. Opening sign-in alone does not verify a connection.").font(.caption).foregroundStyle(.secondary)
                if !store.preferences.setupComplete {
                    Text(store.canFinishSetup ? "Verified: " + store.verifiedProviders.joined(separator: ", ") + ". You can open your board." : "Receive at least one current usage reading to finish setup. You can connect other providers later.")
                        .font(.caption).foregroundStyle(store.canFinishSetup ? .green : .secondary)
                }
                if !helperAvailable { Link("Download OVRCAST", destination: URL(string: "https://github.com/gitdot5/OVRCAST/releases")!) }
            }
            Section("This Mac") {
                if !store.preferences.privacyMode { TextField("Computer name", text: $store.preferences.machineName) }
                if store.hasLegacyCollector {
                    Toggle("Use built-in collection", isOn: $store.preferences.nativeCollection)
                    Text("Switching changes which readings this app displays.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.formStyle(.grouped)
    }
    private var health: some View {
        Form {
            Section("Provider connections on this Mac") {
                ForEach(store.preferences.providers, id: \.self) { provider in
                    healthRow(title: provider, value: store.health[provider] ?? ConnectionHealth()) {
                        store.refresh(provider: provider)
                    }
                }
            }
            if !store.preferences.remotes.isEmpty {
                Section("Other Macs") {
                    ForEach(store.preferences.remotes) { remote in
                        healthRow(title: store.machineName(remote.name), value: store.health["remote:" + remote.id] ?? ConnectionHealth()) { store.refresh() }
                    }
                }
            }
            Text("Automatic retries slow down to at most once every 30 minutes after repeated failures. Retry bypasses the delay. Support reports include only structured connection states.").font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }
    private func healthRow(title: String, value: ConnectionHealth, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(title).fontWeight(.medium); Spacer(); Text(value.displayState().title).foregroundStyle(.secondary); Button("Retry", action: retry).disabled(store.refreshing).controlSize(.small) }
            Text(value.displayState().guidance).font(.caption).foregroundStyle(.secondary)
            Text("Last successful reading: " + (value.lastSuccess.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "None yet")).font(.caption2).foregroundStyle(.secondary)
            if let retryAt = value.retryAt, value.failures > 0 {
                Text("Next automatic retry: " + retryAt.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 3)
    }
    private var appearance: some View {
        Form {
            Picker("Appearance", selection: $store.theme) {
                Text("System").tag("system"); Text("Day").tag("day"); Text("Night").tag("night")
            }.pickerStyle(.segmented)
            Toggle("Show capacity in the menu bar", isOn: $store.preferences.compactMenuBar)
            Picker("Menu-bar provider", selection: $store.preferences.recommendationProvider) {
                ForEach(["Codex", "Claude", "Antigravity"], id: \.self) { Text($0).tag($0) }
            }
            Toggle("Show local usage forecasts", isOn: $store.preferences.showForecasts)
            Text("Forecasts need at least three recent readings over 15 minutes in the same reset window. They are estimates at your recent pace, not guaranteed task capacity.").font(.caption).foregroundStyle(.secondary)
            Toggle("Privacy mode", isOn: $store.preferences.privacyMode)
            Text("Hides account identities, balances and custom computer names. Mac types stay visible.").font(.caption).foregroundStyle(.secondary)
            Toggle("Show or hide with ⌘⇧U", isOn: $store.preferences.shortcutEnabled)
            Text(store.shortcutStatus).font(.caption).foregroundStyle(.secondary)
            Section("Friendly account names") {
                if store.preferences.privacyMode { Text("Turn privacy mode off to edit account aliases.").foregroundStyle(.secondary) }
                else if store.accounts.isEmpty { Text("Connect an account first.").foregroundStyle(.secondary) }
                else {
                    ForEach(store.accounts) { account in
                        TextField(account.email, text: Binding(get: { store.preferences.aliases[account.id] ?? "" }, set: { store.preferences.aliases[account.id] = $0 }))
                            .help("A local nickname for \(account.provider)")
                    }
                }
            }
        }.formStyle(.grouped)
    }
    private var alerts: some View {
        Form {
            Toggle("Usage, reset and credit expiry alerts", isOn: Binding(get: { store.preferences.notifications }, set: { store.enableNotifications($0) }))
            Button("Send a test alert") { Task { store.message = await Notifications.test() } }.disabled(!store.preferences.notifications)
            Text("Alerts omit account identities and balances. A repeated reading does not notify again; reset alerts require a new provider reading.").font(.caption).foregroundStyle(.secondary)
            Picker("Warn when remaining usage crosses", selection: $store.preferences.lowThreshold) {
                Text("10%").tag(10.0); Text("15%").tag(15.0); Text("25%").tag(25.0)
            }
            HStack {
                Picker("Quiet from", selection: $store.preferences.quietStart) { ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) } }
                Picker("Until", selection: $store.preferences.quietEnd) { ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) } }
            }
            Text("Uses this Mac’s local time. Equal times disable quiet hours.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Snooze for 1 hour") { store.preferences.snoozeUntil = Date().addingTimeInterval(3600) }
                if let until = store.preferences.snoozeUntil, until > Date() {
                    Text("Until \(until.formatted(date: .omitted, time: .shortened))").font(.caption)
                    Button("Resume") { store.preferences.snoozeUntil = nil }
                }
            }
        }.formStyle(.grouped)
    }
    private var computers: some View {
        Form {
            Text("Install OVRCAST on the other Mac and connect its providers. It publishes an owner-only usage snapshot while running.").font(.callout)
            Text("Connect using an SSH alias you already trust. OVRCAST never copies sign-in credentials or approves new host keys.").font(.caption).foregroundStyle(.secondary)
            if store.preferences.privacyMode { Text("Turn privacy mode off to manage computers.").foregroundStyle(.secondary) }
            else {
                ForEach(store.preferences.remotes) { remote in
                    HStack {
                        Image(systemName: "desktopcomputer")
                        VStack(alignment: .leading) { Text(remote.name); Text(remote.status).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Button("Remove") { store.preferences.remotes.removeAll { $0.id == remote.id }; store.refresh() }.controlSize(.small)
                    }
                }
                TextField("Computer name", text: $remoteName)
                TextField("Existing SSH alias", text: $remoteAlias)
                HStack {
                    Button("Add computer") {
                        store.preferences.remotes.append(RemoteMachine(name: remoteName.trimmingCharacters(in: .whitespaces), sshAlias: remoteAlias))
                        remoteName = ""; remoteAlias = ""
                        store.refresh()
                    }.disabled(!store.nativeMode || !RemoteMachine(name: remoteName, sshAlias: remoteAlias).valid || store.preferences.remotes.contains { $0.sshAlias == remoteAlias })
                    Button("Check computers") { store.refresh() }.disabled(store.refreshing)
                }
                if !store.nativeMode { Text("Your existing fleet is managed by its collector. Enable built-in collection in Connect to manage computers here.").font(.caption).foregroundStyle(.secondary) }
            }
        }.formStyle(.grouped)
    }
    private var about: some View {
        Form {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit().frame(width: 56, height: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("OVRCAST").font(.title2.weight(.semibold))
                    Text("Your AI capacity, at a glance.").foregroundStyle(.secondary)
                    Text("Created by Git · Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Free and open source · MIT licensed").font(.headline)
            Text("An independent app. Includes an OVRCAST-maintained collector derived from CodexBar’s MIT-licensed code. No separate CodexBar installation is needed.").font(.caption)
            Section("Updates") {
                Button("Check for Updates…") { updates.check() }.disabled(!updates.ready)
                Toggle("Automatically check for updates", isOn: $updates.automaticChecks).disabled(!updates.ready)
                Toggle("Automatically download and install updates", isOn: $updates.automaticInstall).disabled(!updates.ready || !updates.automaticChecks)
                Text(updates.status).font(.caption).foregroundStyle(.secondary)
                Link("Release notes and manual recovery", destination: URL(string: "https://github.com/gitdot5/OVRCAST/releases")!)
                Text("Updates use signed packages and a signed feed on GitHub. Provider usage and credentials are not sent with update checks.").font(.caption).foregroundStyle(.secondary)
            }
            Text("No OVRCAST usage server, analytics or subscription.").font(.caption).foregroundStyle(.secondary)
            Text("Quotas, saved resets and credit pools depend on what each source reports. Unknown does not mean zero.").foregroundStyle(.secondary)
            Text("History keeps seven days of local readings. Account recommendations compare reported headroom within the selected provider; they do not predict whether a task will finish.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("MIT license") { showNotice("LICENSE") }
                Button("Third-party credits") { showNotice("THIRD_PARTY_NOTICES.md") }
                Link("CodexBar", destination: URL(string: "https://github.com/steipete/CodexBar")!)
            }
        }.formStyle(.grouped)
    }
    private func showNotice(_ filename: String) {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent(filename) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"), configuration: configuration)
    }
}
