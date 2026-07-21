import XCTest
@testable import ClipCanvasApp

@MainActor
final class SettingsNavigationTests: XCTestCase {
    func testPinboardsSectionFollowsGeneral() {
        XCTAssertEqual(
            SettingsRootView.Section.allCases.map(\.rawValue),
            [
                "general", "pinboards", "pets", "privacy",
                "shortcuts", "mcp", "about"
            ]
        )
        XCTAssertEqual(
            SettingsRootView.Section.pinboards.symbol,
            "square.grid.2x2"
        )
        XCTAssertEqual(SettingsRootView.Section.pets.symbol, "pawprint")
    }

    func testNavigationCoordinatorSelectsRequestedSection() {
        let navigation = SettingsNavigationCoordinator()

        XCTAssertEqual(navigation.selection, .general)

        navigation.select(.pets)

        XCTAssertEqual(navigation.selection, .pets)
    }
}
