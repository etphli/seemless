import Foundation

public enum ClipboardPayload: Codable, Equatable, Sendable {
    case text(String)
    case link(String)
    case image(fileName: String, width: Int, height: Int)

    public var text: String? {
        switch self {
        case .text(let value), .link(let value): return value
        case .image: return nil
        }
    }

    public var imageFileName: String? {
        if case .image(let name, _, _) = self { return name }
        return nil
    }

    public var kind: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        }
    }

    public var title: String {
        switch self {
        case .text(let value), .link(let value):
            return String(value.split(whereSeparator: \.isNewline).first.map(String.init) ?? value).prefix(120).description
        case .image(_, let width, let height): return "Image · \(width) × \(height)"
        }
    }
}

public struct ClipboardEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let fingerprint: String
    public var payload: ClipboardPayload
    public var copiedAt: Date
    public var isPinned: Bool
    public var sourceName: String
    public var sourceBundleID: String?

    public init(id: UUID = UUID(), fingerprint: String, payload: ClipboardPayload, copiedAt: Date = Date(), isPinned: Bool = false, sourceName: String, sourceBundleID: String? = nil) {
        self.id = id
        self.fingerprint = fingerprint
        self.payload = payload
        self.copiedAt = copiedAt
        self.isPinned = isPinned
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
    }

    public func matches(_ query: String) -> Bool {
        query.isEmpty || [payload.title, payload.text ?? "", sourceName, payload.kind]
            .contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

public enum HistoryPolicy {
    public static let retention: TimeInterval = 7 * 24 * 60 * 60
    public static let maximumImageBytes = 20 * 1024 * 1024

    public static func retaining(_ entries: [ClipboardEntry], now: Date) -> [ClipboardEntry] {
        entries.filter { $0.isPinned || now.timeIntervalSince($0.copiedAt) < retention }
            .sorted { $0.copiedAt > $1.copiedAt }
    }
}
