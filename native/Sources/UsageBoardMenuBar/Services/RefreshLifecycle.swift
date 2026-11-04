import AppKit
import Network

@MainActor final class RefreshLifecycle {
    private let monitor = NWPathMonitor()
    private var observers: [NSObjectProtocol] = []
    private var wasOnline: Bool?
    func start(store: UsageStore) {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak store] _ in
            Task { @MainActor in store?.sleeping = true }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak store] _ in
            Task { @MainActor in store?.sleeping = false; store?.recoverConnection() }
        })
        monitor.pathUpdateHandler = { [weak self, weak store] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let restored = self.wasOnline == false && online
                self.wasOnline = online
                if restored { store?.recoverConnection() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.weekthink.ovrcast.network"))
    }
    func stop() {
        monitor.cancel()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
    }
}
