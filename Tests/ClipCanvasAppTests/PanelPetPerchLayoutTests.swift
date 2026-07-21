import XCTest
@testable import ClipCanvasApp

@MainActor
final class PanelPetPerchLayoutTests: XCTestCase {
    func testPetWindowSitsOutsideTheMainPanelTopEdge() {
        let layout = PanelPetPerchLayout.standard
        let panelFrame = CGRect(x: 12, y: 10, width: 1400, height: 285)
        let petFrame = layout.petWindowFrame(above: panelFrame)

        XCTAssertEqual(petFrame.minY, panelFrame.maxY)
        XCTAssertFalse(petFrame.intersects(panelFrame))
        XCTAssertLessThanOrEqual(petFrame.maxX, panelFrame.maxX)
        XCTAssertGreaterThan(petFrame.minX, panelFrame.midX)
    }

    func testPetWindowMatchesTheCompactArtworkCanvas() {
        let layout = PanelPetPerchLayout.standard

        XCTAssertEqual(
            layout.petWindowFrame(above: .zero).size,
            CGSize(width: layout.windowWidth, height: layout.windowHeight)
        )
    }
}
