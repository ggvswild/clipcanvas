import Foundation
import XCTest
@testable import ClipCanvasApp
import ClipCanvasCore

final class ClipboardItemReorderTests: XCTestCase {
    func testMovingEarlierItemBeforeLaterTargetInsertsInFrontOfIt() {
        let items = sampleItems("A", "B", "C")

        XCTAssertEqual(
            ClipboardItemReorder.ids(
                in: items,
                moving: items[0].id,
                onto: items[2].id,
                insertAfter: false
            ),
            [items[1].id, items[0].id, items[2].id]
        )
    }

    func testMovingEarlierItemAfterLaterTargetPlacesItAtTheEnd() {
        let items = sampleItems("A", "B", "C")

        XCTAssertEqual(
            ClipboardItemReorder.ids(
                in: items,
                moving: items[0].id,
                onto: items[2].id,
                insertAfter: true
            ),
            [items[1].id, items[2].id, items[0].id]
        )
    }

    func testMovingLaterItemBeforeEarlierTargetPlacesItFirst() {
        let items = sampleItems("A", "B", "C")

        XCTAssertEqual(
            ClipboardItemReorder.ids(
                in: items,
                moving: items[2].id,
                onto: items[0].id,
                insertAfter: false
            ),
            [items[2].id, items[0].id, items[1].id]
        )
    }

    func testMovingLaterItemAfterEarlierTargetInsertsBehindIt() {
        let items = sampleItems("A", "B", "C")

        XCTAssertEqual(
            ClipboardItemReorder.ids(
                in: items,
                moving: items[2].id,
                onto: items[0].id,
                insertAfter: true
            ),
            [items[0].id, items[2].id, items[1].id]
        )
    }

    func testDroppingAnItemOntoItselfKeepsTheCurrentOrder() {
        let items = sampleItems("A", "B", "C")

        XCTAssertEqual(
            ClipboardItemReorder.ids(
                in: items,
                moving: items[1].id,
                onto: items[1].id,
                insertAfter: true
            ),
            items.map(\.id)
        )
    }

    func testUnknownIdentifiersProduceNoOrder() {
        let items = sampleItems("A", "B")

        XCTAssertNil(
            ClipboardItemReorder.ids(
                in: items,
                moving: UUID(),
                onto: items[0].id,
                insertAfter: false
            )
        )
    }

    private func sampleItems(_ texts: String...) -> [ClipboardItem] {
        texts.enumerated().map { offset, text in
            ClipboardItem(
                id: UUID(),
                kind: .text,
                plainText: text,
                title: nil,
                source: .init(bundleID: "com.apple.TextEdit", name: "TextEdit"),
                contentHash: UUID().uuidString,
                createdAt: Date(timeIntervalSince1970: TimeInterval(offset)),
                lastCopiedAt: Date(timeIntervalSince1970: TimeInterval(offset)),
                copyCount: 1,
                isSensitive: false,
                metadata: .init(byteCount: text.utf8.count),
                representations: []
            )
        }
    }
}
