import Foundation
import XCTest
@testable import ClipCanvasApp
import ClipCanvasCore

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testPrivacyDefaultsAreConservative() {
        let store = SettingsStore(defaults: isolatedDefaults())

        XCTAssertTrue(store.ignoreConfidential)
        XCTAssertTrue(store.ignoreTransient)
        XCTAssertFalse(store.generateLinkPreviews)
        XCTAssertFalse(store.showDuringScreenSharing)
        XCTAssertFalse(store.enableMCP)
        XCTAssertTrue(store.ignoredApplications.contains(where: { $0.bundleID == "com.apple.Passwords" }))
    }

    func testSettingsPersistAcrossInstances() {
        let defaults = isolatedDefaults()
        let first = SettingsStore(defaults: defaults)
        first.soundEffects = false
        first.pasteStrategy = .clipboardOnly
        first.alwaysPastePlainText = true
        first.retentionPeriod = .week
        first.generateLinkPreviews = true

        let second = SettingsStore(defaults: defaults)

        XCTAssertFalse(second.soundEffects)
        XCTAssertEqual(second.pasteStrategy, .clipboardOnly)
        XCTAssertTrue(second.alwaysPastePlainText)
        XCTAssertEqual(second.retentionPeriod, .week)
        XCTAssertTrue(second.generateLinkPreviews)
    }

    func testSelectedPetDefaultsToPipAndPersists() {
        let defaults = isolatedDefaults()
        let first = SettingsStore(defaults: defaults)

        XCTAssertEqual(first.selectedPet, .pip)

        first.selectedPet = .nova

        XCTAssertEqual(SettingsStore(defaults: defaults).selectedPet, .nova)
    }

    func testUnknownStoredPetFallsBackToPip() {
        let defaults = isolatedDefaults()
        defaults.set("missing-pet", forKey: "selectedPet")

        XCTAssertEqual(
            SettingsStore(defaults: defaults).selectedPet,
            SettingsPetKind.defaultPet
        )
    }

    func testResetShortcutsRestoresDefaults() {
        let store = SettingsStore(defaults: isolatedDefaults())
        store.shortcuts[.activate] = KeyboardShortcut(
            keyCode: 0,
            modifiers: [.control, .option]
        )

        store.resetShortcuts()

        XCTAssertEqual(store.shortcuts, ShortcutAction.defaultShortcuts)
    }

    func testClearedShortcutPersistsAsUnbound() {
        let defaults = isolatedDefaults()
        let first = SettingsStore(defaults: defaults)

        first.clearShortcut(.activate)

        XCTAssertNil(first.shortcuts[.activate])
        XCTAssertNil(SettingsStore(defaults: defaults).shortcuts[.activate])
    }

    func testLegacyStackShortcutIsRemovedWithoutResettingOtherShortcuts() {
        let defaults = isolatedDefaults()
        let legacyData = Data(
            """
            [
              "activate", {"keyCode": 0, "modifiers": 256},
              "activateStack", {"keyCode": 8, "modifiers": 768},
              "nextPinboard", {"keyCode": 124, "modifiers": 256}
            ]
            """.utf8
        )
        defaults.set(legacyData, forKey: "shortcuts")

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(
            store.shortcuts[.activate],
            KeyboardShortcut(keyCode: 0, modifiers: [.command])
        )
        XCTAssertEqual(
            store.shortcuts[.nextPinboard],
            KeyboardShortcut(keyCode: 124, modifiers: [.command])
        )
        XCTAssertEqual(store.shortcuts.count, 2)
        XCTAssertFalse(
            String(
                data: defaults.data(forKey: "shortcuts")!,
                encoding: .utf8
            )!.contains("activateStack")
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "dev.clipcanvas.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
