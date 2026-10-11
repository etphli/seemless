import SwiftUI
import SeemlessCore

struct RecordingTarget: Identifiable { let id: String }

struct ShortcutRecorder: View {
    let model: AppModel
    let action: String
    @Environment(\.dismiss) private var dismiss
    @State private var useHyper = false
    @State private var candidate: Shortcut?
    @State private var error: String?
    @State private var monitor: Any?
    @State private var isListening = true

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "keyboard").font(.system(size: 28, weight: .light)).foregroundStyle(.secondary)
            Text("Set a shortcut").font(.system(size: 20, weight: .semibold))
            Text(model.actionName(action)).font(.system(size: 13)).foregroundStyle(.secondary)
            Picker("Shortcut type", selection: $useHyper) {
                Text("Standard").tag(false)
                Text("Hyper").tag(true)
            }.pickerStyle(.segmented).frame(width: 220)
            Button { candidate = nil; error = nil; isListening = true } label: {
                Text(candidate?.display ?? "Press your shortcut")
                    .font(.system(size: 23, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity).frame(height: 65)
                    .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).help("Record another shortcut")
            Text(useHyper ? "Press a key to pair with Hyper. Enable Caps Lock Hyper in General to use it." : "Hold Command, Option, or Control, then press a key. Escape cancels.")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(height: 35)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save shortcut") {
                    guard let candidate else { return }
                    if let message = model.setShortcut(candidate, for: action) { error = message }
                    else { dismiss() }
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(candidate == nil || error != nil)
            }
        }
        .padding(30).frame(width: 390)
        .onChange(of: useHyper) { _, _ in candidate = nil; error = nil; isListening = true }
        .onAppear {
            model.hotkeys.suspend()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { dismiss(); return nil }
                guard isListening else { return event }
                if event.keyCode == 48, ShortcutModifiers(eventFlags: event.modifierFlags).isEmpty { return event }
                guard !event.isARepeat else { return nil }
                let shortcut = Shortcut(keyCode: event.keyCode, keyName: KeyNames.name(event), modifiers: useHyper ? .hyper : ShortcutModifiers(eventFlags: event.modifierFlags))
                if !shortcut.isValid { error = "Use Command, Option, Control, or Hyper with a non-modifier key."; candidate = nil }
                else if let conflict = model.settings.preferences.conflict(for: shortcut, excluding: action) {
                    candidate = shortcut
                    error = "Already assigned to \(model.actionName(conflict))."
                } else { candidate = shortcut; error = nil; isListening = false }
                return nil
            }
        }
        .onDisappear {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            model.registerShortcuts()
        }
    }
}

enum KeyNames {
    static func name(_ event: NSEvent) -> String {
        let special: [UInt16: String] = [36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 76: "Enter", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑", 122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 80: "F19", 90: "F20"]
        if let name = special[event.keyCode] { return name }
        if let value = event.charactersIgnoringModifiers, !value.isEmpty,
           value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
            return value.uppercased()
        }
        return "Key \(event.keyCode)"
    }
}
