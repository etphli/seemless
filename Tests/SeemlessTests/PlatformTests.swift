import AppKit
import Testing
import SeemlessCore
@testable import Seemless

@MainActor
struct PlatformTests {
    @Test
    func testNativePasteboardCapturesTextLinksAndImagesAndCopiesThemBack() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let pasteboard = NSPasteboard(name: .init("SeemlessTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let store = ClipboardStore(root: root, pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("A real pasteboard test", forType: .string)
        await store.captureChange(sourceName: "Test", sourceBundleID: "test.app")
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.payload == .text("A real pasteboard test"))
        pasteboard.clearContents()
        pasteboard.setString("https://example.com", forType: .string)
        await store.captureChange(sourceName: "Test", sourceBundleID: "test.app")
        #expect(store.entries.first?.payload == .link("https://example.com"))
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.bitmapData?.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
        let png = bitmap.representation(using: .png, properties: [:])!
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
        await store.captureChange(sourceName: "Test", sourceBundleID: "test.app")
        #expect(store.entries.count == 3)
        let image = try #require(store.entries.first)
        #expect(image.payload.kind == "Image")
        let thumbnail = await store.thumbnail(for: image, maximumSize: 1)
        let rendered = try #require(thumbnail)
        #expect(rendered.width == 1 && rendered.height == 1)
        let copied = await store.copy(image)
        #expect(copied)
        #expect(pasteboard.data(forType: .tiff) != nil)
        let text = try #require(store.entries.first { $0.payload.kind == "Text" })
        let textCopied = await store.copy(text)
        #expect(textCopied)
        #expect(pasteboard.string(forType: .string) == "A real pasteboard test")
    }

    @Test
    func testConcealedAndExcludedCopiesAreSkipped() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let pasteboard = NSPasteboard(name: .init("SeemlessTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let store = ClipboardStore(root: root, pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("concealed", forType: .string)
        pasteboard.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        await store.captureChange(sourceName: "Test", sourceBundleID: "test.app")
        #expect(store.entries.isEmpty)
        store.excludedApps = ["excluded.app"]
        pasteboard.clearContents()
        pasteboard.setString("excluded", forType: .string)
        await store.captureChange(sourceName: "Test", sourceBundleID: "excluded.app")
        #expect(store.entries.isEmpty)
    }

    @Test
    func testAppDiscoveryFindsNestedAppsAndSkipsEmbeddedHelpers() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        func makeBundle(_ path: String, id: String, background: Bool = false) throws {
            let contents = root.appendingPathComponent(path).appendingPathComponent("Contents")
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            let info: [String: Any] = ["CFBundleIdentifier": id, "CFBundleName": id, "CFBundlePackageType": "APPL", "LSBackgroundOnly": background]
            let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            try data.write(to: contents.appendingPathComponent("Info.plist"))
        }
        try makeBundle("One.app", id: "one.app")
        try makeBundle("Utilities/Two.app", id: "two.app")
        try makeBundle("One.app/Contents/Helpers/Helper.app", id: "helper.app")
        try makeBundle("Background.app", id: "background.app", background: true)
        let apps = AppCatalog.discover(roots: [root])
        #expect(Set(apps.map(\.id)) == ["one.app", "two.app"])
    }

    @Test
    func testSystemHotkeyRegistrationFlagsAnOccupiedCombination() async {
        _ = NSApplication.shared
        let first = HotkeyService()
        let second = HotkeyService()
        defer { first.stop(); second.stop() }
        let shortcut = Shortcut(keyCode: 106, keyName: "F16", modifiers: [.control, .option, .shift])
        #expect(first.register(["first": shortcut]).isEmpty)
        #expect(second.register(["second": shortcut])["second"] != nil)
    }

    @Test
    func testHyperEventTranslationHandlesReleaseOrderWithoutChangingKeyMappings() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = HyperService(root: root)
        func event(_ key: CGKeyCode, down: Bool) throws -> CGEvent {
            let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down))
            event.flags = []
            return event
        }
        #expect(service.handle(type: .keyDown, event: try event(79, down: true)) == nil)
        let letter = try event(11, down: true)
        #expect(service.handle(type: .keyDown, event: letter) != nil)
        #expect(letter.flags.contains([.maskCommand, .maskAlternate, .maskControl, .maskShift]))
        #expect(service.handle(type: .keyUp, event: try event(79, down: false)) == nil)
        let release = try event(11, down: false)
        _ = service.handle(type: .keyUp, event: release)
        #expect(release.flags.contains(.maskCommand))
        let normal = try event(2, down: true)
        _ = service.handle(type: .keyDown, event: normal)
        #expect(!(normal.flags.contains(.maskCommand)))
        #expect(!(FileManager.default.fileExists(atPath: root.path)))
    }
}
