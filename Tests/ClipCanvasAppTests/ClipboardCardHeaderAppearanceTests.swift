import XCTest
@testable import ClipCanvasApp

final class ClipboardCardHeaderAppearanceTests: XCTestCase {
    func testContentFirstHeaderUsesFlatLowContrastTreatment() {
        let appearance = ClipboardCardHeaderAppearance.contentFirst

        XCTAssertEqual(appearance.backgroundTreatment, .flat)
        XCTAssertLessThanOrEqual(appearance.backgroundOpacity, 0.05)
        XCTAssertLessThanOrEqual(appearance.typeAccentOpacity, 0.8)
        XCTAssertLessThanOrEqual(appearance.sourceIconOpacity, 0.75)
        XCTAssertLessThanOrEqual(appearance.dividerOpacity, 0.06)
    }
}
