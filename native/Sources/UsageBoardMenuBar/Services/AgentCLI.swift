import Foundation

/// An explicitly enabled, local, read-only interface. Never starts collectors or the GUI.
enum AgentCLI {
    struct Result { var code: Int32; var data: Data }
    static let providers = ["Codex", "Claude", "Antigravity", "Claude Platform"]
    static let help = "--agent status|recommend|tokens [--provider Codex|Claude|Antigravity|Claude Platform] [--machine mac-N] [--minimum-remaining 0..100]"

    static func response(_ value: [String: Any], code: Int32 = 0) -> Result {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])) ?? Data("{}".utf8)
        return Result(code: code, data: data + Data("\n".utf8))
    }
    static func failure(_ kind: String, code: Int32) -> Result {
        response(["schemaVersion": 1, "error": kind, "usage": help], code: code)
    }
    static func read(_ url: URL) throws -> Data {
        // Check type and bound the actual read, including files that grow during the operation.
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw CocoaError(.fileReadCorruptFile) }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 4_000_001) ?? Data()
        guard data.count <= 4_000_000 else { throw CocoaError(.fileReadCorruptFile) }
        return data
    }
    static func run(_ args: [String], home: URL = FileManager.default.homeDirectoryForCurrentUser, now: Date = Date()) -> Result {
        guard let command = args.first else { return failure("invalid_arguments", code: 64) }
        if args == ["--help"] { return response(["schemaVersion": 1, "usage": help]) }
        guard ["status", "recommend", "tokens"].contains(command) else { return failure("invalid_arguments", code: 64) }
        var provider: String?, machine: String?, minimum = 15.0, seen = Set<String>()
        var index = 1
        while index < args.count {
            let flag = args[index]
            guard index + 1 < args.count, seen.insert(flag).inserted else { return failure("invalid_arguments", code: 64) }
            let value = args[index + 1]
            switch flag {
            case "--provider":
                guard let known = providers.first(where: { $0.lowercased() == value.lowercased() }) else { return failure("invalid_provider", code: 64) }
                provider = known
            case "--machine":
                guard value.range(of: #"^mac-[1-9][0-9]{0,3}$"#, options: .regularExpression) != nil else { return failure("invalid_machine", code: 64) }
                machine = value
            case "--minimum-remaining":
                guard let number = Double(value), number.isFinite, (0...100).contains(number) else { return failure("invalid_threshold", code: 64) }
                minimum = number
            default: return failure("invalid_arguments", code: 64)
            }
            index += 2
        }
        let app = home.appendingPathComponent("Library/Application Support/UsageBoard/App")
        guard let bytes = try? read(app.appendingPathComponent("preferences.json")),
              let preferences = try? JSONDecoder().decode(BoardPreferences.self, from: bytes), preferences.agentAccess else {
            return failure("agent_access_disabled_enable_in_settings", code: 77)
        }
        if command == "tokens" {
            guard preferences.tokenHistory else { return failure("token_history_disabled_enable_in_settings", code: 77) }
            let url = app.appendingPathComponent("token-activity.json")
            guard FileManager.default.fileExists(atPath: url.path) else { return failure("no_saved_token_history", code: 66) }
            guard let data = try? read(url), let ledger = try? TokenActivityLedger.decode(data) else { return failure("unreadable_token_history", code: 65) }
            return tokenReport(ledger, provider: provider, machine: machine, now: now)
        }
        let legacy = home.appendingPathComponent("usage_board")
        let useLegacy = !preferences.nativeCollection && FileManager.default.fileExists(atPath: legacy.appendingPathComponent("config.local.json").path)
        let snapshotURL = useLegacy ? legacy.appendingPathComponent("state/overview.json") : app.appendingPathComponent("overview.json")
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return failure("no_saved_reading_refresh_in_app", code: 66) }
        guard let data = try? read(snapshotURL), let snapshot = try? SnapshotValidation.decode(data) else { return failure("unreadable_saved_reading", code: 65) }
        return report(snapshot, command: command, provider: provider, machine: machine, minimum: minimum, now: now)
    }

    static func tokenReport(_ ledger: TokenActivityLedger, provider: String?, machine: String?, now: Date) -> Result {
        let machines = ledger.machines.sorted { $0.machine < $1.machine }
        let ids = machines.indices.map { "mac-\($0 + 1)" }
        if let machine, !ids.contains(machine) { return failure("unknown_machine", code: 64) }
        let rows: [[String: Any]] = machines.enumerated().compactMap { index, value in
            guard machine == nil || machine == ids[index] else { return nil }
            let harnesses: [[String: Any]] = value.harnesses.filter { provider == nil || $0.provider == provider?.lowercased() }.map { harness in
                func counters(_ days: Int) -> [String: Any] {
                    let row = harness.summary(days: days, now: now)
                    return ["input": row?.input as Any? ?? NSNull(), "output": row?.output as Any? ?? NSNull(),
                            "cacheRead": row?.cacheRead as Any? ?? NSNull(), "cacheWrite": row?.cacheWrite as Any? ?? NSNull(),
                            "total": row?.total as Any? ?? NSNull()]
                }
                return ["harness": harness.title, "timeZone": harness.timeZone, "observedAt": harness.generatedAt,
                        "historyComplete": harness.historyComplete, "scanComplete": harness.scanComplete as Any? ?? NSNull(), "state": harness.error != nil ? "unavailable" :
                            parsedDate(harness.generatedAt).map { (-60...1200).contains(now.timeIntervalSince($0)) } == true ? "recorded_local_history" : "last_known",
                        "today": counters(1), "last7Days": counters(7)]
            }
            return ["machineID": ids[index], "family": MachineLabels.family(value.machine) ?? "Mac", "harnesses": harnesses]
        }
        return response(["schemaVersion": 1, "mode": "read_only", "idsScopedToSnapshot": true,
                         "generatedAt": parsedDate(ledger.generatedAt).map { ISO8601DateFormatter().string(from: $0) } as Any? ?? NSNull(),
                         "scope": "per_machine_local_records_not_account_wide", "fleetTotal": NSNull(),
                         "costDataAvailable": false, "machines": rows])
    }

    static func report(_ snapshot: UsageSnapshot, command: String, provider: String? = nil, machine: String? = nil,
                       minimum: Double = 15, now: Date = Date()) -> Result {
        func timestamp(_ text: String?) -> String? { parsedDate(text).map { ISO8601DateFormatter().string(from: $0) } }
        func recent(_ text: String?) -> Bool { parsedDate(text).map { (-60...600).contains(now.timeIntervalSince($0)) } == true }
        let snapshotCurrent = recent(snapshot.generatedAt)
        // IDs are scoped to this snapshot. No hash of an email or SSH alias is exposed.
        let machines = Array(Set(snapshot.accounts.flatMap(\.activeMachines))).sorted()
        let machineIDs = Dictionary(uniqueKeysWithValues: machines.enumerated().map { ($0.element, "mac-\($0.offset + 1)") })
        if let machine, !machineIDs.values.contains(machine) { return failure("unknown_machine", code: 64) }
        let rows: [[String: Any]] = snapshot.accounts.sorted { $0.id < $1.id }.enumerated().compactMap { offset, account in
            guard providers.contains(account.provider), provider == nil || provider == account.provider else { return nil }
            let active = account.activeMachines.compactMap { machineIDs[$0] }
            guard machine == nil || active.contains(machine!) else { return nil }
            let current = snapshotCurrent && account.fresh && recent(account.observedAt)
            let hasIssue = !account.issue.isEmpty
            let resetPending = account.quotas.contains { $0.resetPassed || parsedDate($0.resetsAt).map { $0 <= now } == true }
            let remaining = account.quotas.map(\.remaining).min()
            let eligible = current && account.requiresSignIn != true && !hasIssue && !active.isEmpty &&
                !account.quotas.isEmpty && !resetPending && remaining.map { $0 > 0 && $0 >= minimum } == true
            let state = account.requiresSignIn == true ? "sign_in_required" : !current ? "stale" : hasIssue ? "connection_issue" :
                account.quotas.isEmpty ? "quota_unknown" : resetPending ? "reset_pending" : "current"
            let windows: [[String: Any]] = account.quotas.enumerated().map { i, quota in
                // Provider labels and error text are untrusted. Export ordinal windows only.
                ["windowID": "window-\(i + 1)", "remainingPercent": quota.remaining,
                 "resetsAt": timestamp(quota.resetsAt) as Any? ?? NSNull(),
                 "resetPending": quota.resetPassed || parsedDate(quota.resetsAt).map { $0 <= now } == true]
            }
            return ["accountID": "account-\(offset + 1)", "provider": account.provider, "machineIDs": active,
                    "state": state, "eligible": eligible, "observedAt": timestamp(account.observedAt) as Any? ?? NSNull(),
                    "minimumRemainingPercent": remaining as Any? ?? NSNull(), "windows": windows]
        }
        var result: [String: Any] = ["schemaVersion": 1, "mode": "read_only", "generatedAt": timestamp(snapshot.generatedAt) as Any? ?? NSNull(),
            "snapshotCurrent": snapshotCurrent, "idsScopedToSnapshot": true, "minimumRemainingPercent": minimum,
            "costDataAvailable": false, "automaticExecution": false,
            "machines": machines.map { name in ["machineID": machineIDs[name]!, "family": MachineLabels.family(name) ?? "Mac", "reachability": "unknown"] },
            "accounts": rows,
            "constraints": ["Shared account quota is not multiplied by machine count.",
                            "Recommendations use the lowest remaining window and cannot guarantee task fit.",
                            "Percentages across providers are not comparable dollar costs.",
                            "Machine associations do not verify reachability or installed harnesses.",
                            "No credentials, model prices or execution routes are included."]]
        if command == "recommend" {
            // Choose within each provider, never pretend different providers' percentages are equivalent.
            let recommendations = providers.compactMap { name -> [String: Any]? in
                let eligible = rows.filter { $0["provider"] as? String == name && $0["eligible"] as? Bool == true }
                return eligible.sorted {
                    let a = $0["minimumRemainingPercent"] as? Double ?? 0, b = $1["minimumRemainingPercent"] as? Double ?? 0
                    return a == b ? ($0["accountID"] as? String ?? "") < ($1["accountID"] as? String ?? "") : a > b
                }.first
            }
            result["recommendations"] = recommendations
            result["decision"] = recommendations.isEmpty ? "no_eligible_capacity" : "capacity_options_require_task_and_cost_review"
            return response(result, code: recommendations.isEmpty ? 2 : 0)
        }
        return response(result)
    }
}
