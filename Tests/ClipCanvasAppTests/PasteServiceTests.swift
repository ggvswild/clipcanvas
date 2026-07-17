import AppKit
import Foundation
import XCTest
@testable import ClipCanvasApp
import ClipCanvasCore

final class PasteServiceTests: XCTestCase {
    private var root: URL!
    private var repository: ClipboardRepository!
    private var pasteboard: NSPasteboard!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        repository = ClipboardRepository(
            database: try SQLiteDatabase(url: root.appendingPathComponent("db.sqlite3")),
            blobStore: try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        )
        pasteboard = NSPasteboard(
            name: .init("dev.clipcanvas.paste-tests.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
    }

    override func tearDownWithError() throws {
        pasteboard.clearContents()
        try? FileManager.default.removeItem(at: root)
    }

    @MainActor
    func testWritePreservesRichAndPlainRepresentationsWithInternalMarker() throws {
        let service = PasteService(pasteboard: pasteboard, repository: repository)
        let html = Data("<b>ClipCanvas</b>".utf8)
        let item = try repository.upsert(
            ClipboardDraft(
                kind: .richText,
                plainText: "ClipCanvas",
                source: .init(bundleID: "tests", name: "Tests"),
                representations: [
                    .init(uti: NSPasteboard.PasteboardType.html.rawValue, data: html)
                ]
            )
        )

        try service.write(item: item, plainText: false)

        XCTAssertEqual(pasteboard.data(forType: .html), html)
        XCTAssertEqual(pasteboard.string(forType: .string), "ClipCanvas")
        XCTAssertNotNil(
            pasteboard.data(forType: .init(PrivacyPolicy.internalMarkerType))
        )
    }

    @MainActor
    func testPlainTextModeOmitsRichRepresentation() throws {
        let service = PasteService(pasteboard: pasteboard, repository: repository)
        let item = try repository.upsert(
            ClipboardDraft(
                kind: .richText,
                plainText: "plain",
                source: .init(bundleID: "tests", name: "Tests"),
                representations: [
                    .init(
                        uti: NSPasteboard.PasteboardType.html.rawValue,
                        data: Data("<i>plain</i>".utf8)
                    )
                ]
            )
        )

        try service.write(item: item, plainText: true)

        XCTAssertEqual(pasteboard.string(forType: .string), "plain")
        XCTAssertNil(pasteboard.data(forType: .html))
    }

    @MainActor
    func testClipboardOnlyPerformDoesNotRequireAccessibility() async throws {
        let service = PasteService(pasteboard: pasteboard, repository: repository)
        let item = try repository.upsert(
            ClipboardDraft(
                kind: .text,
                plainText: "clipboard only",
                source: .init(bundleID: "tests", name: "Tests"),
                representations: [
                    .init(uti: NSPasteboard.PasteboardType.string.rawValue, data: Data("clipboard only".utf8))
                ]
            )
        )

        try await service.perform(
            item: item,
            strategy: .clipboardOnly,
            plainText: false,
            targetApplication: nil
        )

        XCTAssertEqual(pasteboard.string(forType: .string), "clipboard only")
    }

    @MainActor
    func testActiveAppStrategyActivatesTargetAndEmitsPasteWhenTrusted() async throws {
        var emittedPaste = false
        let service = PasteService(
            pasteboard: pasteboard,
            repository: repository,
            accessibilityTrusted: { true },
            activateApplication: { _ in },
            emitPasteCommand: { emittedPaste = true }
        )
        let item = try repository.upsert(
            ClipboardDraft(
                kind: .text,
                plainText: "active app",
                source: .init(bundleID: "tests", name: "Tests"),
                representations: [
                    .init(uti: NSPasteboard.PasteboardType.string.rawValue, data: Data("active app".utf8))
                ]
            )
        )

        try await service.perform(
            item: item,
            strategy: .activeApp,
            plainText: false,
            targetApplication: nil
        )

        XCTAssertTrue(emittedPaste)
    }
}
