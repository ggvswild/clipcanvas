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

    func testDeleteSystemPinboardIsRejected() throws {
        XCTAssertThrowsError(try repository.deletePinboard(id: Pinboard.usefulLinksID)) { error in
            XCTAssertEqual(error as? ClipboardRepositoryError, .systemPinboardCannotBeDeleted)
        }
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
