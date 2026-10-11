import AppKit
import Observation
import Sparkle

@MainActor @Observable
final class UpdateService: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private(set) var availableVersion: String?
    private(set) var error: String?
    private(set) var didCompleteInitialCheck = false
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored var onAvailabilityChanged: (() -> Void)?

    var currentVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development" }
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    func start() {
        guard controller == nil, Bundle.main.bundleIdentifier == "com.etphli.seemless" else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
        self.controller = controller
        do {
            try controller.updater.start()
            controller.updater.checkForUpdateInformation()
            RuntimeLog.event(.updates, "Update checks started")
        } catch {
            self.error = "Update checks could not start."
            didCompleteInitialCheck = true
            RuntimeLog.event(.updates, "Updater configuration failed", error: true)
        }
    }

    func installAvailableUpdate() {
        guard availableVersion != nil else { return }
        controller?.checkForUpdates(nil)
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        availableVersion = item.displayVersionString
        didCompleteInitialCheck = true
        error = nil
        onAvailabilityChanged?()
        RuntimeLog.event(.updates, "A newer release is available")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        availableVersion = nil
        didCompleteInitialCheck = true
        self.error = nil
        onAvailabilityChanged?()
        RuntimeLog.event(.updates, "Already on the latest compatible release")
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        self.error = "Updates could not be checked. The next scheduled check will retry."
        didCompleteInitialCheck = true
        RuntimeLog.event(.updates, "Update check failed: code=\((error as NSError).code)", error: true)
    }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool { false }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        MainActor.assumeIsolated {
            availableVersion = update.displayVersionString
            onAvailabilityChanged?()
        }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        DispatchQueue.main.async { [weak self] in
            guard let updater = self?.controller?.updater, updater.canCheckForUpdates else { return }
            updater.checkForUpdateInformation()
        }
    }
}
