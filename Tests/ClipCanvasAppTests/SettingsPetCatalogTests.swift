import XCTest
@testable import ClipCanvasApp

final class SettingsPetCatalogTests: XCTestCase {
    func testCatalogShipsSixStableOriginalPets() {
        XCTAssertEqual(
            SettingsPetKind.allCases.map(\.rawValue),
            ["pip", "sprig", "nova", "mallow", "byte", "ember"]
        )
        XCTAssertEqual(SettingsPetKind.defaultPet, .pip)
        XCTAssertEqual(Set(SettingsPetKind.allCases.map(\.id)).count, 6)
    }

    func testCatalogIncludesForestTimeAndWishStarMotifs() {
        XCTAssertEqual(SettingsPetKind.sprig.motif, .forestTime)
        XCTAssertEqual(SettingsPetKind.nova.motif, .wishStar)
    }
}
