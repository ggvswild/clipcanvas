import XCTest
@testable import ClipCanvasApp

final class PinboardTabAppearanceTests: XCTestCase {
    func testIntegratedTabsUseQuietSurfacesWithoutPersistentBorders() {
        let appearance = PinboardTabAppearance.integrated

        XCTAssertLessThanOrEqual(appearance.defaultBackgroundOpacity, 0.04)
        XCTAssertGreaterThan(
            appearance.selectedBackgroundOpacity,
            appearance.defaultBackgroundOpacity
        )
        XCTAssertLessThanOrEqual(appearance.selectedBackgroundOpacity, 0.14)
        XCTAssertEqual(appearance.defaultBorderWidth, 0)
        XCTAssertEqual(appearance.selectedBorderWidth, 0)
        XCTAssertEqual(appearance.selectedScale, appearance.defaultScale)
    }

    func testSelectedTabUsesACompactColorIndicatorInsteadOfAColorFill() {
        let appearance = PinboardTabAppearance.integrated

        XCTAssertGreaterThanOrEqual(appearance.selectedIndicatorWidth, 12)
        XCTAssertLessThanOrEqual(appearance.selectedIndicatorHeight, 2)
        XCTAssertGreaterThan(
            appearance.selectedLabelOpacity,
            appearance.defaultLabelOpacity
        )
    }

    func testPaletteMatchesEveryColorOfferedByThePinboardEditor() {
        XCTAssertEqual(
            PinboardColorPalette.supportedNames,
            ["cyan", "blue", "purple", "pink", "orange", "green"]
        )
    }

    func testDropTargetIsMoreProminentThanSelectedTab() {
        let appearance = PinboardTabAppearance.integrated

        XCTAssertGreaterThan(
            appearance.dropTargetBorderWidth,
            appearance.selectedBorderWidth
        )
        XCTAssertGreaterThan(
            appearance.dropTargetScale,
            appearance.selectedScale
        )
        XCTAssertLessThanOrEqual(appearance.dropTargetScale, 1.02)
        XCTAssertGreaterThan(appearance.dropTargetShadowOpacity, 0)
    }
}
