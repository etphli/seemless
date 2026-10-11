import AppKit
import ApplicationServices
import Observation
import SeemlessCore

@MainActor @Observable
final class HyperService {
    private(set) var isEnabled = false
    var error: String?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var isHeld = false
    private var modifiedKeys: Set<Int64> = []
    private let lease: URL

    init(root: URL) { lease = root.appendingPathComponent("hyper-recovery.json") }

    func recover() {
        guard FileManager.default.fileExists(atPath: lease.path) else { return }
        do {
            let previous = try JSONDecoder().decode([KeyMapping].self, from: Data(contentsOf: lease))
            let current = try readMappings()
            try writeMappings(KeyMapping.restoringHyper(in: current, previousCaps: previous))
            try FileManager.default.removeItem(at: lease)
            error = nil
        } catch { self.error = "Caps Lock restoration needs attention: \(error.localizedDescription)" }
    }

    func enable() {
        guard !isEnabled else { return }
        recover()
        guard error == nil else { return }
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, pointer in
            guard let pointer else { return Unmanaged.passUnretained(event) }
            let service = Unmanaged<HyperService>.fromOpaque(pointer).takeUnretainedValue()
            return MainActor.assumeIsolated { service.handle(type: type, event: event) }
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            error = "Allow Accessibility and Input Monitoring for Seemless in System Settings, then try again."
            return
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
        do {
            let current = try readMappings()
            guard !current.contains(where: { $0.source != KeyMapping.capsLock && $0.destination == KeyMapping.f18 }) else {
                throw HyperError.reservedKey
            }
            let previous = current.filter { $0.source == KeyMapping.capsLock }
            try FileManager.default.createDirectory(at: lease.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(previous).write(to: lease, options: .atomic)
            try writeMappings(KeyMapping.enablingHyper(in: current))
            isEnabled = true
            error = nil
        } catch {
            stopTap()
            recover()
            self.error = error.localizedDescription
        }
    }

    func disable() {
        stopTap()
        isEnabled = false
        error = nil
        recover()
    }

    private func stopTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        isHeld = false
        modifiedKeys.removeAll()
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            isHeld = false
            modifiedKeys.removeAll()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if key == 79 {
            if type == .keyDown { isHeld = true }
            if type == .keyUp { isHeld = false }
            return nil
        }
        if isHeld || modifiedKeys.contains(key) {
            event.flags.formUnion([.maskCommand, .maskAlternate, .maskControl, .maskShift])
            if type == .keyDown { modifiedKeys.insert(key) }
            if type == .keyUp { modifiedKeys.remove(key) }
        }
        return Unmanaged.passUnretained(event)
    }

    private func readMappings() throws -> [KeyMapping] {
        let output = try runHidutil(["property", "--get", "UserKeyMapping"])
        if output.trimmingCharacters(in: .whitespacesAndNewlines) == "(null)" { return [] }
        let parsed = try PropertyListSerialization.propertyList(from: Data(output.utf8), options: [], format: nil)
        guard let values = parsed as? [[String: Any]] else { throw HyperError.unreadableMapping }
        return try values.map { value in
            func number(_ key: String) throws -> UInt64 {
                if let number = value[key] as? NSNumber { return number.uint64Value }
                if let string = value[key] as? String, let number = UInt64(string) { return number }
                throw HyperError.unreadableMapping
            }
            return try KeyMapping(source: number("HIDKeyboardModifierMappingSrc"), destination: number("HIDKeyboardModifierMappingDst"))
        }
    }

    private func writeMappings(_ mappings: [KeyMapping]) throws {
        let data = try JSONEncoder().encode(["UserKeyMapping": mappings])
        _ = try runHidutil(["property", "--set", String(decoding: data, as: UTF8.self)])
        guard try readMappings() == mappings else { throw HyperError.mappingRejected }
    }

    private func runHidutil(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw HyperError.mappingRejected }
        return String(decoding: data, as: UTF8.self)
    }
}

enum HyperError: LocalizedError {
    case reservedKey, unreadableMapping, mappingRejected
    var errorDescription: String? {
        switch self {
        case .reservedKey: return "Another key mapping already uses F18. Remove that mapping before enabling Caps Lock Hyper."
        case .unreadableMapping: return "The current keyboard mapping could not be read. No mapping has been intentionally replaced."
        case .mappingRejected: return "macOS did not accept the keyboard mapping. Check keyboard permissions or other key remapping tools."
        }
    }
}
