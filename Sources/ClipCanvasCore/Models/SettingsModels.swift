import Foundation

public struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let command = ShortcutModifiers(rawValue: 1 << 8)
    public static let shift = ShortcutModifiers(rawValue: 1 << 9)
    public static let option = ShortcutModifiers(rawValue: 1 << 11)
    public static let control = ShortcutModifiers(rawValue: 1 << 12)
}

public struct KeyboardShortcut: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: ShortcutModifiers

    public init(keyCode: UInt32, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var displayText: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        text += Self.keyName(keyCode)
        return text
    }

    private static func keyName(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 0: "A"
        case 1: "S"
        case 2: "D"
        case 3: "F"
        case 4: "H"
        case 5: "G"
        case 6: "Z"
        case 7: "X"
        case 8: "C"
        case 9: "V"
        case 11: "B"
        case 12: "Q"
        case 13: "W"
        case 14: "E"
        case 15: "R"
        case 16: "Y"
        case 17: "T"
        case 18...26: String(Int(keyCode) - 17)
        case 45: "N"
        case 46: "M"
        case 123: "←"
        case 124: "→"
        default: "#\(keyCode)"
        }
    }
}

public enum ShortcutAction: String, Codable, CaseIterable, Sendable {
    case activate
    case activateStack
    case previousPinboard
    case nextPinboard

    public static let defaultShortcuts: [ShortcutAction: KeyboardShortcut] = [
        .activate: KeyboardShortcut(
            keyCode: 9,
            modifiers: [.command, .shift]
        ),
        .activateStack: KeyboardShortcut(
            keyCode: 8,
            modifiers: [.command, .shift]
        ),
        .previousPinboard: KeyboardShortcut(
            keyCode: 123,
            modifiers: [.command]
        ),
        .nextPinboard: KeyboardShortcut(
            keyCode: 124,
            modifiers: [.command]
        )
    ]
}

public struct IgnoredApplication: Identifiable, Codable, Hashable, Sendable {
    public var id: String { bundleID }
    public let bundleID: String
    public var name: String
    public var path: String?

    public init(bundleID: String, name: String, path: String? = nil) {
        self.bundleID = bundleID
        self.name = name
        self.path = path
    }
}
