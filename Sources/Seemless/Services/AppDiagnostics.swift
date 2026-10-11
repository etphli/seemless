import AppKit
import ApplicationServices
import SeemlessCore

@MainActor
enum AppDiagnostics {
    struct Capture: Codable {
        let name: String
        let windowNumber: Int
        let visible: Bool
        let key: Bool
        let pixelWidth: Int
        let pixelHeight: Int
        let bytes: Int
    }

    struct Report: Codable {
        let capturedAt: Date
        let processID: Int32
        let appCount: Int
        let shortcutsRequested: Int
        let shortcutsFailed: Int
        let accessibilityGranted: Bool
        let hyperEnabled: Bool
        let clipboardRecording: Bool
        let sampleHistoryCount: Int
        let updateAvailableVersion: String?
        let captureMethod: String
        let captures: [Capture]
    }

    static func run(model: AppModel, destination: URL) async {
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            if CommandLine.arguments.contains("--check-updates") {
                for _ in 0..<30 {
                    if model.updates.didCompleteInitialCheck { break }
                    try await Task.sleep(for: .milliseconds(100))
                }
            }
            _ = try await model.clipboard.repository.insert(ClipboardEntry(fingerprint: "diagnostic-text", payload: .text("Small actions, fewer steps.\n\nOpen the app you need, reuse a recent copy, and get back to your work."), isPinned: true, sourceName: "Notes"))
            _ = try await model.clipboard.repository.insert(ClipboardEntry(fingerprint: "diagnostic-link", payload: .link("https://developer.apple.com"), sourceName: "Safari"))
            await model.clipboard.refresh()
            let originalAppearance = NSApp.appearance
            defer { NSApp.appearance = originalAppearance }
            var captures: [Capture] = []
            for (suffix, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
                NSApp.appearance = NSAppearance(named: appearance)
                for name in ["settings", "commands", "clipboard"] {
                    if name == "settings" { model.panels.showSettings() }
                    else { model.panels.show(name == "commands" ? .commands : .clipboard) }
                    let window = model.panels.diagnosticWindow
                    window?.appearance = NSAppearance(named: appearance)
                    try await Task.sleep(for: .milliseconds(400))
                    guard let window, window.isVisible, let view = window.contentView else {
                        throw CocoaError(.coderInvalidValue)
                    }
                    view.layoutSubtreeIfNeeded()
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                        throw CocoaError(.coderInvalidValue)
                    }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard let png = bitmap.representation(using: .png, properties: [:]) else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    let captureName = "\(name)-\(suffix)"
                    try png.write(to: destination.appendingPathComponent(captureName + ".png"), options: .atomic)
                    captures.append(Capture(name: captureName, windowNumber: window.windowNumber, visible: window.isVisible, key: window.isKeyWindow, pixelWidth: bitmap.pixelsWide, pixelHeight: bitmap.pixelsHigh, bytes: png.count))
                    RuntimeLog.event(.windows, "Captured \(captureName): visible=\(window.isVisible) key=\(window.isKeyWindow)")
                    window.orderOut(nil)
                    model.panels.dismiss(restoreFocus: false)
                }
            }
            let report = Report(capturedAt: .now, processID: ProcessInfo.processInfo.processIdentifier, appCount: model.catalog.apps.count, shortcutsRequested: model.settings.preferences.shortcuts.count, shortcutsFailed: model.shortcutFailures.count, accessibilityGranted: AXIsProcessTrusted(), hyperEnabled: model.hyper.isEnabled, clipboardRecording: model.clipboard.isMonitoring, sampleHistoryCount: model.clipboard.entries.count, updateAvailableVersion: model.updates.availableVersion, captureMethod: "AppKit content capture from visible native windows; synthetic clipboard examples", captures: captures)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(report).write(to: destination.appendingPathComponent("report.json"), options: .atomic)
            RuntimeLog.event(.lifecycle, "Diagnostics complete: captures=\(captures.count)")
        } catch {
            RuntimeLog.event(.lifecycle, "Diagnostics failed", error: true)
            try? Data(error.localizedDescription.utf8).write(to: destination.appendingPathComponent("failure.txt"), options: .atomic)
        }
    }
}
