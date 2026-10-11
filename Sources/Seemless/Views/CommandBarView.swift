import SwiftUI
import SeemlessCore

private enum CommandChoice {
    case clipboard, settings, toggleHistory, rescan
    case app(InstalledApp)
    case window(WindowTarget)
}

private struct CommandResult: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let shortcut: Shortcut?
    let choice: CommandChoice
}

struct CommandBarView: View {
    let model: AppModel
    @State private var query = ""
    @State private var selection = 0

    private var results: [CommandResult] {
        let preferences = model.settings.preferences
        var items = [
            CommandResult(id: "clipboard", title: "Clipboard history", detail: "Find and paste something you copied", symbol: "doc.on.clipboard", shortcut: preferences.shortcuts[ActionID.clipboard], choice: .clipboard),
            CommandResult(id: "settings", title: "Seemless settings", detail: "Customise shortcuts and preferences", symbol: "slider.horizontal.3", shortcut: nil, choice: .settings),
            CommandResult(id: "pause", title: model.clipboard.isMonitoring ? "Pause clipboard history" : "Start clipboard history", detail: "Control what Seemless remembers", symbol: model.clipboard.isMonitoring ? "pause.circle" : "play.circle", shortcut: nil, choice: .toggleHistory),
            CommandResult(id: "rescan", title: "Rescan installed apps", detail: "Find newly installed applications", symbol: "arrow.clockwise", shortcut: nil, choice: .rescan)
        ]
        let running = Set(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.compactMap(\.bundleIdentifier))
        let apps = model.catalog.apps.sorted { lhs, rhs in
            func priority(_ app: InstalledApp) -> Int {
                (preferences.favourites.contains(app.id) ? 0 : 4) + (preferences.shortcuts[ActionID.app(app.id)] != nil ? 0 : 2) + (running.contains(app.id) ? 0 : 1)
            }
            return priority(lhs) == priority(rhs) ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending : priority(lhs) < priority(rhs)
        }
        let visibleApps = query.isEmpty ? Array(apps.prefix(12)) : apps
        items += visibleApps.map { app in
            CommandResult(id: ActionID.app(app.id), title: app.name, detail: running.contains(app.id) ? "Application · Running" : "Application", symbol: "app", shortcut: preferences.shortcuts[ActionID.app(app.id)], choice: .app(app))
        }
        items += model.windowTargets.map { window in
            CommandResult(id: "window:\(window.app.processIdentifier):\(window.id)", title: window.title, detail: "Window · \(window.app.localizedName ?? "Application")", symbol: "macwindow", shortcut: nil, choice: .window(window))
        }
        guard !query.isEmpty else { return items }
        return items.compactMap { item -> (CommandResult, Int)? in
            guard let score = SearchScoring.score(query, in: item.title) else { return nil }
            return (item, score)
        }.sorted { $0.1 == $1.1 ? $0.0.title.localizedStandardCompare($1.0.title) == .orderedAscending : $0.1 < $1.1 }.map(\.0)
    }

    var body: some View {
        PanelShell {
            VStack(spacing: 0) {
                PanelSearch(query: $query, placeholder: "What would you like to do?", symbol: "command", onSubmit: runSelected, onClose: close)
                Divider()
                HStack {
                    Text(query.isEmpty ? "QUICK ACCESS" : "RESULTS").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.tertiary)
                    Spacer()
                    if model.catalog.isScanning { ProgressView().controlSize(.mini) }
                    else { Text("\(model.catalog.apps.count) apps available").font(.system(size: 11)).foregroundStyle(.tertiary) }
                }.padding(.horizontal, 24).padding(.top, 15).padding(.bottom, 7)
                if results.isEmpty {
                    PanelEmptyState(symbol: "magnifyingglass", title: "No matching actions", detail: "Try an app name, clipboard, or settings.")
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 3) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                    Button { run(result) } label: { row(result, isSelected: selection == index) }
                                        .buttonStyle(.plain).id(result.id)
                                        .onHover { if $0 { selection = index } }
                                }
                            }.padding(.horizontal, 10).padding(.bottom, 10)
                        }
                        .onChange(of: selection) { _, value in
                            guard results.indices.contains(value) else { return }
                            withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(results[value].id, anchor: .center) }
                        }
                    }
                }
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up").foregroundStyle(.secondary)
                    Text("Seemless").fontWeight(.medium)
                    Spacer()
                    Text("↑ ↓").font(.system(.caption, design: .monospaced))
                    Text("Navigate").foregroundStyle(.tertiary)
                    ShortcutBadge(text: "↩")
                    Text("Open").foregroundStyle(.secondary)
                }.font(.system(size: 11)).padding(.horizontal, 22).padding(.vertical, 12)
            }
        }
        .onChange(of: query) { _, _ in selection = 0 }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onExitCommand(perform: close)
    }

    private func row(_ result: CommandResult, isSelected: Bool) -> some View {
        HStack(spacing: 13) {
            Group {
                if case .app(let app) = result.choice { Image(nsImage: model.catalog.icon(for: app)).resizable().scaledToFit() }
                else { Image(systemName: result.symbol).font(.system(size: 19, weight: .regular)).foregroundStyle(.secondary) }
            }.frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(result.detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let shortcut = result.shortcut { ShortcutBadge(text: shortcut.display) }
            if isSelected { Image(systemName: "return").font(.system(size: 11)).foregroundStyle(.tertiary).frame(width: 16) }
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.primary.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
        .accessibilityLabel("\(result.title), \(result.detail)")
    }

    private func move(_ offset: Int) { selection = min(max(0, selection + offset), max(0, results.count - 1)) }
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
