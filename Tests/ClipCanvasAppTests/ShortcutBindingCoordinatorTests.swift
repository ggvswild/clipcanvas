import Foundation
import XCTest
@testable import ClipCanvasApp
import ClipCanvasCore

@MainActor
final class ShortcutBindingCoordinatorTests: XCTestCase {
    func testClearingShortcutAppliesSnapshotWithoutRemovedBinding() {
        let suite = "dev.clipcanvas.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = SettingsStore(defaults: defaults)
        var appliedShortcuts = settings.shortcuts
        let coordinator = ShortcutBindingCoordinator(settings: settings) {
            appliedShortcuts = $0
        }

        settings.clearShortcut(.nextPinboard)

        XCTAssertNil(appliedShortcuts[.nextPinboard])
        withExtendedLifetime(coordinator) {}
    }
}
