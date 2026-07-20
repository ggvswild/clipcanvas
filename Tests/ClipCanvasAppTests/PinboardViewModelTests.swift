import Foundation
import XCTest
@testable import ClipCanvasApp
import ClipCanvasCore

@MainActor
final class PinboardViewModelTests: XCTestCase {
    func testClipboardTabPrecedesEveryPinboard() throws {
        let context = try makeContext()
        defer { try? FileManager.default.removeItem(at: context.root) }

        context.model.createPinboard(name: "Research", color: "purple", symbol: "book")

        let tabs = context.model.pinboardTabs
        XCTAssertNil(tabs[0])
        XCTAssertEqual(
            tabs.dropFirst().compactMap { $0?.id },
            context.model.pinboards.map(\.id)
        )
    }

    func testCreatePinboardSelectAndDeleteReturnsToClipboard() throws {
        let context = try makeContext()
        defer { try? FileManager.default.removeItem(at: context.root) }

        context.model.createPinboard(name: "Research", color: "purple", symbol: "book")
        let created = context.model.pinboards.first(where: { $0.name == "Research" })

        XCTAssertNotNil(created)
        XCTAssertEqual(context.model.selectedPinboardID, created?.id)

        context.model.deletePinboard(created!.id)

        XCTAssertNil(context.model.selectedPinboardID)
        XCTAssertFalse(context.model.pinboards.contains(where: { $0.id == created?.id }))
    }

    func testSystemUsefulLinksCannotBeDeleted() throws {
        let context = try makeContext()
        defer { try? FileManager.default.removeItem(at: context.root) }

        context.model.deletePinboard(Pinboard.usefulLinksID)

        XCTAssertTrue(context.model.pinboards.contains(where: { $0.id == Pinboard.usefulLinksID }))
        XCTAssertNotNil(context.model.errorMessage)
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
}
