import Foundation

enum SnapshotValidation {
    static func decode(_ data: Data) throws -> UsageSnapshot {
        guard data.count <= 4_000_000, NativeCollector.safePayload(data) else { throw CocoaError(.fileReadCorruptFile) }
        let snapshot = try JSONDecoder().decode(UsageSnapshot.self, from: data)
        guard valid(snapshot) else { throw CocoaError(.fileReadCorruptFile) }
        return snapshot
    }
    static func valid(_ snapshot: UsageSnapshot) -> Bool {
        guard snapshot.version == 1, snapshot.accounts.count <= 200,
              Set(snapshot.accounts.map(\.id)).count == snapshot.accounts.count else { return false }
        return snapshot.accounts.allSatisfy { account in
            let strings = [account.id, account.provider, account.email, account.plan, account.status,
                           account.source, account.issue, account.pace ?? ""] + account.machines + account.resetDetails
            return !account.id.isEmpty && strings.allSatisfy { $0.utf8.count <= 4096 } &&
                account.machines.count <= 50 && account.resetDetails.count <= 100 &&
                (account.savedResets.map { (0...1_000_000).contains($0) } ?? true) &&
                account.quotas.count <= 100 && account.quotas.allSatisfy {
                    $0.remaining.isFinite && (0...100).contains($0.remaining) && $0.label.utf8.count <= 4096
                } && account.credits.count <= 100 && account.credits.allSatisfy {
                    [$0.name, $0.value, $0.detail].allSatisfy { $0.utf8.count <= 4096 }
                }
        }
    }
}
