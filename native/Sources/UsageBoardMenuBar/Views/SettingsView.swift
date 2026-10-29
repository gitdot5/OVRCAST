import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @State private var remoteName = ""
    @State private var remoteAlias = ""
    @State private var selectedTab = "connect"
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
            }
            HStack(spacing: 3) {
                ForEach(["connect", "appearance", "alerts", "computers", "about"], id: \.self) { tab in
                    Button { selectedTab = tab } label: {
                        Text(["connect": "Connect", "appearance": "Personalize", "alerts": "Alerts", "computers": "Computers", "about": "About"][tab] ?? tab)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain).accessibilityValue(selectedTab == tab ? "Selected" : "")
                }
            }
            Group {
                switch selectedTab {
                case "appearance": appearance
                case "alerts": alerts
                case "computers": computers
                case "about": about
                default: connection
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            if let message = store.message { Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            HStack {
                Button("Copy support report") { store.copySupportReport() }.controlSize(.small)
                Spacer()
                if !store.preferences.setupComplete {
                    Button("Open my board") {
                        store.preferences.setupComplete = true
                        store.preferences.nativeCollection = true
                        store.showSettings = false
                        store.refresh()
                    }.buttonStyle(.borderedProminent).disabled(!helperAvailable || store.preferences.providers.isEmpty)
                } else { Button("Done") { store.showSettings = false }.keyboardShortcut(.defaultAction) }
            }
        }.padding(22).frame(width: 540, height: 530).background(.background).preferredColorScheme(store.scheme)
    }
    private var connection: some View {
        Form {
            Section("1 · Connect a usage source") {
                Label(helperAvailable ? "CodexBar detected on this Mac" : "Install the free CodexBar companion", systemImage: helperAvailable ? "checkmark.circle.fill" : "arrow.down.app")
                    .foregroundStyle(helperAvailable ? .green : .secondary)
                Text("OVRCAST reads the accounts you connect in CodexBar. No OVRCAST account or subscription is needed.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(helperAvailable ? "Open CodexBar" : "Get CodexBar") {
                        let app = URL(fileURLWithPath: "/Applications/CodexBar.app")
                        NSWorkspace.shared.open(FileManager.default.fileExists(atPath: app.path) ? app : URL(string: "https://github.com/steipete/CodexBar/releases/latest")!)
                    }
                    Button("Check connection") { store.refresh() }.disabled(store.refreshing)
                }
            }
            Section("2 · Choose what to track") {
                HStack(spacing: 18) {
                    ForEach(["Codex", "Claude", "Antigravity"], id: \.self) { provider in
                        Toggle(provider, isOn: Binding(get: { store.preferences.providers.contains(provider) }, set: { on in
                            if on { store.preferences.providers.append(provider) }
                            else { store.preferences.providers.removeAll { $0 == provider } }
                        }))
                    }
                }
                Text("Codex and Claude use CLI sources. Sign-in stays with your provider; OVRCAST never asks you to paste a token.").font(.caption).foregroundStyle(.secondary)
                if !store.preferences.privacyMode { TextField("This computer", text: $store.preferences.machineName) }
                if store.hasLegacyCollector {
                    Toggle("Use built-in collection", isOn: $store.preferences.nativeCollection)
                    Text("Your existing collector is active until you choose built-in collection. Switching changes which readings this app displays.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.formStyle(.grouped)
    }
    private var appearance: some View {
        Form {
            Picker("Appearance", selection: $store.theme) {
                Text("System").tag("system"); Text("Day").tag("day"); Text("Night").tag("night")
            }.pickerStyle(.segmented)
            Toggle("Privacy mode", isOn: $store.preferences.privacyMode)
            Text("Hide account identities, aliases, computer names and balances throughout the board.").font(.caption).foregroundStyle(.secondary)
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
                    Text("Created by Git · Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.2")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Free and open source · MIT licensed").font(.headline)
            Text("An independent app. Usage collection is powered by the separately installed CodexBar CLI, which also inspired parts of the allowance display.").font(.caption)
            Text("No OVRCAST server, analytics or subscription.").font(.caption).foregroundStyle(.secondary)
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
