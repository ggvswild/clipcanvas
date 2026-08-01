import AppKit
import Foundation
import XCTest
@testable import ClipCanvasApp

@MainActor
final class PanelKeyboardRoutingTests: XCTestCase {
    func testCommandEightIsRoutedToQuickPaste() throws {
        let suite = "dev.clipcanvas.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let controller = PanelController(
            model: AppModel(),
            settings: SettingsStore(defaults: defaults)
        )
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "8",
                charactersIgnoringModifiers: "8",
                isARepeat: false,
                keyCode: 28
            )
        )

        XCTAssertTrue(controller.handleKeyDown(event))
    }

    func testCommandEqualsIsNotConsumedAsQuickPaste() throws {
        let suite = "dev.clipcanvas.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let controller = PanelController(
            model: AppModel(),
            settings: SettingsStore(defaults: defaults)
        )
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "=",
                charactersIgnoringModifiers: "=",
                isARepeat: false,
                keyCode: 24
            )
        )

        XCTAssertFalse(controller.handleKeyDown(event))
    }

    func testCommandFRequestsSearchFocus() throws {
        let suite = "dev.clipcanvas.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let model = AppModel()
        let controller = PanelController(
            model: model,
            settings: SettingsStore(defaults: defaults)
        )
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "f",
                charactersIgnoringModifiers: "f",
                isARepeat: false,
                keyCode: 3
            )
        )

        XCTAssertTrue(controller.handleKeyDown(event))
        XCTAssertEqual(model.searchFocusRequestID, 1)
    }

    func testSecondCommandFExitsSearchAndClearsQuery() throws {
        let suite = "dev.clipcanvas.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let model = AppModel()
        let controller = PanelController(
            model: model,
            settings: SettingsStore(defaults: defaults)
        )
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "f",
                charactersIgnoringModifiers: "f",
                isARepeat: false,
                keyCode: 3
            )
        )

        XCTAssertTrue(controller.handleKeyDown(event))
        XCTAssertTrue(model.isSearchFocused)
        model.query = "needle"

        XCTAssertTrue(controller.handleKeyDown(event))
        XCTAssertFalse(model.isSearchFocused)
        XCTAssertEqual(model.query, "")
    }

    func testPanelKeyboardRoutingYieldsWhileSheetIsPresented() {
        XCTAssertFalse(
            PanelController.shouldRoutePanelKeyboardEvent(isPresentingSheet: true)
        )
    }

    func testPanelKeyboardRoutingHandlesEventsWithoutSheet() {
        XCTAssertTrue(
            PanelController.shouldRoutePanelKeyboardEvent(isPresentingSheet: false)
        )
    }

    func testSpaceIsLeftToEditableTextResponder() throws {
        let suite = "dev.clipcanvas.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let model = AppModel()
        let controller = PanelController(
            model: model,
            settings: SettingsStore(defaults: defaults)
        )
        let panel = try XCTUnwrap(
            Mirror(reflecting: controller).children
                .first(where: { $0.label == "panel" })?
                .value as? NSPanel
        )
        let textEditor = NSTextView()
        textEditor.isEditable = true
        panel.contentView?.addSubview(textEditor)
        XCTAssertTrue(panel.makeFirstResponder(textEditor))
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: panel.windowNumber,
                context: nil,
                characters: " ",
                charactersIgnoringModifiers: " ",
                isARepeat: false,
                keyCode: 49
            )
        )

        XCTAssertFalse(controller.handleKeyDown(event))
        XCTAssertFalse(model.isPreviewPresented)
    }

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
