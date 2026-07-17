import Foundation
import XCTest
@testable import ClipCanvasApp
import ClipCanvasCore

@MainActor
final class AppModelNavigationTests: XCTestCase {
    func testMoveSelectionClampsToVisibleItems() {
        let model = AppModel()
        let items = [
            sampleItem(text: "A", date: Date(timeIntervalSince1970: 3)),
            sampleItem(text: "B", date: Date(timeIntervalSince1970: 2)),
            sampleItem(text: "C", date: Date(timeIntervalSince1970: 1))
        ]
        model.replaceItems(items)

        model.moveSelection(by: -1)
        XCTAssertEqual(model.selectedItemID, items[0].id)

        model.moveSelection(by: 10)
        XCTAssertEqual(model.selectedItemID, items[2].id)

        model.moveSelection(by: -10)
        XCTAssertEqual(model.selectedItemID, items[0].id)
    }

    func testReplacingItemsPreservesSelectionWhenStillVisible() {
        let first = sampleItem(text: "First")
        let second = sampleItem(text: "Second")
        let model = AppModel()
        model.replaceItems([first, second])
        model.moveSelection(by: 1)

        model.replaceItems([second])

        XCTAssertEqual(model.selectedItemID, second.id)
    }

    func testQuickPasteReturnsOneBasedVisibleItem() {
        let first = sampleItem(text: "First")
        let second = sampleItem(text: "Second")
        let model = AppModel()
        model.replaceItems([first, second])

        XCTAssertEqual(model.itemForQuickPaste(index: 1)?.id, first.id)
        XCTAssertEqual(model.itemForQuickPaste(index: 2)?.id, second.id)
        XCTAssertNil(model.itemForQuickPaste(index: 0))
        XCTAssertNil(model.itemForQuickPaste(index: 9))
    }

    private func sampleItem(text: String, date: Date = Date()) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .text,
            plainText: text,
            title: nil,
            source: .init(bundleID: "com.apple.TextEdit", name: "TextEdit"),
            contentHash: UUID().uuidString,
            createdAt: date,
            lastCopiedAt: date,
            copyCount: 1,
            isSensitive: false,
            metadata: .init(byteCount: text.utf8.count),
            representations: []
        )
    }
}
