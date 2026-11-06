import AppKit
import Network

/// Coalesce recovery events without losing a network restoration just after wake.
@MainActor final class RecoveryCoordinator {
    private let minimumInterval: TimeInterval
    private let eligible: () -> Bool
    private let busy: () -> Bool
    private let refresh: () -> Void
    private var lastAttempt = Date.distantPast
    private var pending = false
    private var deferred: Task<Void, Never>?
    init(minimumInterval: TimeInterval = 10, eligible: @escaping () -> Bool,
         busy: @escaping () -> Bool, refresh: @escaping () -> Void) {
        self.minimumInterval = minimumInterval; self.eligible = eligible; self.busy = busy; self.refresh = refresh
    }
    func request() {
        guard eligible() else { return }
        if busy() { pending = true; return }
        let delay = minimumInterval - Date().timeIntervalSince(lastAttempt)
        if delay > 0 {
            guard deferred == nil else { return }
            deferred = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
                catch { return }
                guard let self, !Task.isCancelled else { return }
                self.deferred = nil; self.request()
            }
        } else { lastAttempt = Date(); refresh() }
    }
    func finished() {
        if pending { pending = false; request() }
    }
    func stop() { deferred?.cancel(); deferred = nil; pending = false }
}

@MainActor final class RefreshLifecycle {
    private let monitor = NWPathMonitor()
    private var observers: [NSObjectProtocol] = []
    private var wasOnline: Bool?
    private var active = false
    private var started = false
    func start(store: UsageStore) {
        guard !started else { return }
        started = true; active = true
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self, weak store] _ in
            Task { @MainActor in guard self?.active == true else { return }; store?.sleeping = true }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self, weak store] _ in
            Task { @MainActor in guard self?.active == true else { return }; store?.sleeping = false; store?.recoverConnection() }
        })
        monitor.pathUpdateHandler = { [weak self, weak store] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self, self.active else { return }
                let restored = self.wasOnline == false && online
                self.wasOnline = online
                if restored { store?.recoverConnection() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.weekthink.ovrcast.network"))
    }
    func stop() {
        active = false
        monitor.cancel()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
    }
}
