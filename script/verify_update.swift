import AppKit
import Sparkle

@MainActor
final class VerificationDriver: NSObject, SPUUserDriver {
    private let install: Bool
    init(install: Bool) { self.install = install }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { print("Checking release feed") }
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        print("Found compatible update \(appcastItem.displayVersionString)")
        if install { reply(.install) }
        else { reply(.dismiss); exit(0) }
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        acknowledgement(); print("No newer compatible release"); exit(2)
    }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        acknowledgement()
        let failure = error as NSError
        fputs("Update verification failed: code=\(failure.code) \(failure.localizedDescription)\n", stderr)
        exit(1)
    }
    func showDownloadInitiated(cancellation: @escaping () -> Void) { print("Downloading release archive") }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() { print("Download finished; preparing extraction") }
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) { reply(.install) }
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        print("Installing verified release; host terminated=\(applicationTerminated)")
    }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement(); print("Update installed; relaunched=\(relaunched)"); exit(0)
    }
    func dismissUpdateInstallation() {}
}

@main
struct VerifyUpdate {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 3, ["--probe", "--install"].contains(CommandLine.arguments[2]) else {
            fputs("usage: verify-update /absolute/.build/path/Seemless.app --probe|--install\n", stderr)
            exit(2)
        }
        let url = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.contains("/.build/"), url.lastPathComponent == "Seemless.app", let host = Bundle(url: url), host.bundleIdentifier == "com.etphli.seemless" else {
            fputs("Verification only supports a staged Seemless.app inside .build.\n", stderr)
            exit(2)
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let driver = VerificationDriver(install: CommandLine.arguments[2] == "--install")
        let updater = SPUUpdater(hostBundle: host, applicationBundle: host, userDriver: driver, delegate: nil)
        try updater.start()
        updater.checkForUpdates()
        Timer.scheduledTimer(withTimeInterval: 90, repeats: false) { _ in
            fputs("Update verification timed out.\n", stderr); exit(1)
        }
        application.run()
        withExtendedLifetime((driver, updater)) {}
    }
}
