import SwiftUI
import XCTest
@testable import ClipCanvasApp

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testShowCreatesVisibleSettingsWindow() {
        let controller = SettingsWindowController(
            rootView: AnyView(Text("Settings"))
        )

        controller.show()

        XCTAssertTrue(controller.isVisible)
        controller.close()
    }
}
