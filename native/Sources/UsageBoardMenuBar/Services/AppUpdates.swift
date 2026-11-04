import AppKit
import Combine
import Sparkle

@MainActor final class AppUpdates: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = AppUpdates()
    @Published private(set) var ready = false
    @Published private(set) var status = "Updates are available in installed release builds."
    @Published var automaticChecks = false { didSet { controller?.updater.automaticallyChecksForUpdates = automaticChecks } }
    @Published var automaticInstall = false { didSet { controller?.updater.automaticallyDownloadsUpdates = automaticInstall } }
    private var controller: SPUStandardUpdaterController?
    private var observation: AnyCancellable?
    func start(demo: Bool) {
        guard !demo, controller == nil, Bundle.main.bundleURL.pathExtension == "app",
              Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String != nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        do {
            try controller.updater.start()
            automaticChecks = controller.updater.automaticallyChecksForUpdates
            automaticInstall = controller.updater.automaticallyDownloadsUpdates
            status = "Signed updates · automatic checks are optional"
            observation = controller.updater.publisher(for: \.canCheckForUpdates).receive(on: RunLoop.main)
                .sink { [weak self] in self?.ready = $0 }
        } catch { status = "Updates could not start. Download the latest signed release from GitHub." }
    }
    func check() {
        guard ready else { return }
        status = "Checking for signed updates…"
        controller?.checkForUpdates(nil)
    }
    nonisolated func allowedSystemProfileKeys(for updater: SPUUpdater) -> [String]? { [] }
    nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        let failed = error != nil
        Task { @MainActor in
            self.status = failed ? "Update check finished without installing. You can retry or download from GitHub." : "Update check completed."
        }
    }
}
