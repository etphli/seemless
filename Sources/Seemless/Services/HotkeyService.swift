import AppKit
import Carbon
import SeemlessCore

@MainActor
final class HotkeyService {
    private var references: [String: EventHotKeyRef] = [:]
    private var actions: [UInt32: String] = [:]
    private var handler: EventHandlerRef?
    var onAction: ((String) -> Void)?
    private let signature: OSType = 0x53454D4C

    init() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, pointer in
            guard let event, let pointer else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard result == noErr else { return result }
            let service = Unmanaged<HotkeyService>.fromOpaque(pointer).takeUnretainedValue()
            MainActor.assumeIsolated {
                if let action = service.actions[id.id] { service.onAction?(action) }
            }
            return noErr
        }, 1, &event, pointer, &handler)
    }

    func register(_ shortcuts: [String: Shortcut]) -> [String: String] {
        suspend()
        var failures: [String: String] = [:]
        for (index, item) in shortcuts.sorted(by: { $0.key < $1.key }).enumerated() {
            let (action, shortcut) = item
            guard shortcut.isValid else { failures[action] = "Choose a key with Command, Option, Control, or Hyper."; continue }
            let id = UInt32(index + 1)
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(shortcut.keyCode), shortcut.modifiers.carbonFlags, EventHotKeyID(signature: signature, id: id), GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference {
                references[action] = reference
                actions[id] = action
            } else { failures[action] = "This shortcut is unavailable. It may be reserved by macOS or another app." }
        }
        return failures
    }

    func suspend() {
        references.values.forEach { UnregisterEventHotKey($0) }
        references.removeAll()
        actions.removeAll()
    }

    func stop() {
        suspend()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}

extension ShortcutModifiers {
    var carbonFlags: UInt32 {
        var value: UInt32 = 0
        if contains(.command) { value |= UInt32(cmdKey) }
        if contains(.option) { value |= UInt32(optionKey) }
        if contains(.control) { value |= UInt32(controlKey) }
        if contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }

    init(eventFlags: NSEvent.ModifierFlags) {
        var value: Self = []
        if eventFlags.contains(.command) { value.insert(.command) }
        if eventFlags.contains(.option) { value.insert(.option) }
        if eventFlags.contains(.control) { value.insert(.control) }
        if eventFlags.contains(.shift) { value.insert(.shift) }
        self = value
    }
}
