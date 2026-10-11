import SwiftUI
import SeemlessCore

private enum ClipboardFilter: String, CaseIterable { case all = "All", pinned = "Pinned", images = "Images" }

struct ClipboardPanelView: View {
    let model: AppModel
    @State private var query = ""
    @State private var filter: ClipboardFilter = .all
    @State private var selection: UUID?

    private var entries: [ClipboardEntry] {
        model.clipboard.entries.filter {
            $0.matches(query) && (filter != .pinned || $0.isPinned) && (filter != .images || $0.payload.imageFileName != nil)
        }
    }
    private var selected: ClipboardEntry? { entries.first { $0.id == selection } ?? entries.first }
    private var canPaste: Bool { model.hasAccessibility && model.origin != nil }

    var body: some View {
        PanelShell {
            VStack(spacing: 0) {
                PanelSearch(query: $query, placeholder: "Search your clipboard…", symbol: "doc.on.clipboard", onSubmit: useSelected, onClose: close)
                Divider()
                HStack(spacing: 8) {
                    ForEach(ClipboardFilter.allCases, id: \.self) { value in
                        Button { filter = value; selection = nil } label: {
                            Text(value.rawValue).font(.system(size: 11, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 6)
                                .foregroundStyle(filter == value ? .primary : .secondary)
                                .background(filter == value ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                    Button { model.setClipboardEnabled(!model.clipboard.isMonitoring) } label: {
                        HStack(spacing: 5) {
                            Circle().fill(model.clipboard.isMonitoring ? Color.green : Color.secondary).frame(width: 5, height: 5)
                            Text(model.clipboard.isMonitoring ? "Recording" : "Paused")
                        }.font(.system(size: 11)).foregroundStyle(.secondary)
                    }.buttonStyle(.plain).help(model.clipboard.isMonitoring ? "Pause clipboard recording" : "Start clipboard recording")
                }.padding(.horizontal, 17).padding(.vertical, 10)
                Divider()
                if entries.isEmpty {
                    PanelEmptyState(symbol: filter == .pinned ? "pin" : "doc.on.clipboard", title: query.isEmpty ? "Nothing here yet" : "No matching copies", detail: model.clipboard.isMonitoring ? "Copy text, a link, or an image in another app. Your recent copies will appear here." : "Start recording to save future copies on this Mac. Existing clipboard content isn't imported.")
                    if !model.clipboard.isMonitoring {
                        Button("Start clipboard history") { model.setClipboardEnabled(true) }.buttonStyle(.bordered).padding(.bottom, 30)
                    }
                } else {
                    HStack(spacing: 0) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 3) {
                                    ForEach(entries) { entry in
                                        Button { selection = entry.id } label: { entryRow(entry) }
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
                                if let id { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id, anchor: .center) } }
                            }
                        }.frame(maxWidth: .infinity)
                        Divider()
                        if let selected { preview(selected).frame(width: 270) }
                    }
                }
                if let error = model.clipboard.error { Text(error).font(.caption).foregroundStyle(.red).padding(10) }
                Divider()
                HStack(spacing: 10) {
                    Text("\(entries.count) items · On this Mac").font(.system(size: 11)).foregroundStyle(.tertiary)
                    Spacer()
                    if let selected {
                        Button { Task { await model.clipboard.togglePin(selected) } } label: { Image(systemName: selected.isPinned ? "pin.fill" : "pin") }
                            .buttonStyle(.plain).foregroundStyle(.secondary).help(selected.isPinned ? "Unpin" : "Keep indefinitely")
                            .accessibilityLabel(selected.isPinned ? "Unpin item" : "Pin item")
                        Button("Copy") { Task { await model.copy(selected, paste: false) } }.buttonStyle(.borderless)
                        if canPaste { Button("Paste ↩") { useSelected() }.buttonStyle(.borderedProminent).controlSize(.small) }
                        else { ShortcutBadge(text: "↩ Copy") }
                    }
                }.padding(.horizontal, 20).padding(.vertical, 12)
            }
        }
        .onChange(of: query) { _, _ in selection = nil }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onExitCommand(perform: close)
        .task { await model.clipboard.refresh() }
    }

    private func entryRow(_ entry: ClipboardEntry) -> some View {
        HStack(spacing: 12) {
            Group {
                if entry.payload.imageFileName != nil { ClipboardImage(entry: entry, store: model.clipboard, maximumSize: 96) }
                else { Image(systemName: entry.payload.kind == "Link" ? "link" : "text.alignleft").font(.system(size: 17)).foregroundStyle(.secondary) }
            }.frame(width: 34, height: 34).clipShape(RoundedRectangle(cornerRadius: 5))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.payload.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                HStack(spacing: 5) {
                    Text(entry.sourceName).lineLimit(1)
                    Text("·")
                    Text(entry.copiedAt, style: .relative).lineLimit(1)
                }.font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            if entry.isPinned { Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 10).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected?.id == entry.id ? Color.primary.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private func preview(_ entry: ClipboardEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(entry.payload.kind.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.tertiary)
                Spacer()
                Button { Task { await model.clipboard.remove(entry) } } label: { Image(systemName: "trash").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain).help("Delete item").accessibilityLabel("Delete item")
            }
            ScrollView {
                if entry.payload.imageFileName != nil { ClipboardImage(entry: entry, store: model.clipboard).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 7)) }
                else { Text(entry.payload.text ?? "").font(.system(size: 12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            }
            Spacer(minLength: 0)
            Divider()
            Text(entry.sourceName).font(.system(size: 11, weight: .medium))
            Text(entry.copiedAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(entry.isPinned ? "Pinned · Kept until you remove it" : "Expires after 7 days").font(.system(size: 10)).foregroundStyle(.tertiary)
        }.padding(20)
    }

    private func move(_ offset: Int) {
        guard !entries.isEmpty else { return }
        let position = entries.firstIndex { $0.id == selected?.id } ?? 0
        selection = entries[min(max(0, position + offset), entries.count - 1)].id
    }
    private func close() { model.panels.dismiss(restoreFocus: true) }
    private func useSelected() { if let selected { Task { await model.copy(selected, paste: canPaste) } } }
}
