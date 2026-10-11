import Foundation
import OSLog

@MainActor
enum RuntimeLog {
    enum Category: String { case lifecycle, shortcuts, windows, clipboard, updates }
    private struct Entry: Encodable {
        let timestamp: String
        let category: String
        let level: String
        let message: String
    }
    private static var file: FileHandle?

    static func configureFile(_ url: URL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
                    throw CocoaError(.fileWriteUnknown)
                }
            }
            try file?.close()
            file = try FileHandle(forWritingTo: url)
            try file?.seekToEnd()
        } catch {
            Logger(subsystem: "com.etphli.seemless", category: "Lifecycle").error("Local diagnostic log could not be opened")
        }
    }

    static func event(_ category: Category, _ message: String, error: Bool = false) {
        let logger = Logger(subsystem: "com.etphli.seemless", category: category.rawValue)
        if error { logger.error("\(message, privacy: .public)") }
        else { logger.info("\(message, privacy: .public)") }
        guard let file else { return }
        do {
            let entry = Entry(timestamp: Date.now.ISO8601Format(), category: category.rawValue, level: error ? "error" : "info", message: message)
            var data = try JSONEncoder().encode(entry)
            data.append(0x0a)
            try file.write(contentsOf: data)
        } catch { logger.error("Local diagnostic log write failed") }
    }
}
