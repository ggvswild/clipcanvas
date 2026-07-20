import XCTest
@testable import ClipCanvasApp
import ClipCanvasCore

final class ShortcutValidationTests: XCTestCase {
    func testSupportedShortcutActionsDoNotIncludeStack() {
        XCTAssertEqual(
            ShortcutAction.allCases.map(\.rawValue),
            ["activate", "previousPinboard", "nextPinboard"]
        )
        XCTAssertEqual(
            Set(ShortcutAction.defaultShortcuts.keys),
            Set(ShortcutAction.allCases)
        )
    }

    func testGlobalShortcutRequiresModifier() {
        let result = ShortcutValidator.validate(
            action: .activate,
            shortcut: .init(keyCode: 9, modifiers: []),
            existing: [:]
        )

        XCTAssertEqual(result, .missingModifier)
    }

    func testDuplicateShortcutIsRejected() {
        let shortcut = KeyboardShortcut(keyCode: 9, modifiers: [.command, .shift])

        let result = ShortcutValidator.validate(
            action: .nextPinboard,
            shortcut: shortcut,
            existing: [.activate: shortcut]
        )

        XCTAssertEqual(result, .conflictsWith(.activate))
    }

    func testDefaultShortcutsAreValidAndDistinct() {
        let defaults = ShortcutAction.defaultShortcuts

        XCTAssertEqual(Set(defaults.values).count, defaults.count)
        for (action, shortcut) in defaults {
            XCTAssertEqual(
                ShortcutValidator.validate(
                    action: action,
                    shortcut: shortcut,
                    existing: defaults.filter { $0.key != action }
                ),
                .valid
            )
        }
    }
}
