import Foundation

public struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let command = Self(rawValue: 1)
    public static let option = Self(rawValue: 2)
    public static let control = Self(rawValue: 4)
    public static let shift = Self(rawValue: 8)
    public static let hyper: Self = [.command, .option, .control, .shift]
}

public struct Shortcut: Codable, Hashable, Sendable {
    public var keyCode: UInt16
    public var keyName: String
    public var modifiers: ShortcutModifiers

    public init(keyCode: UInt16, keyName: String, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.keyName = keyName
        self.modifiers = modifiers
    }

    public static let commandBar = Self(keyCode: 49, keyName: "Space", modifiers: [.command, .option])
    public static let clipboard = Self(keyCode: 9, keyName: "V", modifiers: [.command, .shift])

    public var display: String {
        if modifiers == .hyper { return "Hyper + \(keyName)" }
        return (modifiers.contains(.control) ? "⌃" : "")
            + (modifiers.contains(.option) ? "⌥" : "")
            + (modifiers.contains(.shift) ? "⇧" : "")
            + (modifiers.contains(.command) ? "⌘" : "") + keyName
    }

    public var isValid: Bool {
        !modifiers.intersection([.command, .option, .control]).isEmpty
            && ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 79].contains(keyCode)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers)
    }
}

public enum ActionID {
    public static let commandBar = "command-bar"
    public static let clipboard = "clipboard"
    public static func app(_ bundleID: String) -> String { "app:\(bundleID)" }
    public static func bundleID(for action: String) -> String? {
        action.hasPrefix("app:") ? String(action.dropFirst(4)) : nil
    }
}

public struct Preferences: Codable, Equatable, Sendable {
    public var shortcuts: [String: Shortcut] = [ActionID.commandBar: .commandBar, ActionID.clipboard: .clipboard]
    public var favourites: Set<String> = []
    public var clipboardEnabled = false
    public var hyperEnabled = false
    public var customAppPaths: [String] = []
    public var excludedApps: Set<String> = ["com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop"]

    public init() {}

    private enum CodingKeys: String, CodingKey { case shortcuts, favourites, clipboardEnabled, hyperEnabled, excludedApps, customAppPaths }

    public init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        shortcuts = try values.decodeIfPresent([String: Shortcut].self, forKey: .shortcuts) ?? shortcuts
        favourites = try values.decodeIfPresent(Set<String>.self, forKey: .favourites) ?? favourites
        clipboardEnabled = try values.decodeIfPresent(Bool.self, forKey: .clipboardEnabled) ?? clipboardEnabled
        hyperEnabled = try values.decodeIfPresent(Bool.self, forKey: .hyperEnabled) ?? hyperEnabled
        customAppPaths = try values.decodeIfPresent([String].self, forKey: .customAppPaths) ?? customAppPaths
        excludedApps = try values.decodeIfPresent(Set<String>.self, forKey: .excludedApps) ?? excludedApps
    }

    public func conflict(for shortcut: Shortcut, excluding action: String) -> String? {
        shortcuts.first { $0.key != action && $0.value == shortcut }?.key
    }
}
