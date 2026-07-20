import Foundation
import XCTest
@testable import ClipCanvasCore

final class PastePinboardImporterTests: XCTestCase {
    private var root: URL!
    private var repository: ClipboardRepository!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        repository = ClipboardRepository(
            database: try SQLiteDatabase(url: root.appendingPathComponent("clipcanvas.sqlite3")),
            blobStore: try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testImportCreatesPinboardsAndPreservesItemMetadata() throws {
        let exportDirectory = root.appendingPathComponent("paste-export", isDirectory: true)
        try FileManager.default.createDirectory(
            at: exportDirectory,
            withIntermediateDirectories: true
        )
        try Data(Self.exportJSON.utf8).write(
            to: exportDirectory.appendingPathComponent("pinboard-export.json")
        )

        let summary = try PastePinboardImporter(repository: repository)
            .importDirectory(exportDirectory)

        XCTAssertEqual(summary.pinboardsProcessed, 2)
        XCTAssertEqual(summary.itemsProcessed, 2)
        XCTAssertEqual(summary.imagesRecovered, 0)

        let pinboards = try repository.listPinboards()
        let code = try XCTUnwrap(pinboards.first(where: { $0.name == "Code" }))
        let links = try XCTUnwrap(pinboards.first(where: { $0.name == "Links" }))

        let codeItem = try XCTUnwrap(repository.items(in: code.id).items.first)
        XCTAssertEqual(codeItem.kind, .richText)
        XCTAssertEqual(codeItem.plainText, "let answer = 42")
        XCTAssertEqual(codeItem.title, "Answer")
        XCTAssertEqual(codeItem.source.bundleID, "com.apple.dt.Xcode")
        XCTAssertEqual(codeItem.source.name, "Xcode")
        XCTAssertEqual(
            Set(codeItem.representations.map(\.uti)),
            ["public.html", "public.utf8-plain-text"]
        )

        let linkItem = try XCTUnwrap(repository.items(in: links.id).items.first)
        XCTAssertEqual(linkItem.kind, .link)
        XCTAssertEqual(linkItem.plainText, "https://example.com/docs")
        XCTAssertEqual(linkItem.title, "Example Docs")
        XCTAssertEqual(linkItem.metadata.domain, "example.com")
        XCTAssertEqual(linkItem.representations.map(\.uti), ["public.url"])
    }

    func testArchiveDecoderRecoversPNGFromVersionedKeyedArchive() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01])
        let propertyList = try PropertyListSerialization.data(
            fromPropertyList: ["$objects": ["$null", png]],
            format: .binary,
            options: 0
        )
        var archive = Data([0x01])
        archive.append(propertyList)

        XCTAssertEqual(PasteArchiveDecoder.imageData(from: archive), png)
    }

    private static let exportJSON = #"""
    {
      "exported_at": "2026-07-17T14:47:01+08:00",
      "source_app": "Paste 2.1.1",
      "source_db": "Paste.db",
      "note": "test fixture",
      "pinboards": [
        {
          "id": 3,
          "name": "Code",
          "kind": "pinboard",
          "display_order": 3,
          "capacity": null
        },
        {
          "id": 7,
          "name": "Links",
          "kind": "pinboard",
          "display_order": 5,
          "capacity": null
        }
      ],
      "item_count": 2,
      "items": [
        {
          "index": 1,
          "db_pk": 101,
          "pinboard_id": 3,
          "pinboard_name": "Code",
          "order_in_pinboard": 0,
          "type": "text",
          "title": "Answer",
          "url_name": null,
          "text_length": 15,
          "total_size": 58,
          "timestamp": "2026-07-15 17:35:17 +0800",
          "checksum": "fixture-code",
          "source_app": "Xcode",
          "source_bundle": "com.apple.dt.Xcode",
          "pasteboard_types": ["public.html", "public.utf8-plain-text"],
          "text": "let answer = 42",
          "html": "<code>let answer = 42</code>",
          "url": null
        },
        {
          "index": 2,
          "db_pk": 102,
          "pinboard_id": 7,
          "pinboard_name": "Links",
          "order_in_pinboard": 0,
          "type": "link",
          "title": null,
          "url_name": "Example Docs",
          "text_length": 24,
          "total_size": 24,
          "timestamp": "2024-01-16 20:08:43 +0800",
          "checksum": "fixture-link",
          "source_app": "Safari",
          "source_bundle": "com.apple.Safari",
          "pasteboard_types": ["public.url"],
          "text": "https://example.com/docs",
          "html": null,
          "url": "https://example.com/docs"
        }
      ]
    }
    """#
}
