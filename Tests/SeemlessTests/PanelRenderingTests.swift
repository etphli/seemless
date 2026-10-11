import AppKit
import SwiftUI
import Testing
import SeemlessCore
@testable import Seemless

@MainActor
struct PanelRenderingTests {
    @Test
    func testPanelsRenderAtTheirNativeSizesInBothAppearances() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        _ = NSApplication.shared
        let model = AppModel(root: root)
        defer { model.stop() }
        model.panels = PanelCoordinator(model: model)
        await model.scanApps()
        _ = try await model.clipboard.repository.insert(ClipboardEntry(fingerprint: "example-text", payload: .text("Small actions, fewer steps.\n\nOpen the app you need, reuse a recent copy, and get back to your work."), isPinned: true, sourceName: "Notes"))
        _ = try await model.clipboard.repository.insert(ClipboardEntry(fingerprint: "example-link", payload: .link("https://developer.apple.com"), sourceName: "Safari"))
        await model.clipboard.refresh()
        let destination = ProcessInfo.processInfo.environment["SEEMLESS_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
        for scheme in [ColorScheme.dark, .light] {
            let suffix = scheme == .dark ? "dark" : "light"
            try await render(CommandBarView(model: model), size: NSSize(width: 640, height: 480), scheme: scheme, name: "commands-\(suffix)", destination: destination)
            try await render(ClipboardPanelView(model: model), size: NSSize(width: 780, height: 520), scheme: scheme, name: "clipboard-\(suffix)", destination: destination)
            try await render(SettingsView(model: model), size: NSSize(width: 840, height: 620), scheme: scheme, name: "settings-\(suffix)", destination: destination)
        }
    }

    private func render<V: View>(_ content: V, size: NSSize, scheme: ColorScheme, name: String, destination: URL?) async throws {
        let hosting = NSHostingView(rootView: content.environment(\.colorScheme, scheme))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = hosting
        hosting.setFrameSize(size)
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        #expect(png.count > 2000)
        if let destination {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try png.write(to: destination.appendingPathComponent(name + ".png"))
        }
        window.contentView = nil
        window.close()
    }
}
