import SwiftUI
import ImageIO
import SeemlessCore

struct ShortcutBadge: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary).padding(.horizontal, 7).padding(.vertical, 4)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.08)))
    }
}

struct PanelShell<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.13)))
            .clipShape(RoundedRectangle(cornerRadius: 18))
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

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 19, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
            TextField(placeholder, text: $query).textFieldStyle(.plain)
                .font(.system(size: 19)).focused($isFocused).onSubmit(onSubmit)
                .accessibilityLabel(placeholder)
            Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary).frame(width: 24, height: 24) }
                .buttonStyle(.plain).help("Close panel")
                .accessibilityLabel("Close panel")
        }
        .padding(.horizontal, 22).padding(.vertical, 20)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isFocused = true } }
    }
}

struct PanelEmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 30, weight: .light)).foregroundStyle(.tertiary)
            Text(title).font(.system(size: 15, weight: .semibold))
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
        .task(id: entry.id) {
            guard let data = try? await store.repository.imageData(for: entry) else { return }
            let limit = maximumSize
            let thumbnail = await Task.detached(priority: .utility) {
                guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil as CGImage? }
                return CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: limit, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary)
            }.value
            if !Task.isCancelled { image = thumbnail }
        }
        .accessibilityLabel(entry.payload.title)
    }
}
