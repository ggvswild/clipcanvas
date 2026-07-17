import Foundation
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
}
