import AppKit
import ClipCanvasCore
import Foundation
import XCTest
@testable import ClipCanvasApp

@MainActor
final class AppModelTests: XCTestCase {
    func testPanelStartsHiddenAndToggles() {
        let model = AppModel()

        XCTAssertFalse(model.isPanelPresented)
        model.togglePanel()
        XCTAssertTrue(model.isPanelPresented)
    }

    func testPasteHidesPanelAndCopiesItem() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ClipboardRepository(
            database: try SQLiteDatabase(url: root.appendingPathComponent("history.sqlite3")),
            blobStore: try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        )
        let text = "single-click-card"
        let item = try repository.upsert(
            ClipboardDraft(
                kind: .text,
                plainText: text,
                source: .init(bundleID: "tests", name: "Tests"),
                representations: [
                    .init(
                        uti: NSPasteboard.PasteboardType.string.rawValue,
                        data: Data(text.utf8)
                    )
                ]
            )
        )
        let pasteboard = NSPasteboard(
            name: .init("dev.clipcanvas.app-model-tests.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
        var didHidePanel = false
        let model = AppModel()
        model.configure(
            repository: repository,
            pasteService: PasteService(pasteboard: pasteboard, repository: repository),
            targetApplication: { nil },
            hidePanel: { didHidePanel = true }
        )
        model.pasteStrategy = .clipboardOnly

        await model.paste(item)

        XCTAssertTrue(didHidePanel)
        XCTAssertEqual(pasteboard.string(forType: .string), text)
    }

    func testPastePromotesItemToMostRecentHistoryPosition() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ClipboardRepository(
            database: try SQLiteDatabase(url: root.appendingPathComponent("history.sqlite3")),
            blobStore: try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        )
        let olderItem = try repository.upsert(
            ClipboardDraft(
                kind: .text,
                plainText: "older",
                source: .init(bundleID: "tests", name: "Tests"),
                capturedAt: Date(timeIntervalSince1970: 100),
                representations: [
                    .init(
                        uti: NSPasteboard.PasteboardType.string.rawValue,
                        data: Data("older".utf8)
                    )
                ]
            )
        )
        let newerItem = try repository.upsert(
            ClipboardDraft(
                kind: .text,
                plainText: "newer",
                source: .init(bundleID: "tests", name: "Tests"),
                capturedAt: Date(timeIntervalSince1970: 200),
                representations: [
                    .init(
                        uti: NSPasteboard.PasteboardType.string.rawValue,
                        data: Data("newer".utf8)
                    )
                ]
            )
        )
        let pasteboard = NSPasteboard(
            name: .init("dev.clipcanvas.app-model-tests.\(UUID().uuidString)")
        )
        let model = AppModel()
        model.configure(
            repository: repository,
            pasteService: PasteService(pasteboard: pasteboard, repository: repository),
            targetApplication: { nil },
            hidePanel: {}
        )
        model.pasteStrategy = .clipboardOnly

        await model.paste(olderItem)

        let history = try repository.list().items
        XCTAssertEqual(history.map(\.id), [olderItem.id, newerItem.id])
        XCTAssertEqual(history.first?.copyCount, 2)
        XCTAssertEqual(model.items.map(\.id), [olderItem.id, newerItem.id])
    }
}
