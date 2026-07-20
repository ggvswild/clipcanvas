import ClipCanvasCore
import Foundation
import XCTest
@testable import ClipCanvasApp

final class PinboardManagementStateTests: XCTestCase {
    func testReconcileSelectsFirstAndFallsBackAfterDeletion() {
        let first = Pinboard(name: "First", sortIndex: 1)
        let second = Pinboard(name: "Second", sortIndex: 2)
        var state = PinboardManagementState()

        state.reconcile(pinboards: [first, second])
        XCTAssertEqual(state.selectedPinboardID, first.id)

        state.selectedPinboardID = second.id
        state.reconcile(pinboards: [first])
        XCTAssertEqual(state.selectedPinboardID, first.id)
    }

    func testReconcileClearsContentWhenNoPinboardsRemain() {
        let item = makeItem(text: "Candidate", title: nil, source: "Notes")
        var state = PinboardManagementState(
            selectedPinboardID: UUID(),
            query: "candidate",
            items: [item]
        )

        state.reconcile(pinboards: [])

        XCTAssertNil(state.selectedPinboardID)
        XCTAssertEqual(state.query, "")
        XCTAssertTrue(state.items.isEmpty)
    }

    func testSearchMatchesTitleTextAndSourceIgnoringCase() {
        var state = PinboardManagementState()
        state.items = [
            makeItem(text: "Release note", title: "Launch", source: "Notes"),
            makeItem(text: "Other", title: nil, source: "Safari")
        ]

        state.query = "launch"
        XCTAssertEqual(state.filteredItems.map(\.plainText), ["Release note"])

        state.query = "RELEASE"
        XCTAssertEqual(state.filteredItems.map(\.plainText), ["Release note"])

        state.query = "NOTES"
        XCTAssertEqual(state.filteredItems.map(\.plainText), ["Release note"])
    }

    func testBlankSearchReturnsEveryItem() {
        var state = PinboardManagementState()
        state.items = [
            makeItem(text: "First", title: nil, source: "Notes"),
            makeItem(text: "Second", title: nil, source: "Safari")
        ]
        state.query = "   "

        XCTAssertEqual(state.filteredItems, state.items)
    }

    private func makeItem(
        text: String,
        title: String?,
        source: String
    ) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .text,
            plainText: text,
            title: title,
            source: .init(bundleID: nil, name: source),
            contentHash: UUID().uuidString,
            createdAt: Date(),
            lastCopiedAt: Date(),
            copyCount: 1,
            isSensitive: false,
            metadata: .init(),
            representations: []
        )
    }
}
