import Foundation

public struct KeyMapping: Codable, Equatable, Sendable {
    public var source: UInt64
    public var destination: UInt64
    public init(source: UInt64, destination: UInt64) {
        self.source = source
        self.destination = destination
    }
    public static let capsLock: UInt64 = 0x700000039
    public static let f18: UInt64 = 0x70000006D
    public static let hyper = Self(source: capsLock, destination: f18)
    public enum CodingKeys: String, CodingKey {
        case source = "HIDKeyboardModifierMappingSrc"
        case destination = "HIDKeyboardModifierMappingDst"
    }

    public static func enablingHyper(in mappings: [Self]) -> [Self] {
        mappings.filter { $0.source != capsLock } + [.hyper]
    }

    public static func restoringHyper(in current: [Self], previousCaps: [Self]) -> [Self] {
        guard current.filter({ $0.source == capsLock }) == [.hyper] else { return current }
        return current.filter { $0.source != capsLock } + previousCaps
    }
}
