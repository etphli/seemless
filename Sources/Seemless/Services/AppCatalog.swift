import AppKit
import Observation

struct InstalledApp: Identifiable, Hashable, Sendable {
    let bundleID: String
    let name: String
    let url: URL
    var id: String { bundleID }
}

@MainActor @Observable
final class AppCatalog {
    private(set) var apps: [InstalledApp] = []
    private(set) var isScanning = false
    private var icons: [String: NSImage] = [:]

    func scan(additionalURLs: [URL] = []) async {
        guard !isScanning else { return }
        isScanning = true
        let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleURL) + additionalURLs
        apps = await Task.detached(priority: .userInitiated) {
            Self.discover(roots: Self.defaultRoots, additionalURLs: running)
        }.value
        icons.removeAll()
        isScanning = false
    }

    func icon(for app: InstalledApp) -> NSImage {
        if let cached = icons[app.id] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: app.url.path)
        icons[app.id] = icon
        return icon
    }

    nonisolated static var defaultRoots: [URL] {
        ["/Applications", "/System/Applications", "/System/Library/CoreServices/Applications"].map { URL(fileURLWithPath: $0) }
            + [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
    }

    nonisolated static func discover(roots: [URL], additionalURLs: [URL] = []) -> [InstalledApp] {
        var urls = additionalURLs
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in enumerator {
                if url.pathExtension.lowercased() == "app" {
                    urls.append(url)
                    enumerator.skipDescendants()
                }
            }
        }
        var unique: [String: InstalledApp] = [:]
        for url in urls {
            guard let bundle = Bundle(url: url), let info = bundle.infoDictionary,
                  info["LSBackgroundOnly"] as? Bool != true else { continue }
            let id = bundle.bundleIdentifier ?? url.path
            guard id != "com.etphli.seemless", unique[id] == nil else { continue }
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            unique[id] = InstalledApp(bundleID: id, name: name, url: url)
        }
        return unique.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
