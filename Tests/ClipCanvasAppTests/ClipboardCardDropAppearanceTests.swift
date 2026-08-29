import XCTest
@testable import ClipCanvasApp

final class ClipboardCardDropAppearanceTests: XCTestCase {
    func testDropTargetIsMoreProminentThanSelectedCard() {
        let appearance = ClipboardCardDropAppearance.insertion

        XCTAssertGreaterThan(appearance.targetedScale, 1)
        XCTAssertGreaterThan(appearance.targetedBorderWidth, 2.5)
        XCTAssertGreaterThan(appearance.targetedShadowOpacity, 0.26)
    }
}
