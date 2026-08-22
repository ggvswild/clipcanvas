import Foundation
import XCTest
@testable import ClipCanvasApp
import ClipCanvasCore

@MainActor
final class ClipboardReorderViewModelTests: XCTestCase {
    func testReorderingHistoryItemsUpdatesVisibleOrderAndKeepsSelection() throws {
        let context = try makeContext()
        defer { try? FileManager.default.removeItem(at: context.root) }
        let first = try context.repository.upsert(textDraft("first"))
        let second = try context.repository.upsert(textDraft("second"))
        let third = try context.repository.upsert(textDraft("third"))
        context.model.reload()
        context.model.selectedItemID = second.id

        let accepted = context.model.reorderDroppedItem(
            id: first.id,
            onto: third.id,
            insertAfter: false
        )

        XCTAssertTrue(accepted)
        XCTAssertNil(context.model.selectedPinboardID)
        XCTAssertEqual(context.model.selectedItemID, second.id)
        XCTAssertEqual(
            context.model.items.map(\.id),
            [first.id, third.id, second.id]
        )
    }

    func testReorderingPinboardItemsDoesNotChangeCurrentTab() throws {
        let context = try makeContext()
        defer { try? FileManager.default.removeItem(at: context.root) }
        let board = try context.repository.createPinboard(name: "Research")
        let first = try context.repository.upsert(textDraft("first"))
        let second = try context.repository.upsert(textDraft("second"))
        try context.repository.pin(itemID: first.id, to: board.id)
        try context.repository.pin(itemID: second.id, to: board.id)
        context.model.reload()
        context.model.selectPinboard(board.id)

        let accepted = context.model.reorderDroppedItem(
            id: first.id,
            onto: second.id,
            insertAfter: false
        )

        XCTAssertTrue(accepted)
        XCTAssertEqual(context.model.selectedPinboardID, board.id)
        XCTAssertEqual(
            context.model.items.map(\.id),
            [first.id, second.id]
        )
    }

    func testSearchResultsRejectReorder() throws {
        let context = try makeContext()
        defer { try? FileManager.default.removeItem(at: context.root) }
        let first = try context.repository.upsert(textDraft("alpha unique"))
        let second = try context.repository.upsert(textDraft("beta unique"))
        context.model.reload()
        context.model.query = "unique"
        context.model.reload()

        XCTAssertFalse(context.model.canReorderItems)
        XCTAssertFalse(
            context.model.reorderDroppedItem(
                id: first.id,
                onto: second.id,
                insertAfter: true
            )
        )
        XCTAssertEqual(
            try context.repository.list().items.map(\.id),
            [second.id, first.id]
        )
    }

    private func makeContext() throws -> (root: URL, repository: ClipboardRepository, model: AppModel) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = ClipboardRepository(
            database: try SQLiteDatabase(url: root.appendingPathComponent("history.sqlite3")),
            blobStore: try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        )
        let model = AppModel()
        model.configure(
            repository: repository,
            pasteService: PasteService(
                pasteboard: NSPasteboard(name: .init("dev.clipcanvas.tests.\(UUID().uuidString)")),
                repository: repository
            ),
            targetApplication: { nil },
            hidePanel: {}
        )
        return (root, repository, model)
    }

    private func textDraft(_ text: String) -> ClipboardDraft {
        ClipboardDraft(
            kind: .text,
            plainText: text,
            source: .init(bundleID: "com.apple.TextEdit", name: "TextEdit"),
            representations: [
                .init(
                    uti: "public.utf8-plain-text",
                    data: Data(text.utf8)
                )
            ]
        )
    }
}
