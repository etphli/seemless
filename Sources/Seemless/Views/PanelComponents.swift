import SwiftUI
import SeemlessCore

struct ShortcutBadge: View {
    let text: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let theme = SeemlessTheme(scheme: scheme)
        Text(text).font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(theme.secondary).padding(.horizontal, 6).padding(.vertical, 3)
            .background(theme.raised, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(theme.line))
    }
}

struct PanelShell<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let theme = SeemlessTheme(scheme: scheme)
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(theme.text)
            .tint(theme.accent)
            .background(theme.canvas.opacity(0.96))
            .background(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.line))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(1)
    }
}

struct PanelSearch: View {
    @Binding var query: String
    let placeholder: String
    let symbol: String
    let onSubmit: () -> Void
    let onClose: () -> Void
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = SeemlessTheme(scheme: scheme)
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .regular)).foregroundStyle(theme.accent)
                .frame(width: 24, height: 24)
            TextField(placeholder, text: $query).textFieldStyle(.plain)
                .font(.system(size: 16, weight: .regular)).focused($isFocused).onSubmit(onSubmit)
                .accessibilityLabel(placeholder)
            Button(action: onClose) { ShortcutBadge(text: "esc") }
                .buttonStyle(.plain).help("Close panel")
                .accessibilityLabel("Close panel")
        }
        .padding(.horizontal, 20).padding(.vertical, 17)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isFocused = true } }
    }
}

struct PanelEmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let theme = SeemlessTheme(scheme: scheme)
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 24, weight: .light)).foregroundStyle(theme.accent)
                .frame(width: 52, height: 52).background(theme.selection, in: RoundedRectangle(cornerRadius: 13))
            Text(title).font(.system(size: 14, weight: .medium)).padding(.top, 6)
            Text(detail).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 300)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
    }
}

struct ClipboardImage: View {
    let entry: ClipboardEntry
    let store: ClipboardStore
    var maximumSize = 600
    @State private var image: CGImage?
    var body: some View {
        Group {
            if let image { Image(decorative: image, scale: 1).resizable().scaledToFit() }
            else { Image(systemName: "photo").foregroundStyle(.secondary) }
        }
        .task(id: "\(entry.fingerprint):\(maximumSize)") {
            image = nil
            let thumbnail = await store.thumbnail(for: entry, maximumSize: maximumSize)
            if !Task.isCancelled { image = thumbnail }
        }
        .accessibilityLabel(entry.payload.title)
    }
}
