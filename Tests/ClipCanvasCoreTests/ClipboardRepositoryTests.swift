import Foundation
import XCTest
@testable import ClipCanvasCore

final class ClipboardRepositoryTests: XCTestCase {
    private var root: URL!
    private var repository: ClipboardRepository!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let database = try SQLiteDatabase(url: root.appendingPathComponent("history.sqlite3"))
        let blobs = try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        repository = ClipboardRepository(database: database, blobStore: blobs)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testRepeatedContentReusesItemAndIncrementsCopyCount() throws {
        let first = try repository.upsert(textDraft("same", at: Date(timeIntervalSince1970: 100)))
        let second = try repository.upsert(textDraft("same", at: Date(timeIntervalSince1970: 200)))

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.copyCount, 2)
        XCTAssertEqual(second.lastCopiedAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(try repository.list(.init(limit: 50)).items.count, 1)
    }

    func testSearchMatchesTextTitleAndSource() throws {
        _ = try repository.upsert(
            textDraft(
                "local-first clipboard",
                title: "Architecture note",
                sourceName: "Notes"
            )
        )
        _ = try repository.upsert(
            textDraft(
                "unrelated",
                title: "Other",
                sourceName: "Safari"
            )
        )

        XCTAssertEqual(try repository.search("clipboard", limit: 10).items.count, 1)
        XCTAssertEqual(try repository.search("Architecture", limit: 10).items.count, 1)
        XCTAssertEqual(try repository.search("Notes", limit: 10).items.count, 1)
    }

    func testPinboardCRUDAndPinning() throws {
        let item = try repository.upsert(textDraft("keep me"))
        let board = try repository.createPinboard(name: "Research", color: "purple", symbol: "book")

        try repository.pin(itemID: item.id, to: board.id)
        let pinned = try repository.items(in: board.id, limit: 50)

        XCTAssertEqual(pinned.items.map(\.id), [item.id])
        XCTAssertTrue(try repository.listPinboards().contains(where: { $0.id == Pinboard.usefulLinksID }))
        XCTAssertTrue(try repository.listPinboards().contains(where: { $0.id == board.id }))

        try repository.unpin(itemID: item.id, from: board.id)
        XCTAssertTrue(try repository.items(in: board.id, limit: 50).items.isEmpty)
        try repository.deletePinboard(id: board.id)
        XCTAssertFalse(try repository.listPinboards().contains(where: { $0.id == board.id }))
    }

    func testNewlyPinnedItemAppearsFirstWithoutReorderingOlderItems() throws {
        let first = try repository.upsert(textDraft("first"))
        let second = try repository.upsert(textDraft("second"))
        let newest = try repository.upsert(textDraft("newest"))
        let board = try repository.createPinboard(name: "Research")
        try repository.pin(itemID: first.id, to: board.id)
        try repository.pin(itemID: second.id, to: board.id)

        try repository.pin(itemID: newest.id, to: board.id)

        XCTAssertEqual(
            try repository.items(in: board.id).items.map(\.id),
            [newest.id, second.id, first.id]
        )
    }

    func testDeleteSystemPinboardIsRejected() throws {
        XCTAssertThrowsError(try repository.deletePinboard(id: Pinboard.usefulLinksID)) { error in
            XCTAssertEqual(error as? ClipboardRepositoryError, .systemPinboardCannotBeDeleted)
        }
    }

    func testUpdateAndReorderOrdinaryPinboards() throws {
        let first = try repository.createPinboard(
            name: "First",
            color: "cyan",
            symbol: "pin.fill"
        )
        let second = try repository.createPinboard(
            name: "Second",
            color: "blue",
            symbol: "link"
        )

        try repository.updatePinboard(
            id: first.id,
            name: " Renamed ",
            color: "purple",
            symbol: "star.fill"
        )
        try repository.reorderPinboards(ids: [second.id, first.id])

        let boards = try repository.listPinboards()
        XCTAssertEqual(
            boards.filter { !$0.isSystem }.map(\.id),
            [second.id, first.id]
        )
        let updated = try XCTUnwrap(boards.first(where: { $0.id == first.id }))
        XCTAssertEqual(updated.name, "Renamed")
        XCTAssertEqual(updated.color, "purple")
        XCTAssertEqual(updated.symbol, "star.fill")
        XCTAssertEqual(boards.first?.id, Pinboard.usefulLinksID)
    }

    func testSystemPinboardCannotBeModified() throws {
        XCTAssertThrowsError(
            try repository.updatePinboard(
                id: Pinboard.usefulLinksID,
                name: "Changed",
                color: "pink",
                symbol: "heart.fill"
            )
        ) { error in
            XCTAssertEqual(
                error as? ClipboardRepositoryError,
                .systemPinboardCannotBeModified
            )
        }
    }

    func testDeletePinboardPreservesClipboardItem() throws {
        let item = try repository.upsert(textDraft("still in history"))
        let board = try repository.createPinboard(name: "Temporary")
        try repository.pin(itemID: item.id, to: board.id)

        try repository.deletePinboard(id: board.id)

        XCTAssertEqual(try repository.item(id: item.id).id, item.id)
    }

    func testUnpinDoesNotAffectOtherPinboards() throws {
        let item = try repository.upsert(textDraft("shared"))
        let first = try repository.createPinboard(name: "First")
        let second = try repository.createPinboard(name: "Second")
        try repository.pin(itemID: item.id, to: first.id)
        try repository.pin(itemID: item.id, to: second.id)

        try repository.unpin(itemID: item.id, from: first.id)

        XCTAssertTrue(try repository.items(in: first.id).items.isEmpty)
        XCTAssertEqual(
            try repository.items(in: second.id).items.map(\.id),
            [item.id]
        )
    }

    func testDeleteItemsOlderThanCutoffPreservesPinnedItems() throws {
        let oldPinned = try repository.upsert(
            textDraft("old pinned", at: Date(timeIntervalSince1970: 100))
        )
        _ = try repository.upsert(
            textDraft("old disposable", at: Date(timeIntervalSince1970: 110))
        )
        let recent = try repository.upsert(
            textDraft("recent", at: Date(timeIntervalSince1970: 300))
        )
        try repository.pin(itemID: oldPinned.id, to: Pinboard.usefulLinksID)

        try repository.deleteItems(
            olderThan: Date(timeIntervalSince1970: 200),
            preservingPinned: true
        )

        let remaining = try repository.list().items
        XCTAssertEqual(Set(remaining.map(\.id)), [oldPinned.id, recent.id])
    }

    func testUpdateTitleRefreshesSearchIndex() throws {
        let item = try repository.upsert(textDraft("https://example.com"))

        try repository.updateTitle(id: item.id, title: "Private Example")

        XCTAssertEqual(try repository.item(id: item.id).title, "Private Example")
        XCTAssertEqual(try repository.search("Private", limit: 10).items.map(\.id), [item.id])
    }

    private func textDraft(
        _ text: String,
        title: String? = nil,
        sourceName: String = "TextEdit",
        at date: Date = Date()
    ) -> ClipboardDraft {
        ClipboardDraft(
            kind: .text,
            plainText: text,
            title: title,
            source: .init(bundleID: "com.apple.TextEdit", name: sourceName),
            capturedAt: date,
            representations: [
                .init(uti: "public.utf8-plain-text", data: Data(text.utf8))
            ]
        )
    }
}
