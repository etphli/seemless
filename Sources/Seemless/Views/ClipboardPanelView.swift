import SwiftUI
import SeemlessCore

private enum ClipboardFilter: String, CaseIterable { case all = "All", pinned = "Pinned", images = "Images" }

struct ClipboardPanelView: View {
    let model: AppModel
    @Environment(\.colorScheme) private var scheme
    @State private var query = ""
    @State private var filter: ClipboardFilter = .all
    @State private var selection: UUID?
    @State private var entries: [ClipboardEntry] = []
    private var theme: SeemlessTheme { SeemlessTheme(scheme: scheme) }
    private var selectedID: UUID? { selection ?? entries.first?.id }
    private var selected: ClipboardEntry? { entries.first { $0.id == selectedID } }
    private var canPaste: Bool { model.hasAccessibility && model.origin != nil }

    var body: some View {
        PanelShell {
            VStack(spacing: 0) {
                PanelSearch(query: $query, placeholder: "Search clipboard history", symbol: "doc.on.clipboard", onSubmit: useSelected, onClose: close)
                theme.line.frame(height: 1)
                HStack {
                    HStack(spacing: 2) {
                        ForEach(ClipboardFilter.allCases, id: \.self) { value in
                            Button { filter = value } label: {
                                Text(value.rawValue).font(.system(size: 10.5, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 5)
                                    .foregroundStyle(filter == value ? theme.text : theme.muted)
                                    .background(filter == value ? theme.raised : .clear, in: RoundedRectangle(cornerRadius: 5))
                            }.buttonStyle(.plain)
                        }
                    }.padding(3).background(theme.inset, in: RoundedRectangle(cornerRadius: 7))
                    Spacer()
                    Button { model.setClipboardEnabled(!model.clipboard.isMonitoring) } label: {
                        HStack(spacing: 6) {
                            Circle().fill(model.clipboard.isMonitoring ? Color.green : theme.muted).frame(width: 4, height: 4)
                            Text(model.clipboard.isMonitoring ? "Recording" : "Paused")
                            Image(systemName: model.clipboard.isMonitoring ? "pause" : "play").font(.system(size: 8))
                        }.font(.system(size: 10)).foregroundStyle(theme.secondary)
                    }.buttonStyle(.plain).help(model.clipboard.isMonitoring ? "Pause clipboard recording" : "Start clipboard recording")
                }.padding(.horizontal, 18).padding(.vertical, 10)
                theme.line.frame(height: 1)
                if entries.isEmpty {
                    PanelEmptyState(symbol: filter == .pinned ? "pin" : "doc.on.clipboard", title: query.isEmpty ? "Your next copy starts here" : "No matching copies", detail: model.clipboard.isMonitoring ? "Copy text, a link, or an image. Your recent copies will appear here." : "Start recording to keep future copies on this Mac. Your current clipboard stays private.")
                    if !model.clipboard.isMonitoring {
                        Button("Start recording") { model.setClipboardEnabled(true) }.buttonStyle(QuietButtonStyle(prominent: true)).padding(.bottom, 26)
                    }
                } else {
                    HStack(spacing: 0) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 3) {
                                    ForEach(entries) { entry in
                                        Button { selection = entry.id } label: { entryRow(entry, isSelected: selectedID == entry.id) }
                                            .buttonStyle(.plain).id(entry.id)
                                            .contextMenu {
                                                Button("Copy") { Task { await model.copy(entry, paste: false) } }
                                                Button(entry.isPinned ? "Unpin" : "Pin") { Task { await model.clipboard.togglePin(entry) } }
                                                Divider()
                                                Button("Delete", role: .destructive) { Task { await model.clipboard.remove(entry) } }
                                            }
                                    }
                                }.padding(9)
                            }.onChange(of: selection) { _, id in
                                if let id { withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(id, anchor: .center) } }
                            }
                        }.frame(maxWidth: .infinity)
                        theme.line.frame(width: 1)
                        if let selected { preview(selected).frame(width: 285).background(theme.inset.opacity(0.45)) }
                    }
                }
                if let error = model.clipboard.error { Text(error).font(.caption).foregroundStyle(.red).padding(10) }
                theme.line.frame(height: 1)
                HStack(spacing: 8) {
                    Image(systemName: "lock").font(.system(size: 9)).foregroundStyle(theme.muted)
                    Text("\(entries.count) items · Stored on this Mac").font(.system(size: 10)).foregroundStyle(theme.muted)
                    Spacer()
                    if let selected {
                        Button { Task { await model.clipboard.togglePin(selected) } } label: {
                            Image(systemName: selected.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 11)).foregroundStyle(selected.isPinned ? theme.accent : theme.secondary)
                                .frame(width: 26, height: 26)
                        }.buttonStyle(.plain).help(selected.isPinned ? "Unpin" : "Keep indefinitely")
                            .accessibilityLabel(selected.isPinned ? "Unpin item" : "Pin item")
                        Button { Task { await model.copy(selected, paste: false) } } label: {
                            HStack(spacing: 8) { Text("Copy"); if !canPaste { Text("↩").font(.system(size: 10, design: .monospaced)) } }
                        }.buttonStyle(QuietButtonStyle(prominent: !canPaste))
                        if canPaste {
                            Button { useSelected() } label: { HStack(spacing: 8) { Text("Paste"); Text("↩") } }
                                .buttonStyle(QuietButtonStyle(prominent: true))
                        }
                    }
                }.padding(.horizontal, 18).padding(.vertical, 9)
            }
        }
        .onAppear { refreshEntries() }
        .onChange(of: query) { _, _ in refreshEntries(resetSelection: true) }
        .onChange(of: filter) { _, _ in refreshEntries(resetSelection: true) }
        .onChange(of: model.clipboard.entries) { _, _ in refreshEntries() }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onExitCommand(perform: close)
        .task { await model.clipboard.refresh() }
    }

    private func entryRow(_ entry: ClipboardEntry, isSelected: Bool) -> some View {
        HStack(spacing: 11) {
            Group {
                if entry.payload.imageFileName != nil { ClipboardImage(entry: entry, store: model.clipboard, maximumSize: 96) }
                else {
                    Image(systemName: entry.payload.kind == "Link" ? "link" : "text.alignleft")
                        .font(.system(size: 14)).foregroundStyle(isSelected ? theme.accent : theme.secondary)
                        .frame(width: 30, height: 30).background(theme.raised, in: RoundedRectangle(cornerRadius: 7))
                }
            }.frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.payload.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                HStack(spacing: 5) {
                    Text(entry.sourceName).lineLimit(1)
                    Text("·")
                    Text(entry.copiedAt, style: .relative).lineLimit(1)
                }.font(.system(size: 10)).foregroundStyle(theme.muted)
            }
            Spacer(minLength: 4)
            if entry.isPinned { Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(theme.accent) }
        }
        .padding(.horizontal, 11).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? theme.selection : .clear, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(isSelected ? theme.accent.opacity(0.18) : .clear))
        .contentShape(Rectangle())
    }

    private func preview(_ entry: ClipboardEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Text("Preview").font(.system(size: 10, weight: .medium)).foregroundStyle(theme.muted)
                Spacer()
                Text(entry.payload.kind).font(.system(size: 9, weight: .medium)).foregroundStyle(theme.accent)
                    .padding(.horizontal, 6).padding(.vertical, 3).background(theme.selection, in: RoundedRectangle(cornerRadius: 4))
                Button { Task { await model.clipboard.remove(entry) } } label: { Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(theme.muted) }
                    .buttonStyle(.plain).help("Delete item").accessibilityLabel("Delete item")
            }
            ScrollView {
                if entry.payload.imageFileName != nil {
                    ClipboardImage(entry: entry, store: model.clipboard).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 7))
                } else {
                    Text(entry.payload.text ?? "").font(.system(size: 12)).lineSpacing(5).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).background(theme.raised, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            Spacer(minLength: 0)
            theme.line.frame(height: 1)
            metadata("Source", value: entry.sourceName)
            metadata("Copied", value: entry.copiedAt.formatted(date: .abbreviated, time: .shortened))
            HStack(spacing: 5) {
                Image(systemName: entry.isPinned ? "pin" : "clock").font(.system(size: 9))
                Text(entry.isPinned ? "Kept until you remove it" : "Expires after 7 days")
            }.font(.system(size: 10)).foregroundStyle(theme.muted)
        }.padding(18)
    }

    private func metadata(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(theme.muted)
            Spacer()
            Text(value).foregroundStyle(theme.secondary).lineLimit(1)
        }.font(.system(size: 10))
    }

    private func refreshEntries(resetSelection: Bool = false) {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        entries = model.clipboard.entries.filter {
            $0.matches(search) && (filter != .pinned || $0.isPinned) && (filter != .images || $0.payload.imageFileName != nil)
        }
        if resetSelection || !entries.contains(where: { $0.id == selection }) { selection = entries.first?.id }
    }

    private func move(_ offset: Int) {
        guard !entries.isEmpty else { return }
        let position = entries.firstIndex { $0.id == selectedID } ?? 0
        selection = entries[min(max(0, position + offset), entries.count - 1)].id
    }
    private func close() { model.panels.dismiss(restoreFocus: true) }
    private func useSelected() { if let selected { Task { await model.copy(selected, paste: canPaste) } } }
}
