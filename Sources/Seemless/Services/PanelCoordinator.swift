import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

@MainActor
final class PanelCoordinator: NSObject, NSWindowDelegate {
    private unowned let model: AppModel
    private var panel: FloatingPanel?
    private var settingsWindow: NSWindow?
    private(set) var visibleKind: PanelKind?
    private var outsideMonitor: Any?

    var diagnosticWindow: NSWindow? { panel ?? settingsWindow }

    init(model: AppModel) { self.model = model }

    func show(_ kind: PanelKind) {
        dismiss(restoreFocus: false)
        let size = kind == .commands ? NSSize(width: 640, height: 480) : NSSize(width: 780, height: 520)
        let window = FloatingPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.title = kind == .commands ? "Seemless command bar" : "Seemless clipboard history"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.delegate = self
        window.onCancel = { [weak self] in self?.dismiss(restoreFocus: true) }
        window.isReleasedWhenClosed = false
        if kind == .commands { window.contentView = NSHostingView(rootView: CommandBarView(model: model)) }
        else { window.contentView = NSHostingView(rootView: ClipboardPanelView(model: model)) }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let width = min(size.width, frame.width - 24)
            let height = min(size.height, frame.height - 24)
            window.setFrame(NSRect(x: frame.midX - width / 2, y: frame.minY + (frame.height - height) * 0.6, width: width, height: height), display: true)
        }
        panel = window
        visibleKind = kind
        window.makeKeyAndOrderFront(nil)
        RuntimeLog.event(.windows, "Opened \(kind == .commands ? "commands" : "clipboard"): window=\(window.windowNumber)")
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.dismiss(restoreFocus: false) }
        }
    }

    func dismiss(restoreFocus: Bool) {
        let wasVisible = visibleKind != nil
        visibleKind = nil
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
        outsideMonitor = nil
        panel?.delegate = nil
        panel?.orderOut(nil)
        panel = nil
        if wasVisible { RuntimeLog.event(.windows, "Dismissed floating panel") }
        if restoreFocus, wasVisible, let origin = model.origin { model.switcher.focus(origin) }
    }

    func showSettings() {
        dismiss(restoreFocus: false)
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 620), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Seemless settings"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.minSize = NSSize(width: 760, height: 540)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.center()
            settingsWindow = window
        }
        model.hasAccessibility = model.switcher.hasAccessibility
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        RuntimeLog.event(.windows, "Opened settings: window=\(self.settingsWindow?.windowNumber ?? -1)")
    }

    func windowDidResignKey(_ notification: Notification) {
        if visibleKind != nil { dismiss(restoreFocus: false) }
    }
}
