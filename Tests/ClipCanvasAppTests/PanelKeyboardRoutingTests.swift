import AppKit
import XCTest
@testable import ClipCanvasApp

@MainActor
final class PanelKeyboardRoutingTests: XCTestCase {
    func testDeleteShortcutIsLeftToEditableTextResponder() {
        let textEditor = NSTextView()
        textEditor.isEditable = true

        XCTAssertFalse(
            PanelController.shouldHandleDeleteShortcut(firstResponder: textEditor)
        )
    }

    func testDeleteShortcutIsLeftToEditableTextField() {
        let textField = NSTextField()
        textField.isEditable = true

        XCTAssertFalse(
            PanelController.shouldHandleDeleteShortcut(firstResponder: textField)
        )
    }

    func testDeleteShortcutIsHandledWhenTextInputIsNotFocused() {
        XCTAssertTrue(
            PanelController.shouldHandleDeleteShortcut(firstResponder: nil)
        )
    }
}
