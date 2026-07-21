import XCTest
@testable import ClipCanvasApp

@MainActor
final class PanelWindowFocusTests: XCTestCase {
    func testInternalFocusRecoveryDoesNotHidePanel() {
        XCTAssertFalse(
            PanelController.shouldHideAfterFocusChange(
                isPanelVisible: true,
                isPresentingSheet: false,
                panelIsKey: true
            )
        )
    }

    func testExternalFocusChangeStillHidesPanel() {
        XCTAssertTrue(
            PanelController.shouldHideAfterFocusChange(
                isPanelVisible: true,
                isPresentingSheet: false,
                panelIsKey: false
            )
        )
    }

    func testSheetPresentationKeepsPanelVisible() {
        XCTAssertFalse(
            PanelController.shouldHideAfterFocusChange(
                isPanelVisible: true,
                isPresentingSheet: true,
                panelIsKey: false
            )
        )
    }
}
