import SwiftUI
import SeemlessCore

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General", shortcuts = "Shortcuts", apps = "Applications", clipboard = "Clipboard"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .shortcuts: return "keyboard"
        case .apps: return "square.grid.2x2"
        case .clipboard: return "doc.on.clipboard"
        }
    }
    var subtitle: String {
        switch self {
        case .general: return "Shortcuts, focus, and everyday actions."
        case .shortcuts: return "Make your frequent actions immediate."
        case .apps: return "Choose your apps. Give each one a shortcut."
        case .clipboard: return "Keep useful copies close, and keep them local."
        }
    }
}

struct SettingsView: View {
    let model: AppModel
    @Environment(\.colorScheme) private var scheme
    private var theme: SeemlessTheme { SeemlessTheme(scheme: scheme) }
    @State private var section: SettingsSection = .general
    @State private var appQuery = ""
    @State private var recording: RecordingTarget?
    @State private var showClearConfirmation = false
    @State private var showExclusions = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    SeemlessMark(size: 28)
                    Text("Seemless").font(.system(size: 15, weight: .semibold)).tracking(-0.3)
                }.padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 25)
                List(selection: $section) {
                    ForEach(SettingsSection.allCases) { value in
                        HStack(spacing: 9) {
                            Image(systemName: value.symbol).frame(width: 18).foregroundStyle(section == value ? theme.accent : theme.secondary)
                            Text(value.rawValue).font(.system(size: 12, weight: .medium)).foregroundStyle(section == value ? theme.accent : theme.secondary)
                        }.tag(value).padding(.vertical, 4).listItemTint(theme.accent)
                    }
                }.listStyle(.sidebar).scrollContentBackground(.hidden)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) { Circle().fill(theme.accent).frame(width: 4, height: 4); Text("In your menu bar").font(.system(size: 10)).foregroundStyle(theme.secondary) }
                    Text("Version \(model.updates.currentVersion)").font(.system(size: 9)).foregroundStyle(theme.muted)
                    if let version = model.updates.availableVersion {
                        Button { model.updates.installAvailableUpdate() } label: {
                            HStack(spacing: 6) { Image(systemName: "arrow.down.circle"); Text("Update to \(version)") }
                        }.buttonStyle(QuietButtonStyle(prominent: true)).padding(.top, 6)
                    }
                }.padding(20)
            }.frame(width: 172).background(.bar)
            theme.line.frame(width: 1)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(section.rawValue).font(.system(size: 24, weight: .medium)).tracking(-0.6)
                        Text(section.subtitle).font(.system(size: 11.5)).foregroundStyle(theme.secondary)
                    }
                    Spacer()
                    Button { model.show(.commands) } label: { HStack(spacing: 6) { Image(systemName: "command"); Text("Open") } }.buttonStyle(QuietButtonStyle()).help("Open command bar")
                }.padding(.horizontal, 28).padding(.top, 25).padding(.bottom, 22)
                if let notice = model.notice ?? model.settings.error {
                    Text(notice).font(.caption).foregroundStyle(.red).padding(.horizontal, 28).padding(.bottom, 12)
                }
                switch section {
                case .general: general
                case .shortcuts: shortcuts
                case .apps: applications
                case .clipboard: clipboard
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(theme.text)
        .font(.system(size: 12))
        .tint(theme.accent)
        .background(theme.canvas)
        .groupBoxStyle(SettingsGroupStyle())
        .sheet(item: $recording) { ShortcutRecorder(model: model, action: $0.id) }
        .sheet(isPresented: $showExclusions) { ExclusionPicker(model: model) }
        .confirmationDialog("Clear unpinned clipboard history?", isPresented: $showClearConfirmation) {
            Button("Clear unpinned items", role: .destructive) { Task { await model.clipboard.clearUnpinned() } }
        } message: { Text("Pinned items will remain. Cleared items cannot be recovered.") }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.hasAccessibility = model.switcher.hasAccessibility }
    }

    private var general: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                sectionLabel("SHORTCUTS")
                GroupBox {
                    VStack(spacing: 0) {
                        settingsAction("Command bar", detail: "Search apps and actions", symbol: "command", action: ActionID.commandBar)
                        Divider().padding(.leading, 40)
                        settingsAction("Clipboard history", detail: "Search and reuse recent copies", symbol: "doc.on.clipboard", action: ActionID.clipboard)
                    }.padding(6)
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("HYPER KEY")
                    GroupBox {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Label("Caps Lock Hyper", systemImage: "capslock")
                                Spacer()
                                Toggle("Enable Caps Lock Hyper", isOn: Binding(get: { model.hyper.isEnabled }, set: { model.setHyperEnabled($0) })).labelsHidden().toggleStyle(.switch)
                            }
                            Text("Hold Caps Lock with a key to run its shortcut. Your original mapping returns when you disable Hyper or quit.")
                                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            if let error = model.hyper.error { Text(error).font(.caption).foregroundStyle(.red) }
                        }.padding(10)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("PERMISSIONS")
                    GroupBox {
                        HStack(alignment: .center, spacing: 15) {
                            Image(systemName: model.hasAccessibility ? "checkmark.shield" : "hand.raised").font(.system(size: 22)).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(model.hasAccessibility ? "Accessibility enabled" : "Accessibility").font(.system(size: 13, weight: .medium))
                                Text("Precise window focus, direct paste, and Caps Lock Hyper.").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            if !model.hasAccessibility { Button("Enable access") { model.requestAccessibility() }.buttonStyle(QuietButtonStyle(prominent: true)) }
                        }.padding(10)
                    }
                    Button("Input Monitoring settings ↗") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                    }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(theme.accent)
                }
            }.padding(.horizontal, 28).padding(.bottom, 28)
        }
    }

    private var shortcuts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sectionLabel("SEEMLESS")
                GroupBox {
                    VStack(spacing: 0) {
                        settingsAction("Command bar", detail: "Open the action launcher", symbol: "command", action: ActionID.commandBar)
                        Divider()
                        settingsAction("Clipboard history", detail: "Find text, links, and images", symbol: "doc.on.clipboard", action: ActionID.clipboard)
                    }.padding(6)
                }
                sectionLabel("APPLICATION SHORTCUTS")
                let assigned = model.settings.preferences.shortcuts.keys.filter { ActionID.bundleID(for: $0) != nil }.sorted { model.actionName($0) < model.actionName($1) }
                if assigned.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your first app shortcut").font(.system(size: 14, weight: .medium))
                        Text("Choose an installed app and give it a shortcut. Press it again to return to your previous app or window.").font(.system(size: 12)).foregroundStyle(.secondary)
                        Button("Choose an app") { section = .apps }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    GroupBox {
                        VStack(spacing: 0) {
                            ForEach(assigned, id: \.self) { action in
                                settingsAction(model.actionName(action), detail: "Open, focus, or return", symbol: "app", action: action)
                                if action != assigned.last { Divider() }
                            }
                        }.padding(6)
                    }
                }
                Text("Shortcuts work across apps. Conflicts within Seemless are blocked; shortcuts reserved by macOS or another app are flagged when registered.").font(.system(size: 11)).foregroundStyle(.tertiary)
            }.padding(.horizontal, 28).padding(.bottom, 28)
        }
    }

    private var applications: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                TextField("Search installed apps", text: $appQuery).textFieldStyle(.roundedBorder)
                Button("Add app…") { model.addApp() }
                Button { Task { await model.scanApps() } } label: { Image(systemName: "arrow.clockwise") }.help("Rescan installed apps").disabled(model.catalog.isScanning)
            }.padding(.horizontal, 28)
            HStack {
                Text("\(model.catalog.apps.count) installed apps").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text("Star apps for quick access").font(.system(size: 11)).foregroundStyle(.tertiary)
            }.padding(.horizontal, 28)
            Divider()
            if model.catalog.isScanning { ProgressView("Finding your apps…").padding(30) }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.catalog.apps.filter { appQuery.isEmpty || $0.name.localizedCaseInsensitiveContains(appQuery) }) { app in
                        appRow(app)
                        Divider().padding(.leading, 48)
                    }
                }.padding(.horizontal, 28)
            }
        }
    }

    private var clipboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Save clipboard history", isOn: Binding(get: { model.clipboard.isMonitoring }, set: { model.setClipboardEnabled($0) })).toggleStyle(.switch)
                        Text("Text, links, and images stay on this Mac for 7 days. Pinned items stay until you remove them. Recording starts with your next copy.")
                            .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }.padding(12)
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Excluded apps").font(.system(size: 13, weight: .medium))
                            Spacer()
                            Button("Choose apps…") { showExclusions = true }
                        }
                        Text("Copies from excluded apps, and copies marked concealed or temporary, are skipped. Password managers are excluded by default.").font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Text("Not every app marks sensitive content. Pause recording when copying something you don't want saved.").font(.system(size: 11)).foregroundStyle(.tertiary)
                    }.padding(12)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(model.clipboard.entries.count) saved items").font(.system(size: 13, weight: .medium))
                        Text("\(model.clipboard.entries.filter(\.isPinned).count) pinned · Images up to 20 MB").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open history") { model.show(.clipboard) }
                }
                Divider()
                HStack {
                    Text("Pinned items are kept when you clear history.").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear unpinned…", role: .destructive) { showClearConfirmation = true }.disabled(model.clipboard.entries.allSatisfy(\.isPinned))
                }
                if let error = model.clipboard.error { Text(error).font(.caption).foregroundStyle(.red) }
            }.padding(.horizontal, 28).padding(.bottom, 28)
        }
    }

    private func settingsAction(_ title: String, detail: String, symbol: String, action: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(theme.accent).frame(width: 30, height: 30).background(theme.selection, in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(model.shortcutFailures[action] ?? detail).font(.system(size: 11)).foregroundStyle(model.shortcutFailures[action] == nil ? Color.secondary : Color.red).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button { recording = RecordingTarget(id: action) } label: { ShortcutBadge(text: model.settings.preferences.shortcuts[action]?.display ?? "Set shortcut") }
                .buttonStyle(.plain).accessibilityLabel("Set shortcut for \(title)")
            if model.settings.preferences.shortcuts[action] != nil {
                Button {
                    _ = model.setShortcut(nil, for: action)
                    model.registerShortcuts()
                } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }.buttonStyle(.plain).help("Remove shortcut").accessibilityLabel("Remove shortcut for \(title)")
            }
        }.padding(.vertical, 10).padding(.horizontal, 7)
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: model.catalog.icon(for: app)).resizable().scaledToFit().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                if let failure = model.shortcutFailures[ActionID.app(app.id)] { Text(failure).font(.system(size: 10)).foregroundStyle(.red).lineLimit(2) }
            }
            Spacer()
            Button { model.toggleFavourite(app.id) } label: { Image(systemName: model.settings.preferences.favourites.contains(app.id) ? "star.fill" : "star").foregroundStyle(model.settings.preferences.favourites.contains(app.id) ? theme.accent : theme.muted) }.buttonStyle(.plain).help("Toggle quick access").accessibilityLabel("Toggle quick access for \(app.name)")
            Button { recording = RecordingTarget(id: ActionID.app(app.id)) } label: { ShortcutBadge(text: model.settings.preferences.shortcuts[ActionID.app(app.id)]?.display ?? "Set shortcut") }.buttonStyle(.plain).accessibilityLabel("Set shortcut for \(app.name)")
        }.padding(.vertical, 12)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .medium)).tracking(1.2).foregroundStyle(theme.muted)
    }
}

private struct SettingsGroupStyle: GroupBoxStyle {
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        let theme = SeemlessTheme(scheme: scheme)
        configuration.content
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.raised, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.line))
    }
}

private struct ExclusionPicker: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Exclude apps from clipboard history").font(.system(size: 18, weight: .semibold))
            TextField("Search apps", text: $query).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.catalog.apps.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { app in
                        Toggle(app.name, isOn: Binding(get: { model.settings.preferences.excludedApps.contains(app.id) }, set: { excluded in
                            if model.settings.update({ preferences in
                                if excluded { preferences.excludedApps.insert(app.id) }
                                else { preferences.excludedApps.remove(app.id) }
                            }) { model.clipboard.excludedApps = model.settings.preferences.excludedApps }
                        })).toggleStyle(.checkbox)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(2)
            }
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(25).frame(width: 430, height: 440)
    }
}
