import ClipCanvasCore

enum ShortcutValidationResult: Equatable {
    case valid
    case missingModifier
    case conflictsWith(ShortcutAction)
}

enum ShortcutValidator {
    static func validate(
        action: ShortcutAction,
        shortcut: KeyboardShortcut,
        existing: [ShortcutAction: KeyboardShortcut]
    ) -> ShortcutValidationResult {
        guard !shortcut.modifiers.isEmpty else {
            return .missingModifier
        }
        if let conflict = existing.first(where: {
            $0.key != action && $0.value == shortcut
        })?.key {
            return .conflictsWith(conflict)
        }
        return .valid
    }
}
