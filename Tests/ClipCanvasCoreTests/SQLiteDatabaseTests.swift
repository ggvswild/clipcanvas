import Foundation
import SQLite3
import XCTest
@testable import ClipCanvasCore

final class SQLiteDatabaseTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testMigrationCreatesHistoryAndPinboardTables() throws {
        let database = try SQLiteDatabase(
            url: temporaryDirectory.appendingPathComponent("clipcanvas.sqlite3")
        )

        let names = try database.tableNames()

        XCTAssertTrue(names.contains("clipboard_items"))
        XCTAssertTrue(names.contains("item_representations"))
        XCTAssertTrue(names.contains("clipboard_fts"))
        XCTAssertTrue(names.contains("pinboards"))
        XCTAssertTrue(names.contains("pinboard_items"))
        XCTAssertTrue(names.contains("authorized_clients"))
        XCTAssertTrue(names.contains("audit_events"))

        let version = try database.rows("PRAGMA user_version").first?.integer("user_version")
        let columns = try database.rows("PRAGMA table_info(clipboard_items)")
        XCTAssertEqual(version, 2)
        XCTAssertTrue(columns.contains { $0.string("name") == "sort_index" })
    }

    func testMigratesV1HistoryIntoSortIndexByRecency() throws {
        let url = temporaryDirectory.appendingPathComponent("v1.sqlite3")
        try createLegacyV1Database(
            at: url,
            items: [
                ("OLD", 100),
                ("NEW", 200)
            ]
        )

        let database = try SQLiteDatabase(url: url)
        let version = try database.rows("PRAGMA user_version").first?.integer("user_version")
        let rows = try database.rows(
            """
            SELECT id, sort_index
            FROM clipboard_items
            ORDER BY sort_index ASC, last_copied_at DESC, id DESC
            """
        )

        XCTAssertEqual(version, 2)
        XCTAssertEqual(rows.compactMap { $0.string("id") }, ["NEW", "OLD"])
        XCTAssertEqual(rows.compactMap { $0.integer("sort_index") }, [0, 1])
    }

    func testMigrationCreatesUsefulLinksSystemPinboard() throws {
        let database = try SQLiteDatabase(
            url: temporaryDirectory.appendingPathComponent("clipcanvas.sqlite3")
        )

        let count = try database.scalarInt(
            "SELECT COUNT(*) FROM pinboards WHERE id = ? AND is_system = 1",
            bindings: [.text(Pinboard.usefulLinksID.uuidString)]
        )

        XCTAssertEqual(count, 1)
    }

    private func createLegacyV1Database(
        at url: URL,
        items: [(id: String, lastCopiedAt: Double)]
    ) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
        let openResult = sqlite3_open_v2(url.path, &handle, flags, nil)
        guard openResult == SQLITE_OK, let handle else {
            throw SQLiteFailure(code: openResult, message: "Unable to create legacy database", sql: nil)
        }
        defer { sqlite3_close(handle) }

        let statements = [
            """
            CREATE TABLE clipboard_items (
                id TEXT PRIMARY KEY NOT NULL,
                kind TEXT NOT NULL,
                plain_text TEXT,
                title TEXT,
                source_bundle_id TEXT,
                source_name TEXT,
                source_icon_path TEXT,
                content_hash TEXT NOT NULL UNIQUE,
                created_at REAL NOT NULL,
                last_copied_at REAL NOT NULL,
                copy_count INTEGER NOT NULL DEFAULT 1,
                is_sensitive INTEGER NOT NULL DEFAULT 0,
                metadata_json BLOB
            )
            """,
            "PRAGMA user_version = 1"
        ]
        for sql in statements {
            try execLegacy(sql, on: handle)
        }
        for item in items {
            try execLegacy(
                """
                INSERT INTO clipboard_items
                (id, kind, plain_text, title, source_name, content_hash,
                 created_at, last_copied_at, copy_count, is_sensitive)
                VALUES ('\(item.id)', 'text', '\(item.id)', NULL, 'TextEdit',
                        'hash-\(item.id)', \(item.lastCopiedAt), \(item.lastCopiedAt), 1, 0)
                """,
                on: handle
            )
        }
    }

    private func execLegacy(_ sql: String, on handle: OpaquePointer) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        let message = errorMessage.map { String(cString: $0) } ?? "SQLite exec failed"
        sqlite3_free(errorMessage)
        guard result == SQLITE_OK else {
            throw SQLiteFailure(code: result, message: message, sql: sql)
        }
    }
}
