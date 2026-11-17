import Foundation

/// Local counter projection only. No account identity, paths, content, models or costs leave this boundary.
public enum OVRCASTTokenActivity {
    public static func read(provider: UsageProvider) async -> Data {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        var payload: [String: Any] = ["schemaVersion": 1, "provider": provider.rawValue,
            "generatedAt": ISO8601DateFormatter().string(from: now), "timeZone": calendar.timeZone.identifier,
            "historyComplete": false, "days": []]
        do {
            let cache = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/OVRCAST/TokenActivity")
            try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: cache.path)
            var scanOptions = CostUsageScanner.Options(cacheRoot: cache, calendar: calendar)
            scanOptions.maxCodexScanDurationPerRefresh = 2
            // This API is internal to the core, so all network/pricing and other-harness fallbacks
            // can be explicitly disabled instead of relying on CLI defaults.
            let snapshot = try await CostUsageFetcher.loadTokenSnapshot(provider: provider, now: now,
                allowVertexClaudeFallback: false, historyDays: 7, allowPricingRefresh: false,
                refreshPricingInBackground: false, includePiSessions: false, scannerOptions: scanOptions,
                retryUnknownPricing: false)
            payload["historyComplete"] = snapshot.historyIsFullyScanned
            payload["days"] = snapshot.daily.map { day -> [String: Any] in
                func number(_ value: Int?) -> Any { value.flatMap { $0 >= 0 ? $0 : nil } as Any? ?? NSNull() }
                return ["date": day.date, "input": number(day.inputTokens), "output": number(day.outputTokens),
                        "cacheRead": number(day.cacheReadTokens), "cacheWrite": number(day.cacheCreationTokens),
                        "total": number(day.totalTokens)]
            }
        } catch { payload["error"] = "local_history_unavailable" }
        return (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data("{}".utf8)
    }
}
