import Testing
import Foundation
@testable import SeemlessCore

struct ShortcutAndMappingTests {
    @Test
    func testConflictUsesKeyCodeAndModifiersRegardlessOfDisplayName() {
        var preferences = Preferences()
        let shortcut = Shortcut(keyCode: 11, keyName: "B", modifiers: .hyper)
        preferences.shortcuts[ActionID.app("test.app")] = shortcut
        let sameKey = Shortcut(keyCode: 11, keyName: "Different layout", modifiers: .hyper)
        #expect(preferences.conflict(for: sameKey, excluding: ActionID.clipboard) == ActionID.app("test.app"))
        #expect(preferences.conflict(for: sameKey, excluding: ActionID.app("test.app")) == nil)
        #expect(Set([shortcut, sameKey]).count == 1)
        #expect(shortcut.isValid)
        #expect(!(Shortcut(keyCode: 11, keyName: "B", modifiers: [.shift]).isValid))
    }

    @Test
    func testHyperRestoresPriorCapsMappingAndPreservesOtherChanges() {
        let previous = KeyMapping(source: KeyMapping.capsLock, destination: 0x700000029)
        let other = KeyMapping(source: 1, destination: 2)
        let newer = KeyMapping(source: 3, destination: 4)
        let enabled = KeyMapping.enablingHyper(in: [previous, other])
        #expect(enabled == [other, .hyper])
        let restored = KeyMapping.restoringHyper(in: enabled + [newer], previousCaps: [previous])
        #expect(restored == [other, newer, previous])
        let externalCapsChange = KeyMapping(source: KeyMapping.capsLock, destination: 0x7000000E0)
        #expect(KeyMapping.restoringHyper(in: [other, externalCapsChange], previousCaps: [previous]) == [other, externalCapsChange])
    }

    @Test
    func testSearchRanksPrefixAndSupportsAbbreviations() {
        #expect(SearchScoring.score("clip", in: "Clipboard history") == 0)
        #expect(SearchScoring.score("history", in: "Clipboard history") == 1)
        #expect(SearchScoring.score("vsc", in: "Visual Studio Code") == 3)
        #expect(SearchScoring.score("xyz", in: "Clipboard history") == nil)
    }

    @Test
    func testOlderPreferencesKeepDefaultsForNewFields() throws {
        let preferences = try JSONDecoder().decode(Preferences.self, from: Data("{\"clipboardEnabled\":true}".utf8))
        #expect(preferences.clipboardEnabled)
        #expect(!(preferences.hyperEnabled))
        #expect(preferences.shortcuts[ActionID.commandBar] == .commandBar)
        #expect(!(preferences.excludedApps.isEmpty))
    }
}
