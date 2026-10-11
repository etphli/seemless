import Foundation

public actor HistoryRepository {
    private let root: URL
    private let index: URL
    private var entries: [ClipboardEntry] = []
    private var loaded = false

    public init(root: URL) {
        self.root = root
        index = root.appendingPathComponent("history.json")
    }

    public func load(now: Date = Date()) throws -> [ClipboardEntry] {
        try prepare()
        try prune(now: now)
        return entries
    }

    public func insert(_ entry: ClipboardEntry, imageData: Data? = nil, now: Date = Date()) throws -> [ClipboardEntry] {
        try prepare()
        var updated = entries
        if let position = updated.firstIndex(where: { $0.fingerprint == entry.fingerprint }) {
            updated[position].copiedAt = entry.copiedAt
            updated[position].sourceName = entry.sourceName
            updated[position].sourceBundleID = entry.sourceBundleID
        } else {
            if let fileName = entry.payload.imageFileName {
                guard let imageData, imageData.count <= HistoryPolicy.maximumImageBytes else {
                    throw HistoryError.invalidImage
                }
                try imageData.write(to: imageURL(fileName), options: .atomic)
            }
            updated.insert(entry, at: 0)
        }
        try commit(updated)
        try prune(now: now)
        return entries
    }

    public func togglePin(_ id: UUID, now: Date = Date()) throws -> [ClipboardEntry] {
        try prepare()
        var updated = entries
        if let index = updated.firstIndex(where: { $0.id == id }) { updated[index].isPinned.toggle() }
        try commit(updated)
        try prune(now: now)
        return entries
    }

    public func remove(_ id: UUID) throws -> [ClipboardEntry] {
        try prepare()
        try removeEntries(entries.filter { $0.id != id })
        return entries
    }

    public func clearUnpinned() throws -> [ClipboardEntry] {
        try prepare()
        try removeEntries(entries.filter(\.isPinned))
        return entries
    }

    public func imageData(for entry: ClipboardEntry) throws -> Data? {
        guard let fileName = entry.payload.imageFileName else { return nil }
        return try Data(contentsOf: imageURL(fileName))
    }

    private func imageURL(_ fileName: String) throws -> URL {
        guard fileName == URL(fileURLWithPath: fileName).lastPathComponent,
              fileName.hasSuffix(".png"), !fileName.hasPrefix(".") else { throw HistoryError.invalidImage }
        return root.appendingPathComponent("images", isDirectory: true).appendingPathComponent(fileName)
    }

    private func prepare() throws {
        guard !loaded else { return }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("images"), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        if FileManager.default.fileExists(atPath: index.path) {
            entries = try JSONDecoder().decode([ClipboardEntry].self, from: Data(contentsOf: index))
            for entry in entries {
                if let fileName = entry.payload.imageFileName { _ = try imageURL(fileName) }
            }
        }
        loaded = true
    }

    private func commit(_ updated: [ClipboardEntry]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(updated).write(to: index, options: .atomic)
        entries = updated.sorted { $0.copiedAt > $1.copiedAt }
    }

    private func prune(now: Date) throws {
        let retained = HistoryPolicy.retaining(entries, now: now)
        if retained != entries { try removeEntries(retained) }
        let references = Set(entries.compactMap(\.payload.imageFileName))
        for url in try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("images"), includingPropertiesForKeys: nil) where url.pathExtension == "png" {
            if !references.contains(url.lastPathComponent) { try FileManager.default.removeItem(at: url) }
        }
    }

    private func removeEntries(_ retained: [ClipboardEntry]) throws {
        let removed = entries.filter { entry in !retained.contains { $0.id == entry.id } }
        try commit(retained)
        for entry in removed {
            if let fileName = entry.payload.imageFileName {
                let url = try imageURL(fileName)
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            }
        }
    }
}

public enum HistoryError: LocalizedError {
    case invalidImage
    public var errorDescription: String? { "This image cannot be saved. Clipboard images must be PNG files smaller than 20 MB." }
}
