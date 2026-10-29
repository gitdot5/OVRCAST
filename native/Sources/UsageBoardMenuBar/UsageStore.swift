import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class UsageStore: ObservableObject {
    static let shared = UsageStore()
    @Published var accounts: [UsageAccount] = []
    @Published var generatedAt: String?
    @Published var message: String?
    @Published var refreshing = false
    @Published var reconnecting = false
    @Published var selectedProvider = "Overview"
    @Published var selectedAccount: String?
    @Published var showSettings = false { didSet { onSettingsChanged?(showSettings) } }
    @Published var showRepair = false
    @Published var shortcutStatus = "⌘⇧U to show or hide the board"
    @Published var history: [HistoryPoint] = []
    @Published var preferences: BoardPreferences { didSet {
        if !isDemo { try? PrivateFiles.write(preferences, to: dataDirectory.appendingPathComponent("preferences.json")) }
        onPreferencesChanged?()
    } }
    @Published var machineFilter: String { didSet { defaults.set(machineFilter, forKey: "machineFilter"); selectedAccount = nil } }
    @Published var statusFilter: AccountFilter { didSet { defaults.set(statusFilter.rawValue, forKey: "statusFilter"); selectedAccount = nil } }
    @Published var accountOrder: AccountOrder { didSet { defaults.set(accountOrder.rawValue, forKey: "accountOrder"); selectedAccount = nil } }
    @Published var firstMachine: String { didSet { defaults.set(firstMachine, forKey: "firstMachine"); selectedAccount = nil } }
    @Published var theme: String { didSet { defaults.set(theme, forKey: "appearance"); onPreferencesChanged?() } }
    let root: URL
    let dataDirectory: URL
    let isDemo: Bool
    let hasLegacyCollector: Bool
    private let defaults: UserDefaults
    private var lastPoll = Date.distantPast
    private var notified: [String: Date] = [:]
    private var remoteCache: [String: [UsageAccount]] = [:]
    var timer: Timer?
    var onChange: (() -> Void)?
    var onPreferencesChanged: (() -> Void)?
    var onSettingsChanged: ((Bool) -> Void)?
    var legacyLocalMachine: String {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("config.local.json")),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let machines = config["machines"] as? [String: [String: Any]] else { return "MacBook" }
        return machines.first { $0.value["local_path"] != nil }?.key ?? "MacBook"
    }
    var floatingBoard: Bool {
        get { defaults.bool(forKey: "floatingBoard") }
        set { defaults.set(newValue, forKey: "floatingBoard") }
    }
    var nativeMode: Bool { preferences.nativeCollection || !hasLegacyCollector }
    var scheme: ColorScheme? { theme == "system" ? nil : theme == "night" ? .dark : .light }
    var available: Int { accounts.filter(\.available).count }
    var reportingResets: [UsageAccount] { accounts.filter { $0.current && $0.savedResets != nil } }
    var resetTotal: Int { reportingResets.compactMap(\.savedResets).reduce(0, +) }
    var providers: [String] { ["Overview"] + ["Codex", "Claude", "Antigravity", "Claude Platform"].filter { p in accounts.contains { $0.provider == p } } }
    var machineOptions: [String] { AccountList.machines(accounts) }
    var filtersActive: Bool { !machineFilter.isEmpty || statusFilter != .all || accountOrder != .attention }
    var visibleAccounts: [UsageAccount] {
        AccountList.apply(accounts, provider: selectedProvider, machine: machineFilter, status: statusFilter, order: accountOrder, firstMachine: firstMachine)
    }
    var visibleResetAccounts: [UsageAccount] { visibleAccounts.filter { $0.current && $0.savedResets != nil } }
    var visibleResetTotal: Int { visibleResetAccounts.compactMap(\.savedResets).reduce(0, +) }
    var recommendation: Recommendation? {
        Insights.recommend(visibleAccounts, provider: selectedProvider == "Overview" ? preferences.recommendationProvider : selectedProvider,
                           window: preferences.recommendationWindow)
    }
    var nextReset: String {
        let reset = visibleAccounts.filter(\.current).flatMap(\.quotas).filter { !$0.awaiting }.compactMap { parsedDate($0.resetsAt) }.min()
        return reset.map { resetLabel(ISO8601DateFormatter().string(from: $0)) } ?? "No current reset time"
    }
    func accountName(_ account: UsageAccount) -> String {
        if preferences.privacyMode { return "Account \((accounts.map(\.id).sorted().firstIndex(of: account.id) ?? 0) + 1)" }
        let alias = preferences.aliases[account.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return alias.isEmpty ? account.email : alias
    }
    func machineName(_ machine: String) -> String {
        preferences.privacyMode ? "Mac \((machineOptions.sorted().firstIndex(of: machine) ?? 0) + 1)" : machine
    }
    func resetFilters() { machineFilter = ""; statusFilter = .all; accountOrder = .attention; firstMachine = "MacBook" }
    init(defaults: UserDefaults = .standard, root: URL? = nil, dataDirectory: URL? = nil, demo: Bool = CommandLine.arguments.contains("--demo")) {
        isDemo = demo
        self.defaults = demo ? UserDefaults(suiteName: "com.weekthink.usageboard.demo")! : defaults
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.root = root ?? home.appendingPathComponent("usage_board")
        self.dataDirectory = dataDirectory ?? home.appendingPathComponent("Library/Application Support/UsageBoard/App")
        hasLegacyCollector = !demo && FileManager.default.fileExists(atPath: self.root.appendingPathComponent("config.local.json").path)
        var initialPreferences = demo ? BoardPreferences() : PrivateFiles.read(BoardPreferences.self, from: self.dataDirectory.appendingPathComponent("preferences.json")) ?? BoardPreferences()
        if hasLegacyCollector { initialPreferences.setupComplete = true }
        preferences = initialPreferences
        machineFilter = self.defaults.string(forKey: "machineFilter") ?? ""
        statusFilter = AccountFilter(rawValue: self.defaults.string(forKey: "statusFilter") ?? "") ?? .all
        accountOrder = AccountOrder(rawValue: self.defaults.string(forKey: "accountOrder") ?? "") ?? .attention
        firstMachine = self.defaults.string(forKey: "firstMachine") ?? "MacBook"
        theme = self.defaults.string(forKey: "appearance") ?? "system"
        if !demo {
            history = PrivateFiles.read([HistoryPoint].self, from: self.dataDirectory.appendingPathComponent("history.json")) ?? []
            notified = PrivateFiles.read([String: Date].self, from: self.dataDirectory.appendingPathComponent("alerts.json")) ?? [:]
        }
    }
    func start() {
        load()
        if !preferences.setupComplete && !isDemo { showSettings = true }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.load()
                if self.nativeMode && self.preferences.setupComplete && Date().timeIntervalSince(self.lastPoll) > 180 { self.refresh() }
            }
        }
        if nativeMode && preferences.setupComplete && !isDemo { refresh() }
    }
    func load() {
        if isDemo { if accounts.isEmpty { apply(DemoData.snapshot()) }; return }
        let url = nativeMode ? dataDirectory.appendingPathComponent("overview.json") : root.appendingPathComponent("state/overview.json")
        if let data = try? Data(contentsOf: url), let snapshot = try? SnapshotValidation.decode(data) { apply(snapshot) }
        else if preferences.setupComplete { message = "No saved reading yet. Check the connection to collect usage." }
        onChange?()
    }
    private func apply(_ snapshot: UsageSnapshot) {
        let previous = accounts
        accounts = snapshot.accounts; generatedAt = snapshot.generatedAt
        for remote in preferences.remotes where remoteCache[remote.id] == nil {
            remoteCache[remote.id] = accounts.filter { $0.machines.contains(remote.name) }
        }
        if !accounts.isEmpty {
            if !machineFilter.isEmpty && !machineOptions.contains(machineFilter) { machineFilter = "" }
            if !machineOptions.contains(firstMachine) { firstMachine = machineOptions.first ?? "MacBook" }
        }
        history = Insights.history(history, accounts: accounts)
        if !isDemo {
            try? PrivateFiles.write(history, to: dataDirectory.appendingPathComponent("history.json"))
            // Publish only readings owned by this Mac, avoiding remote snapshot loops.
            if !nativeMode {
                var local = snapshot
                local.accounts = snapshot.accounts.filter { $0.machines.contains(legacyLocalMachine) }.map { old in
                    var copy = old; copy.machines = [legacyLocalMachine]; return copy
                }
                try? PrivateFiles.write(local, to: dataDirectory.deletingLastPathComponent().appendingPathComponent("native-overview.json"))
            }
            let now = Date()
            notified = notified.filter { now.timeIntervalSince($0.value) < 7 * 86400 }
            let candidates = AlertRules.changes(from: previous, to: accounts, threshold: preferences.lowThreshold)
            let quiet = AlertRules.quiet(hour: Calendar.current.component(.hour, from: now), start: preferences.quietStart, end: preferences.quietEnd)
            for alert in candidates where notified[alert.id] == nil {
                notified[alert.id] = now
                if preferences.notifications && !quiet && (preferences.snoozeUntil ?? .distantPast) <= now { Notifications.deliver(alert) }
            }
            try? PrivateFiles.write(notified, to: dataDirectory.appendingPathComponent("alerts.json"))
        }
        onChange?()
    }
    func refresh(collect: Bool = true) {
        guard !refreshing else { return }
        if isDemo { message = "Demo data — no accounts connected"; return }
        if nativeMode { refreshNative(); return }
        refreshing = true; message = "Refreshing usage…"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-I", root.appendingPathComponent("gather.py").path, "--quiet"] + (collect ? ["--refresh"] : [])
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self else { return }
                self.refreshing = false; self.load()
                self.message = process.terminationStatus == 0 ? "Refresh requested. Readings can take up to 3 minutes." : "Refresh failed. Open connection help to check the source."
            }
        }
        do { try process.run() } catch { refreshing = false; message = "Could not start the usage refresh. Open connection help." }
    }
    private func refreshNative() {
        guard let helper = NativeCollector.helper else { message = "Install CodexBar, then use Check connection in Settings."; showSettings = true; return }
        refreshing = true; lastPoll = Date(); message = "Checking selected providers…"
        let providers = preferences.providers, machine = preferences.machineName, remotes = preferences.remotes
        Task {
            let local = await withTaskGroup(of: [UsageAccount].self) { group in
                for provider in providers { group.addTask { NativeCollector.collect(provider: provider, machine: machine, helper: helper) } }
                var rows: [UsageAccount] = []; for await row in group { rows += row }; return rows
            }
            var combined: [UsageAccount] = []
            for provider in providers {
                let readings = local.filter { $0.provider == provider }
                if readings.allSatisfy({ !$0.fresh }), !readings.isEmpty {
                    let retained = accounts.filter { $0.provider == provider && $0.machines.contains(machine) }
                    combined += retained.isEmpty ? readings : retained.map { old in
                        var copy = old; copy.fresh = false; copy.issue = readings[0].issue; copy.requiresSignIn = readings[0].requiresSignIn; return copy
                    }
                } else { combined += readings }
            }
            let localSnapshot = UsageSnapshot(version: 1, generatedAt: ISO8601DateFormatter().string(from: Date()), accounts: combined)
            try? PrivateFiles.write(localSnapshot, to: dataDirectory.deletingLastPathComponent().appendingPathComponent("native-overview.json"))
            for remote in remotes {
                let result = await Task.detached(priority: .utility) { try? NativeCollector.remote(remote) }.value
                if let result { remoteCache[remote.id] = result; combined += result }
                else { combined += (remoteCache[remote.id] ?? []).map { old in var copy = old; copy.fresh = false; copy.issue = "Computer unavailable. Check its connection in Settings."; return copy } }
                if let index = preferences.remotes.firstIndex(where: { $0.id == remote.id }) {
                    preferences.remotes[index].status = result == nil ? "Unavailable" : "Connected"
                    preferences.remotes[index].checkedAt = ISO8601DateFormatter().string(from: Date())
                }
            }
            let snapshot = UsageSnapshot(version: 1, generatedAt: ISO8601DateFormatter().string(from: Date()), accounts: NativeCollector.merge(combined))
            try? PrivateFiles.write(snapshot, to: dataDirectory.appendingPathComponent("overview.json"))
            apply(snapshot); refreshing = false
            message = snapshot.accounts.contains { !$0.current } ? "Some accounts need attention. Open an account for connection help." : "Usage is up to date."
        }
    }
    func enableNotifications(_ enabled: Bool) {
        guard enabled else { preferences.notifications = false; return }
        Task {
            let allowed = await Notifications.request()
            preferences.notifications = allowed
            if !allowed { message = "Allow OVRCAST notifications in System Settings to enable alerts." }
        }
    }
    func exportSnapshot() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "usage-board-snapshot.json"
        panel.allowedContentTypes = [.json]
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url, let self else { return }
            var rows = self.accounts
            if self.preferences.privacyMode {
                rows = rows.enumerated().map { index, old in
                    var copy = old
                    copy.id = "account-\(index + 1)"; copy.email = self.accountName(old)
                    copy.machines = old.machines.map(self.machineName); copy.plan = "Hidden"
                    copy.source = "Hidden"; copy.issue = ""; copy.pace = nil; copy.resetDetails = []
                    copy.credits = old.credits.map { CreditPool(name: $0.name, value: "Hidden", detail: "") }
                    return copy
                }
            }
            let snapshot = UsageSnapshot(version: 1, generatedAt: self.generatedAt ?? ISO8601DateFormatter().string(from: Date()), accounts: rows)
            do { try PrivateFiles.write(snapshot, to: url); self.message = "Snapshot exported." }
            catch { self.message = "Could not save the snapshot." }
        }
    }
    func copySupportReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Insights.supportReport(accounts, native: nativeMode, helperAvailable: NativeCollector.helper != nil), forType: .string)
        message = "Support report copied. Account identities, balances and machine details are excluded."
    }
    func reconnect(_ account: UsageAccount) {
        let localMachine = nativeMode ? preferences.machineName : legacyLocalMachine
        if !account.machines.contains(localMachine) { reconnectRemote(account); return }
        let reconnect = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/UsageBoard/Reconnect Claude.command")
        if account.provider == "Claude", !nativeMode, FileManager.default.fileExists(atPath: reconnect.path) { NSWorkspace.shared.open(reconnect); return }
        if account.provider == "Claude", nativeMode {
            let companion = URL(fileURLWithPath: "/Applications/CodexBar.app")
            NSWorkspace.shared.open(FileManager.default.fileExists(atPath: companion.path) ? companion : URL(string: "https://github.com/steipete/CodexBar#readme")!)
            message = "Connect Claude in CodexBar or run claude to sign in to Claude Code, then check again."
            return
        }
        let names = ["Claude": "Claude", "Codex": "Codex", "Antigravity": "Antigravity"]
        if let name = names[account.provider], let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ["Claude":"com.anthropic.claudefordesktop", "Codex":"com.openai.codex", "Antigravity":"com.google.antigravity"][account.provider] ?? "") {
            NSWorkspace.shared.open(url); message = "Check \(name)'s sign-in, then refresh usage."
        } else { NSWorkspace.shared.open(URL(string: "https://github.com/steipete/CodexBar#readme")!) }
    }
    private func reconnectRemote(_ account: UsageAccount) {
        guard !reconnecting else { return }
        var ssh: [String]?
        if nativeMode {
            if let remote = preferences.remotes.first(where: { account.machines.contains($0.name) && $0.valid }) { ssh = [remote.sshAlias] }
        } else if let data = try? Data(contentsOf: root.appendingPathComponent("config.local.json")),
                  let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let machines = config["machines"] as? [String: [String: Any]] {
            ssh = account.activeMachines.compactMap { machines[$0]?["ssh"] as? [String] }.first
        }
        guard let ssh, let action = RemoteReconnect.make(provider: account.provider, ssh: ssh) else {
            message = "No remote connection is configured. Open Setup → Computers, or sign in directly on the listed Mac."
            return
        }
        reconnecting = true; message = "Opening sign-in on the remote Mac…"
        Task {
            let (url, opened) = await Task.detached { action.open() }.value
            let sharing = url.map { NSWorkspace.shared.open($0) } ?? false
            reconnecting = false
            if opened && sharing { message = "Sign-in opened on the remote Mac. Complete it in Screen Sharing, then choose Check again." }
            else if opened { message = "Sign-in opened on the remote Mac. Connect with Screen Sharing or finish there, then check again." }
            else { message = "Could not open remote sign-in. Wake or unlock that Mac, then open Reconnect Claude there (or the provider app for other accounts) and check again." }
        }
    }
}
