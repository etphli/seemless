import SwiftUI
import SeemlessCore

private enum CommandChoice {
    case clipboard, settings, toggleHistory, rescan
    case app(InstalledApp)
    case window(WindowTarget)
}

private enum CommandSection: String { case apps = "Applications", windows = "Windows", actions = "Actions" }

private struct CommandResult: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let shortcut: Shortcut?
    let section: CommandSection
    let choice: CommandChoice
}

struct CommandBarView: View {
    let model: AppModel
    @Environment(\.colorScheme) private var scheme
    @State private var query = ""
    @State private var selection = 0
    @State private var hoveredID: String?
    @State private var candidates: [CommandResult] = []
    @State private var results: [CommandResult] = []
    private var theme: SeemlessTheme { SeemlessTheme(scheme: scheme) }
    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        PanelShell {
            VStack(spacing: 0) {
                PanelSearch(query: $query, placeholder: "Search apps and actions", symbol: "magnifyingglass", onSubmit: runSelected, onClose: close)
                theme.line.frame(height: 1)
                if results.isEmpty {
                    PanelEmptyState(symbol: "magnifyingglass", title: "No matching actions", detail: "Try an app name, clipboard, or settings.")
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                    if showsHeader(at: index) {
                                        HStack {
                                            Text(isSearching ? "Search results" : result.section.rawValue)
                                            Spacer()
                                            if index == 0 {
                                                if model.catalog.isScanning { ProgressView().controlSize(.mini) }
                                                else { Text(isSearching ? "\(results.count) matches" : "\(model.catalog.apps.count) apps") }
                                            }
                                        }
                                        .font(.system(size: 10, weight: .medium)).foregroundStyle(theme.muted)
                                        .padding(.horizontal, 12).padding(.top, index == 0 ? 8 : 12).padding(.bottom, 5)
                                    }
                                    Button { run(result) } label: { row(result, isSelected: selection == index) }
                                        .buttonStyle(.plain).id(result.id)
                                        .onHover { hoveredID = $0 ? result.id : nil }
                                }
                            }.padding(.horizontal, 9).padding(.bottom, 10)
                        }
                        .onChange(of: selection) { _, value in
                            guard results.indices.contains(value) else { return }
                            withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(results[value].id, anchor: .center) }
                        }
                    }
                }
                theme.line.frame(height: 1)
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up").font(.system(size: 11)).foregroundStyle(theme.accent)
                    Text("Seemless").foregroundStyle(theme.secondary)
                    Spacer()
                    Text("↑ ↓").font(.system(size: 10, design: .monospaced))
                    Text("Navigate").padding(.trailing, 9)
                    ShortcutBadge(text: "↩")
                    Text("Open")
                }.font(.system(size: 10)).foregroundStyle(theme.muted).padding(.horizontal, 20).padding(.vertical, 9)
            }
        }
        .onAppear(perform: reloadCandidates)
        .onChange(of: query) { _, _ in updateResults(resetSelection: true) }
        .onChange(of: model.catalog.apps) { _, _ in reloadCandidates() }
        .onChange(of: model.settings.preferences) { _, _ in reloadCandidates() }
        .onChange(of: model.clipboard.isMonitoring) { _, _ in reloadCandidates() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in reloadCandidates() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in reloadCandidates() }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onExitCommand(perform: close)
    }

    private func showsHeader(at index: Int) -> Bool {
        index == 0 || (!isSearching && results[index].section != results[index - 1].section)
    }

    private func row(_ result: CommandResult, isSelected: Bool) -> some View {
        HStack(spacing: 11) {
            Group {
                if case .app(let app) = result.choice { Image(nsImage: model.catalog.icon(for: app)).resizable().scaledToFit() }
                else {
                    Image(systemName: result.symbol).font(.system(size: 14, weight: .regular))
                        .foregroundStyle(isSelected ? theme.accent : theme.secondary)
                        .frame(width: 28, height: 28).background(theme.raised, in: RoundedRectangle(cornerRadius: 7))
                }
            }.frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(result.title).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                Text(result.detail).font(.system(size: 10.5)).foregroundStyle(theme.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let shortcut = result.shortcut { ShortcutBadge(text: shortcut.display) }
            Image(systemName: "return").font(.system(size: 10)).foregroundStyle(theme.accent)
                .opacity(isSelected ? 1 : 0).frame(width: 14)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? theme.selection : hoveredID == result.id ? theme.raised : .clear, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(isSelected ? theme.accent.opacity(0.18) : .clear))
        .contentShape(Rectangle())
        .accessibilityLabel("\(result.title), \(result.detail)")
    }

    private func reloadCandidates() {
        let preferences = model.settings.preferences
        let running = Set(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.compactMap(\.bundleIdentifier))
        let ranked: [(InstalledApp, Int)] = model.catalog.apps.map { app in
            let favourite = preferences.favourites.contains(app.id) ? 0 : 4
            let assigned = preferences.shortcuts[ActionID.app(app.id)] != nil ? 0 : 2
            let active = running.contains(app.id) ? 0 : 1
            return (app, favourite + assigned + active)
        }
        let apps = ranked.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return lhs.0.name.localizedStandardCompare(rhs.0.name) == .orderedAscending
        }
        candidates = apps.map { app, _ in
            CommandResult(id: ActionID.app(app.id), title: app.name, detail: running.contains(app.id) ? "Running" : "Open application", symbol: "app", shortcut: preferences.shortcuts[ActionID.app(app.id)], section: .apps, choice: .app(app))
        }
        candidates += model.windowTargets.map { window in
            CommandResult(id: "window:\(window.app.processIdentifier):\(window.id)", title: window.title, detail: window.app.localizedName ?? "Window", symbol: "macwindow", shortcut: nil, section: .windows, choice: .window(window))
        }
        candidates += [
            CommandResult(id: "clipboard", title: "Clipboard history", detail: "Search and reuse recent copies", symbol: "doc.on.clipboard", shortcut: preferences.shortcuts[ActionID.clipboard], section: .actions, choice: .clipboard),
            CommandResult(id: "settings", title: "Settings", detail: "Shortcuts, applications, and preferences", symbol: "slider.horizontal.3", shortcut: nil, section: .actions, choice: .settings),
            CommandResult(id: "pause", title: model.clipboard.isMonitoring ? "Pause clipboard history" : "Start clipboard history", detail: "Control what Seemless remembers", symbol: model.clipboard.isMonitoring ? "pause" : "play", shortcut: nil, section: .actions, choice: .toggleHistory),
            CommandResult(id: "rescan", title: "Rescan installed apps", detail: "Find newly installed applications", symbol: "arrow.clockwise", shortcut: nil, section: .actions, choice: .rescan)
        ]
        updateResults(resetSelection: false)
    }

    private func updateResults(resetSelection: Bool) {
        let previousID = results.indices.contains(selection) ? results[selection].id : nil
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if search.isEmpty {
            results = Array(candidates.filter { $0.section == .apps }.prefix(4))
                + Array(candidates.filter { $0.section == .windows }.prefix(3))
                + candidates.filter { $0.id == "clipboard" || $0.id == "settings" }
        } else {
            results = candidates.enumerated().compactMap { index, item -> (CommandResult, Int, Int)? in
                guard let score = SearchScoring.score(search, in: item.title) else { return nil }
                return (item, score, index)
            }.sorted { $0.1 == $1.1 ? $0.2 < $1.2 : $0.1 < $1.1 }.map(\.0)
        }
        selection = resetSelection ? 0 : results.firstIndex { $0.id == previousID } ?? 0
        hoveredID = nil
    }

    private func move(_ offset: Int) { hoveredID = nil; selection = min(max(0, selection + offset), max(0, results.count - 1)) }
    private func close() { model.panels.dismiss(restoreFocus: true) }
    private func runSelected() { if results.indices.contains(selection) { run(results[selection]) } }
    private func run(_ result: CommandResult) {
        switch result.choice {
        case .clipboard: model.show(.clipboard)
        case .settings: model.panels.showSettings()
        case .app(let app): model.switchApp(app)
        case .window(let window): model.focusWindow(window)
        case .toggleHistory: model.setClipboardEnabled(!model.clipboard.isMonitoring); close()
        case .rescan: Task { await model.scanApps() }
        }
    }
}
