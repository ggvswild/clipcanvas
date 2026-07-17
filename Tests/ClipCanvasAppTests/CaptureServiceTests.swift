import AppKit
import Foundation
import XCTest
@testable import ClipCanvasApp
import ClipCanvasCore

final class CaptureServiceTests: XCTestCase {
    func testCaptureNowPersistsAllowedPasteboardChangeOnlyOnce() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ClipboardRepository(
            database: try SQLiteDatabase(url: root.appendingPathComponent("history.sqlite3")),
            blobStore: try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        )
        let pasteboard = NSPasteboard(name: .init("dev.clipcanvas.tests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("captured", forType: .string)
        let service = CaptureService(
            pasteboard: pasteboard,
            repository: repository,
            captureExisting: true,
            configuration: { PrivacyConfiguration() },
            source: {
                ClipboardSource(bundleID: "com.apple.TextEdit", name: "TextEdit")
            }
        )

        try service.captureNow()
        try service.captureNow()

        let items = try repository.list().items
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.plainText, "captured")
        XCTAssertEqual(items.first?.copyCount, 1)
    }

    func testCaptureNowDoesNotPersistInternalWrite() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ClipboardRepository(
            database: try SQLiteDatabase(url: root.appendingPathComponent("history.sqlite3")),
            blobStore: try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        )
        let pasteboard = NSPasteboard(name: .init("dev.clipcanvas.tests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("owned", forType: .string)
        pasteboard.setData(Data(), forType: .init(PrivacyPolicy.internalMarkerType))
        let service = CaptureService(
            pasteboard: pasteboard,
            repository: repository,
            captureExisting: true,
            configuration: { PrivacyConfiguration() },
            source: {
                ClipboardSource(bundleID: "dev.clipcanvas.app", name: "ClipCanvas")
            }
        )

        try service.captureNow()

        XCTAssertTrue(try repository.list().items.isEmpty)
    }

    func testDefaultServiceDoesNotCaptureClipboardThatPredatesLaunch() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ClipboardRepository(
            database: try SQLiteDatabase(url: root.appendingPathComponent("history.sqlite3")),
            blobStore: try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        )
        let pasteboard = NSPasteboard(name: .init("dev.clipcanvas.tests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("predates launch", forType: .string)
        let service = CaptureService(
            pasteboard: pasteboard,
            repository: repository,
            configuration: { PrivacyConfiguration() },
            source: {
                ClipboardSource(bundleID: "dev.clipcanvas.app", name: "ClipCanvas")
            }
        )

        try service.captureNow()

        XCTAssertTrue(try repository.list().items.isEmpty)
    }
}
