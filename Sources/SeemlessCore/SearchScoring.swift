import Foundation

public enum SearchScoring {
    public static func score(_ query: String, in value: String) -> Int? {
        let query = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let value = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if query.isEmpty { return 0 }
        if value.hasPrefix(query) { return 0 }
        if value.contains(query) { return 1 }
        if query.split(separator: " ").allSatisfy({ value.contains($0) }) { return 2 }
        var cursor = value.startIndex
        for character in query where character != " " {
            guard let found = value[cursor...].firstIndex(of: character) else { return nil }
            cursor = value.index(after: found)
        }
        return 3
    }
}
