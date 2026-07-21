import XCTest
@testable import ClipCanvasApp

final class SettingsPetBehaviorTests: XCTestCase {
    func testPausedCaptureLetsPipRest() {
        XCTAssertEqual(
            SettingsPetBehavior.status(itemCount: 12, isCapturePaused: true),
            .resting
        )
        XCTAssertEqual(
            SettingsPetBehavior.mood(itemCount: 12, isCapturePaused: true),
            .sleepy
        )
    }

    func testEmptyHistoryMakesPipCurious() {
        XCTAssertEqual(
            SettingsPetBehavior.status(itemCount: 0, isCapturePaused: false),
            .waiting
        )
        XCTAssertEqual(
            SettingsPetBehavior.mood(itemCount: 0, isCapturePaused: false),
            .curious
        )
    }

    func testActiveHistoryMakesPipGuardRecentClips() {
        XCTAssertEqual(
            SettingsPetBehavior.status(itemCount: 18, isCapturePaused: false),
            .guarding(itemCount: 18)
        )
        XCTAssertEqual(
            SettingsPetBehavior.mood(itemCount: 18, isCapturePaused: false),
            .content
        )
    }

    func testTapReactionsRotateToStayFresh() {
        XCTAssertEqual(
            (1...8).map(SettingsPetBehavior.reaction(forTapCount:)),
            [
                .nuzzle, .sparkle, .peek, .proud,
                .nuzzle, .sparkle, .peek, .proud
            ]
        )
    }
}
