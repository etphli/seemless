import Foundation
import Observation
import SeemlessCore

@MainActor @Observable
final class SettingsStore {
    private(set) var preferences = Preferences()
    var error: String?
    private let file: URL

    init(root: URL) {
        file = root.appendingPathComponent("settings.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do { preferences = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: file)) }
        catch {
            self.error = "Settings could not be loaded. A backup will be preserved before saving new settings."
        }
    }

    @discardableResult func update(_ change: (inout Preferences) -> Void) -> Bool {
        var updated = preferences
        change(&updated)
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            if error != nil, FileManager.default.fileExists(atPath: file.path) {
                try FileManager.default.copyItem(at: file, to: file.deletingLastPathComponent().appendingPathComponent("settings-backup-\(UUID().uuidString).json"))
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(updated).write(to: file, options: .atomic)
            preferences = updated
            error = nil
            return true
        } catch {
            self.error = "Settings could not be saved: \(error.localizedDescription)"
            return false
        }
    }
}
