import XCTest
@testable import ClipCanvasApp

final class PinboardStripEdgeFadeAppearanceTests: XCTestCase {
    func testSoftFadeKeepsBothClippedEdgesSymmetrical() {
        let appearance = PinboardStripEdgeFadeAppearance.soft

        XCTAssertEqual(appearance.edgeOpacity, 0)
        XCTAssertEqual(appearance.contentOpacity, 1)
        XCTAssertGreaterThan(appearance.fadeFraction, 0)
        XCTAssertLessThanOrEqual(appearance.fadeFraction, 0.08)
        XCTAssertEqual(
            appearance.leadingContentLocation,
            1 - appearance.trailingContentLocation,
            accuracy: 0.0001
        )
    }
}
