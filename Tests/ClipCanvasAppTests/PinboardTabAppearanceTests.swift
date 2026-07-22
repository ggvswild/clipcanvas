import XCTest
@testable import ClipCanvasApp

final class PinboardTabAppearanceTests: XCTestCase {
    func testReadableTabsKeepGroupColorVisibleAndAddSelectionEmphasis() {
        let appearance = PinboardTabAppearance.readable

        XCTAssertGreaterThanOrEqual(appearance.defaultBackgroundOpacity, 0.24)
        XCTAssertGreaterThan(
            appearance.selectedBackgroundOpacity,
            appearance.defaultBackgroundOpacity
        )
        XCTAssertGreaterThan(
            appearance.selectedBorderWidth,
            appearance.defaultBorderWidth
        )
        XCTAssertGreaterThan(appearance.selectedScale, appearance.defaultScale)
        XCTAssertLessThanOrEqual(appearance.selectedScale, 1.03)
    }

    func testPaletteMatchesEveryColorOfferedByThePinboardEditor() {
        XCTAssertEqual(
            PinboardColorPalette.supportedNames,
            ["cyan", "blue", "purple", "pink", "orange", "green"]
        )
    }

    func testDropTargetIsMoreProminentThanSelectedTab() {
        let appearance = PinboardTabAppearance.readable

        XCTAssertGreaterThan(
            appearance.dropTargetBorderWidth,
            appearance.selectedBorderWidth
        )
        XCTAssertGreaterThan(
            appearance.dropTargetScale,
            appearance.selectedScale
        )
        XCTAssertGreaterThan(appearance.dropTargetShadowOpacity, 0)
    }
}
