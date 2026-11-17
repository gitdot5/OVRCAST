import Foundation

struct TokenDay: Codable {
    var date: String
    var input: Int?, output: Int?, cacheRead: Int?, cacheWrite: Int?, total: Int?
}
struct TokenHarness: Codable {
    var schemaVersion: Int
    var provider: String
    var generatedAt: String
    var timeZone: String
    var historyComplete: Bool
    var days: [TokenDay]
    var error: String?
    var title: String { ["codex": "Codex", "claude": "Claude Code", "antigravity": "Antigravity"][provider] ?? "Other" }
    func summary(days count: Int, now: Date = Date()) -> TokenDay? {
        guard error == nil, let zone = TimeZone(identifier: timeZone) else { return nil }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = zone
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        let keys = Set((0..<count).compactMap { calendar.date(byAdding: .day, value: -$0, to: now).map { formatter.string(from: $0) } })
        let selected = days.filter { keys.contains($0.date) }
        // No row is not proof of zero. Complete scanned history can establish an empty day.
        let observedToday = parsedDate(generatedAt).map { calendar.isDate($0, inSameDayAs: now) && $0 <= now.addingTimeInterval(60) } == true
        guard !selected.isEmpty || (historyComplete && observedToday) else { return nil }
        func sum(_ key: KeyPath<TokenDay, Int?>) -> Int? {
            guard !selected.isEmpty else { return 0 }
            var total = 0
            for row in selected {
                guard let value = row[keyPath: key], value >= 0 else { return nil }
                let next = total.addingReportingOverflow(value); guard !next.overflow else { return nil }; total = next.partialValue
            }
            return total
        }
        return TokenDay(date: formatter.string(from: now), input: sum(\.input), output: sum(\.output), cacheRead: sum(\.cacheRead), cacheWrite: sum(\.cacheWrite), total: sum(\.total))
    }
    var current: Bool { parsedDate(generatedAt).map { (-60...1200).contains(Date().timeIntervalSince($0)) } == true }
}
struct TokenMachine: Codable { var machine: String; var harnesses: [TokenHarness] }
struct TokenActivityLedger: Codable {
    var schemaVersion: Int = 1
    var generatedAt: String
    var machines: [TokenMachine]
    static func decode(_ data: Data) throws -> TokenActivityLedger {
        guard NativeCollector.safePayload(data) else { throw CocoaError(.fileReadCorruptFile) }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.schemaVersion == 1, parsedDate(value.generatedAt) != nil, value.machines.count <= 50,
              Set(value.machines.map(\.machine)).count == value.machines.count,
              value.machines.allSatisfy({ $0.machine.utf8.count <= 4096 && $0.harnesses.count <= 3 &&
                  Set($0.harnesses.map(\.provider)).count == $0.harnesses.count && $0.harnesses.allSatisfy(TokenActivityCollector.valid) }) else { throw CocoaError(.fileReadCorruptFile) }
        return value
    }
}
enum TokenActivityCollector {
    static let providers = ["codex", "claude", "antigravity"]
    static func valid(_ value: TokenHarness) -> Bool {
        guard value.schemaVersion == 1, providers.contains(value.provider), value.days.count <= 7,
              TimeZone(identifier: value.timeZone) != nil, parsedDate(value.generatedAt) != nil,
              value.error == nil || value.error == "local_history_unavailable",
              Set(value.days.map(\.date)).count == value.days.count else { return false }
        return value.days.allSatisfy { row in
            row.date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil &&
            [row.input, row.output, row.cacheRead, row.cacheWrite, row.total].allSatisfy { $0 == nil || $0! >= 0 }
        }
    }
    static func unavailable(_ provider: String) -> TokenHarness {
        TokenHarness(schemaVersion: 1, provider: provider, generatedAt: ISO8601DateFormatter().string(from: Date()),
                     timeZone: TimeZone.current.identifier, historyComplete: false, days: [], error: "local_history_unavailable")
    }
    static func local(helper: String, machine: String) -> TokenMachine {
        let rows = providers.map { provider -> TokenHarness in
            if Task.isCancelled { return unavailable(provider) }
            guard let output = try? CommandRunner.run(helper, ["token-activity", "--provider", provider], timeout: 45), output.code == 0,
                  NativeCollector.safePayload(output.data), let row = try? JSONDecoder().decode(TokenHarness.self, from: output.data),
                  row.provider == provider, valid(row) else { return unavailable(provider) }
            return row
        }
        return TokenMachine(machine: machine, harnesses: rows)
    }
    static func remote(name: String, ssh: [String]) -> TokenMachine {
        let output = try? CommandRunner.run("/usr/bin/ssh", ["-o", "ClearAllForwardings=yes"] + ssh +
            [#"cat "$HOME/Library/Application Support/UsageBoard/token-activity.json""#], timeout: 25)
        guard let output, output.code == 0, let ledger = try? TokenActivityLedger.decode(output.data), ledger.machines.count == 1 else {
            return TokenMachine(machine: name, harnesses: providers.map(unavailable))
        }
        return TokenMachine(machine: name, harnesses: ledger.machines[0].harnesses)
    }
}
