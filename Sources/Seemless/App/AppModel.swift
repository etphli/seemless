import AppKit
import ApplicationServices
import UniformTypeIdentifiers
import Observation
import SeemlessCore

enum PanelKind { case commands, clipboard }

@MainActor @Observable
final class AppModel {
    let settings: SettingsStore
    let catalog = AppCatalog()
    let clipboard: ClipboardStore
    let hyper: HyperService
    let switcher = AppSwitcher()
    let hotkeys = HotkeyService()
    let updates = UpdateService()
    var shortcutFailures: [String: String] = [:]
    var notice: String?
    var origin: FocusTarget?
    var windowTargets: [WindowTarget] = []
    var hasAccessibility = AXIsProcessTrusted()
    var panels: PanelCoordinator!

    init(root: URL) {
        settings = SettingsStore(root: root)
        clipboard = ClipboardStore(root: root.appendingPathComponent("Clipboard", isDirectory: true))
        hyper = HyperService(root: root)
    }

    func start(showSettingsOnLaunch: Bool = true, checkUpdates: Bool = true) async {
        panels = PanelCoordinator(model: self)
        hyper.recover()
        if settings.preferences.hyperEnabled { hyper.enable() }
        hotkeys.onAction = { [weak self] in self?.run($0) }
        registerShortcuts()
        await clipboard.load()
        clipboard.excludedApps = settings.preferences.excludedApps
        clipboard.setMonitoring(settings.preferences.clipboardEnabled)
        await scanApps()
        if checkUpdates { updates.start() }
        RuntimeLog.event(.lifecycle, "Ready: apps=\(self.catalog.apps.count) accessibility=\(self.hasAccessibility)")
        if showSettingsOnLaunch { panels.showSettings() }
    }

    func registerShortcuts() {
        shortcutFailures = hotkeys.register(settings.preferences.shortcuts)
        RuntimeLog.event(.shortcuts, "Registration: requested=\(self.settings.preferences.shortcuts.count) failed=\(self.shortcutFailures.count)")
    }

    func scanApps() async {
        await catalog.scan(additionalURLs: settings.preferences.customAppPaths.map { URL(fileURLWithPath: $0) })
    }

    func addApp() {
        let picker = NSOpenPanel()
        picker.title = "Choose an application"
        picker.canChooseDirectories = false
        picker.allowedContentTypes = [.applicationBundle]
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        picker.allowsMultipleSelection = false
        if picker.runModal() == .OK, let url = picker.url {
            if settings.update({ preferences in
                if !preferences.customAppPaths.contains(url.path) { preferences.customAppPaths.append(url.path) }
            }) { Task { await scanApps() } }
        }
    }

    func run(_ action: String) {
        switch action {
        case ActionID.commandBar: show(.commands)
        case ActionID.clipboard: show(.clipboard)
        default:
            guard let id = ActionID.bundleID(for: action) else { return }
            guard let app = catalog.apps.first(where: { $0.id == id }) else {
                notice = "This app is no longer available. Rescan your apps in Settings."
                panels.showSettings()
                return
            }
            switchApp(app)
        }
    }

    func show(_ kind: PanelKind) {
        guard panels != nil else { return }
        if panels.visibleKind == kind { panels.dismiss(restoreFocus: true); return }
        if panels.visibleKind == nil { origin = switcher.capture() }
        hasAccessibility = switcher.hasAccessibility
        windowTargets = kind == .commands ? switcher.windows(in: origin?.app) : []
        notice = nil
        panels.show(kind)
    }

    func switchApp(_ app: InstalledApp) {
        let target = panels.visibleKind == nil ? switcher.capture() : origin
        panels.dismiss(restoreFocus: false)
        switcher.switchTo(app, origin: target) { [weak self] error in
            self?.notice = error
            self?.panels.showSettings()
        }
    }

    func focusWindow(_ target: WindowTarget) {
        panels.dismiss(restoreFocus: false)
        switcher.focus(FocusTarget(app: target.app, window: target.element))
    }

    func copy(_ entry: ClipboardEntry, paste: Bool) async {
        guard await clipboard.copy(entry) else { return }
        let target = origin
        panels.dismiss(restoreFocus: true)
        if paste, hasAccessibility, let target, !target.app.isTerminated {
            try? await Task.sleep(for: .milliseconds(160))
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.app.processIdentifier else { return }
            for isDown in [true, false] {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: isDown)
                event?.flags = [.maskCommand]
                event?.postToPid(target.app.processIdentifier)
            }
        }
    }

    func setClipboardEnabled(_ enabled: Bool) {
        if settings.update({ $0.clipboardEnabled = enabled }) { clipboard.setMonitoring(enabled) }
    }

    func setHyperEnabled(_ enabled: Bool) {
        if enabled { hyper.enable() } else { hyper.disable() }
        if hyper.error == nil { settings.update { $0.hyperEnabled = enabled } }
        RuntimeLog.event(.shortcuts, "Hyper: enabled=\(self.hyper.isEnabled) failed=\(self.hyper.error != nil)")
    }

    func toggleFavourite(_ id: String) {
        settings.update { preferences in
            if preferences.favourites.contains(id) { preferences.favourites.remove(id) }
            else { preferences.favourites.insert(id) }
        }
    }

    func setShortcut(_ shortcut: Shortcut?, for action: String) -> String? {
        if let shortcut {
            guard shortcut.isValid else { return "Include Command, Option, Control, or Hyper." }
            if let conflict = settings.preferences.conflict(for: shortcut, excluding: action) {
                return "Already assigned to \(actionName(conflict))."
            }
        }
        guard settings.update({ $0.shortcuts[action] = shortcut }) else { return settings.error }
        return nil
    }

    func actionName(_ action: String) -> String {
        if action == ActionID.commandBar { return "Command bar" }
        if action == ActionID.clipboard { return "Clipboard history" }
        if let id = ActionID.bundleID(for: action) { return catalog.apps.first { $0.id == id }?.name ?? id }
        return action
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func stop() {
        clipboard.stop(); hotkeys.stop(); hyper.disable()
        RuntimeLog.event(.lifecycle, "Stopped")
    }
}
