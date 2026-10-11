import AppKit
import SeemlessCore

@main
struct SeemlessApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var terminationSignal: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        signal(SIGTERM, SIG_IGN)
        terminationSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        terminationSignal?.setEventHandler { NSApp.terminate(nil) }
        terminationSignal?.resume()
        let arguments = CommandLine.arguments
        let diagnosticDirectory: URL?
        if let index = arguments.firstIndex(of: "--diagnostics"), arguments.indices.contains(index + 1) {
            diagnosticDirectory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        } else { diagnosticDirectory = nil }
        if let diagnosticDirectory {
            RuntimeLog.configureFile(diagnosticDirectory.appendingPathComponent("events.jsonl"))
        } else if let index = arguments.firstIndex(of: "--log-file"), arguments.indices.contains(index + 1) {
            RuntimeLog.configureFile(URL(fileURLWithPath: arguments[index + 1]))
        }
        let root = diagnosticDirectory?.appendingPathComponent("data-" + UUID().uuidString, isDirectory: true)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Seemless", isDirectory: true)
        RuntimeLog.event(.lifecycle, "Launching: diagnostics=\(diagnosticDirectory != nil)")
        model = AppModel(root: root)
        model.updates.onAvailabilityChanged = { [weak self] in self?.rebuildMenu() }
        installMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Seemless")
        statusItem.button?.toolTip = "Seemless"
        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self
        rebuildMenu()
        Task {
            let checkUpdates = diagnosticDirectory == nil || arguments.contains("--check-updates")
            await model.start(showWelcome: diagnosticDirectory == nil, checkUpdates: checkUpdates)
            if let diagnosticDirectory { await AppDiagnostics.run(model: model, destination: diagnosticDirectory) }
        }
    }

    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Seemless")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let settings = NSMenuItem(title: "Settings…", action: #selector(self.settings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        let hide = NSMenuItem(title: "Hide Seemless", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hide.target = NSApp
        appMenu.addItem(hide)
        let quit = NSMenuItem(title: "Quit Seemless", action: #selector(self.quit), keyEquivalent: "q")
        quit.target = self
        appMenu.addItem(quit)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        editItem.submenu = edit
        main.addItem(editItem)
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let windowItem = NSMenuItem()
        let windows = NSMenu(title: "Window")
        windowItem.submenu = windows
        main.addItem(windowItem)
        windows.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.mainMenu = main
        NSApp.windowsMenu = windows
    }

    func menuWillOpen(_ menu: NSMenu) { rebuildMenu() }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()
        add("Open command bar", action: #selector(commandBar), shortcut: model.settings.preferences.shortcuts[ActionID.commandBar], to: menu)
        add("Clipboard history", action: #selector(clipboard), shortcut: model.settings.preferences.shortcuts[ActionID.clipboard], to: menu)
        menu.addItem(.separator())
        add(model.clipboard.isMonitoring ? "Pause clipboard history" : "Start clipboard history", action: #selector(toggleClipboard), to: menu)
        let hyper = NSMenuItem(title: model.hyper.isEnabled ? "Caps Lock Hyper is on" : "Caps Lock Hyper is off", action: nil, keyEquivalent: "")
        menu.addItem(hyper)
        menu.addItem(.separator())
        add("Settings…", action: #selector(settings), to: menu)
        if let version = model.updates.availableVersion {
            add("Update to \(version)…", action: #selector(update), to: menu)
        }
        add("Quit Seemless", action: #selector(quit), to: menu)
    }

    private func add(_ title: String, action: Selector, shortcut: Shortcut? = nil, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let shortcut { item.toolTip = shortcut.display }
        menu.addItem(item)
    }

    @objc private func commandBar() { model.show(.commands) }
    @objc private func clipboard() { model.show(.clipboard) }
    @objc private func toggleClipboard() { model.setClipboardEnabled(!model.clipboard.isMonitoring) }
    @objc private func settings() { model.panels?.showSettings() }
    @objc private func update() { model.updates.installAvailableUpdate() }
    @objc private func quit() { NSApp.terminate(nil) }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.hyper.disable()
        if model.hyper.error != nil {
            let alert = NSAlert()
            alert.messageText = "Caps Lock could not be restored"
            alert.informativeText = "\(model.hyper.error ?? "")\nYou can retry, or quit and recover the mapping next time Seemless opens."
            alert.addButton(withTitle: "Retry")
            alert.addButton(withTitle: "Quit anyway")
            if alert.runModal() == .alertFirstButtonReturn {
                model.hyper.disable()
                if model.hyper.error != nil { return .terminateCancel }
            }
        }
        model.stop()
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
