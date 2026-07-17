import Foundation
import XCTest
@testable import ClipCanvasCore

final class AuthorizationTests: XCTestCase {
    private var root: URL!
    private var repository: ClipboardRepository!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let database = try SQLiteDatabase(url: root.appendingPathComponent("db.sqlite3"))
        repository = ClipboardRepository(
            database: database,
            blobStore: try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testTokenIsReturnedOnceStoredAsHashAndAuthorizesScopes() throws {
        let issued = try repository.createAuthorizedClient(
            displayName: "Claude Desktop",
            scopes: [.read, .write]
        )

        XCTAssertGreaterThanOrEqual(issued.token.count, 40)
        XCTAssertFalse(try repository.authorizationStorageContains(issued.token))
        XCTAssertEqual(
            try repository.authorize(token: issued.token)?.scopes,
            [.read, .write]
        )
        XCTAssertEqual(try repository.listAuthorizedClients().first?.displayName, "Claude Desktop")
    }

    func testRevocationIsImmediate() throws {
        let issued = try repository.createAuthorizedClient(
            displayName: "Local agent",
            scopes: [.read]
        )
        XCTAssertNotNil(try repository.authorize(token: issued.token))

        try repository.revokeAuthorizedClient(id: issued.client.id)

        XCTAssertNil(try repository.authorize(token: issued.token))
        XCTAssertNotNil(try repository.listAuthorizedClients().first?.revokedAt)
    }

    func testAuditStoresMethodAndOutcomeButNoClipboardContent() throws {
        let client = try repository.createAuthorizedClient(
            displayName: "Audited",
            scopes: [.read]
        ).client
        try repository.recordAudit(
            clientID: client.id,
            method: "clipboard_read",
            itemID: UUID(),
            outcome: .success,
            detail: "representation omitted"
        )

        let event = try XCTUnwrap(repository.listAuditEvents(limit: 10).first)
        XCTAssertEqual(event.method, "clipboard_read")
        XCTAssertEqual(event.outcome, .success)
        XCTAssertEqual(event.detail, "representation omitted")
    }
}
