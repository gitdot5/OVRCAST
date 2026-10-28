import Foundation
import Darwin

struct CommandOutput { var data: Data; var code: Int32 }
private final class Capture: @unchecked Sendable {
    let lock = NSLock()
    var data = Data()
    var oversized = false
    func append(_ part: Data) {
        lock.lock(); defer { lock.unlock() }
        if data.count + part.count > 4_000_000 { oversized = true }
        else { data.append(part) }
    }
    func result() -> (Data, Bool) { lock.lock(); defer { lock.unlock() }; return (data, oversized) }
}
enum CommandRunner {
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 60) throws -> CommandOutput {
        let process = Process(), pipe = Pipe(), capture = Capture(), ended = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        env["PATH"] = home + "/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in ended.signal() }
        let drained = DispatchSemaphore(value: 0)
        try process.run()
        DispatchQueue.global(qos: .utility).async {
            defer { drained.signal() }
            while let chunk = try? pipe.fileHandleForReading.read(upToCount: 16384), !chunk.isEmpty { capture.append(chunk) }
        }
        if ended.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if ended.wait(timeout: .now() + 2) == .timedOut { kill(process.processIdentifier, SIGKILL) }
            try? pipe.fileHandleForReading.close()
            throw NSError(domain: "UsageBoard", code: 1, userInfo: [NSLocalizedDescriptionKey: "The usage source did not respond in time."])
        }
        _ = drained.wait(timeout: .now() + 2)
        try? pipe.fileHandleForReading.close()
        let (data, oversized) = capture.result()
        guard !oversized else { throw CocoaError(.fileReadTooLarge) }
        return CommandOutput(data: data, code: process.terminationStatus)
    }
}
enum NativeCollector {
    static var helper: String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI", home + "/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI",
                home + "/.local/bin/codexbar", "/opt/homebrew/bin/codexbar", "/usr/local/bin/codexbar"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    static func failure(provider: String, machine: String, issue: String, signIn: Bool = false) -> UsageAccount {
        UsageAccount(id: provider.lowercased() + ":unknown:" + machine, provider: provider, email: "Account not connected", plan: "Plan unknown",
                     machines: [machine], severity: "unknown", status: signIn ? "Sign in required" : "Needs a reading", requiresSignIn: signIn,
                     fresh: false, observedAt: nil, source: "CodexBar", issue: issue, quotas: [], resetDetails: [], credits: [])
    }
    static func collect(provider: String, machine: String, helper: String) -> [UsageAccount] {
        let source = provider == "Antigravity" ? [] : ["--source", "cli"]
        do {
            let output = try CommandRunner.run(helper, ["usage", "--provider", provider.lowercased(), "--all-accounts", "--format", "json", "--no-color"] + source, timeout: 90)
            return try parse(output.data, provider: provider, machine: machine)
        } catch {
            return [failure(provider: provider, machine: machine, issue: "The usage source could not provide a reading. Check the provider app and try again.")]
        }
    }
    static func safePayload(_ data: Data) -> Bool {
        guard data.count <= 4_000_000, let text = String(data: data, encoding: .utf8) else { return false }
        return [#"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#, #"sk-ant-[A-Za-z0-9_-]{8,}"#,
                #"\bsk-[A-Za-z0-9]{20,}"#, #"Bearer\s+[A-Za-z0-9._-]{20,}"#,
                #""(?:access_token|refresh_token|id_token|sessionKey|cookie|cookieHeader|apiKey)"\s*:"#]
            .allSatisfy { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) == nil }
    }
    static func parse(_ data: Data, provider: String, machine: String) throws -> [UsageAccount] {
        guard safePayload(data), let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], !rows.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        return rows.enumerated().map { index, row in
            guard let usage = row["usage"] as? [String: Any] else {
                let error = row["error"] as? [String: Any] ?? [:]
                let message = (error["message"] as? String ?? "").lowercased()
                let auth = error["kind"] as? String == "authentication" || ["sign in", "login", "not logged", "unauthorized"].contains(where: message.contains)
                return failure(provider: provider, machine: machine, issue: auth ? "Sign in through the provider app, then check again." : "Open the provider app and check its connection in CodexBar.", signIn: auth)
            }
            let email = (usage["accountEmail"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Account \(index + 1)"
            let observed = usage["updatedAt"] as? String
            let labels = row["rateWindowLabels"] as? [String: String] ?? [:]
            var quotas: [Quota] = []
            func add(_ object: Any?, _ label: String) {
                guard let window = object as? [String: Any], let used = window["usedPercent"] as? NSNumber,
                      CFGetTypeID(used) != CFBooleanGetTypeID(), used.doubleValue.isFinite,
                      (0...100).contains(used.doubleValue) else { return }
                quotas.append(Quota(label: label, remaining: 100 - used.doubleValue, resetsAt: window["resetsAt"] as? String, resetPassed: false))
            }
            for (key, fallback) in [("primary", "Session"), ("secondary", "Weekly"), ("tertiary", "Model limit")] { add(usage[key], labels[key] ?? fallback) }
            for extra in usage["extraRateWindows"] as? [[String: Any]] ?? [] { add(extra["window"], extra["title"] as? String ?? "Model limit") }
            let reset = row["resetCredits"] as? [String: Any] ?? usage["codexResetCredits"] as? [String: Any] ?? [:]
            let count = (reset["available"] ?? reset["availableCount"]) as? Int
            var credits: [CreditPool] = []
            let rawCredits = row["credits"] as? [String: Any] ?? [:]
            if provider == "Codex" {
                let balance = rawCredits["remaining"] as? Double
                credits.append(CreditPool(name: "Codex credits", value: rawCredits["balanceReadSucceeded"] as? Bool != false ? balance.map { String(format: "%.2f credits", $0) } ?? "Unknown" : "Unknown", detail: "Separate from included allowance"))
            }
            for section in usage["details"] as? [[String: Any]] ?? [] {
                for detail in section["rows"] as? [[String: Any]] ?? [] {
                    guard let label = detail["label"] as? String, let value = detail["value"] as? String else { continue }
                    let secondary = detail["secondaryValue"] as? String ?? "Reported by provider"
                    let expiry = (detail["expiresAt"] as? String) ?? expiryDate(in: secondary)
                    credits.append(CreditPool(name: String(label.prefix(100)), value: String(value.prefix(300)), detail: String(secondary.prefix(300)), expiresAt: expiry))
                }
            }
            if let cost = usage["providerCost"] as? [String: Any], let used = cost["used"] as? Double, let currency = cost["currencyCode"] as? String {
                credits.append(CreditPool(name: "Reported spending", value: String(format: "%.2f %@", used, currency), detail: cost["period"] as? String ?? "Separate billing pool"))
            }
            if credits.isEmpty { credits = [CreditPool(name: "Credits", value: "Unknown", detail: "Current source does not report this balance")] }
            let minimum = quotas.map(\.remaining).min() ?? 0
            let severity = quotas.isEmpty ? "unknown" : minimum <= 10 ? "critical" : minimum <= 40 ? "warning" : "good"
            let status = quotas.isEmpty ? "Needs a reading" : minimum == 0 ? "Limit reached" : minimum <= 40 ? "Running low" : "Available"
            return UsageAccount(id: provider.lowercased() + ":" + (email.contains("@") ? email.lowercased() : machine + ":" + email),
                                provider: provider, email: email, plan: usage["loginMethod"] as? String ?? "Plan unknown", machines: [machine],
                                severity: severity, status: status, requiresSignIn: false, fresh: observed != nil && !quotas.isEmpty,
                                observedAt: observed, source: "CodexBar · " + (row["source"] as? String ?? "CLI"), issue: "", quotas: quotas,
                                savedResets: count, resetDetails: [], credits: credits)
        }
    }
    static func expiryDate(in text: String) -> String? {
        guard let range = text.range(of: #"(?i)expires\s+\d{4}-\d{2}-\d{2}T[0-9:.]+(?:Z|[+-][0-9:]+)"#, options: .regularExpression),
              let date = text[range].split(separator: " ").last, parsedDate(String(date)) != nil else { return nil }
        return String(date)
    }
    static func merge(_ accounts: [UsageAccount]) -> [UsageAccount] {
        var result: [String: UsageAccount] = [:]
        for account in accounts {
            if let old = result[account.id] {
                var winner = (parsedDate(account.observedAt) ?? .distantPast) > (parsedDate(old.observedAt) ?? .distantPast) ? account : old
                winner.machines = Array(Set(old.machines + account.machines)).sorted()
                result[account.id] = winner
            } else { result[account.id] = account }
        }
        return result.values.sorted { $0.provider == $1.provider ? $0.id < $1.id : $0.provider < $1.provider }
    }
    static func remote(_ machine: RemoteMachine) throws -> [UsageAccount] {
        guard machine.valid else { throw CocoaError(.validationMissingMandatoryProperty) }
        let result = try CommandRunner.run("/usr/bin/ssh", RemoteReconnect.connectionOptions + [machine.sshAlias,
            #"cat "$HOME/Library/Application Support/UsageBoard/native-overview.json""#], timeout: 15)
        guard result.code == 0, safePayload(result.data) else { throw CocoaError(.fileReadUnknown) }
        let snapshot = try SnapshotValidation.decode(result.data)
        return snapshot.accounts.map { account in var copy = account; copy.machines = [machine.name]; return copy }
    }
}
