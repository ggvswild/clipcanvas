import XCTest
@testable import ClipCanvasApp

@MainActor
final class AppModelTests: XCTestCase {
    func testPanelStartsHiddenAndToggles() {
        let model = AppModel()

        XCTAssertFalse(model.isPanelPresented)
        model.togglePanel()
        XCTAssertTrue(model.isPanelPresented)
    }
}
