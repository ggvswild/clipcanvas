import XCTest
@testable import ClipCanvasApp

final class SettingsLayoutMetricsTests: XCTestCase {
    func testSettingsRowsShareAStableTwoColumnGrid() {
        let metrics = SettingsLayoutMetrics.standard
        let leadingColumnWidth = metrics.contentWidth
            - (metrics.cardHorizontalPadding * 2)
            - metrics.columnSpacing
            - metrics.trailingColumnWidth

        XCTAssertEqual(metrics.spacingUnit, 4)
        XCTAssertEqual(metrics.windowWidth, 900)
        XCTAssertEqual(metrics.windowHeight, 650)
        XCTAssertEqual(metrics.rowVerticalPadding, 12)
        XCTAssertEqual(metrics.columnSpacing, 16)
        XCTAssertEqual(metrics.trailingColumnWidth, 192)
        XCTAssertGreaterThanOrEqual(leadingColumnWidth, 360)
    }
}
