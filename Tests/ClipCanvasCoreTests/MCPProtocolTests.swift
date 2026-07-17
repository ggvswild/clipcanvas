import Foundation
import XCTest
@testable import ClipCanvasCore

final class MCPProtocolTests: XCTestCase {
    func testRequestRoundTripsStringAndNumericIdentifiers() throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        let numeric = try decoder.decode(
            MCPRequest.self,
            from: Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#.utf8)
        )
        let string = try decoder.decode(
            MCPRequest.self,
            from: Data(#"{"jsonrpc":"2.0","id":"abc","method":"ping"}"#.utf8)
        )

        XCTAssertEqual(numeric.id, .integer(1))
        XCTAssertEqual(string.id, .string("abc"))
        XCTAssertNoThrow(try encoder.encode(numeric))
        XCTAssertNoThrow(try encoder.encode(string))
    }

    func testInitializeReturnsStableProtocolVersionAndCapabilities() async throws {
        let repository = try makeRepository()
        let router = MCPToolRouter(repository: repository)
        let response = await router.handle(
            request: MCPRequest(
                id: .integer(7),
                method: "initialize",
                params: .object([
                    "protocolVersion": .string("2025-11-25"),
                    "capabilities": .object([:])
                ])
            ),
            authorization: nil
        )

        XCTAssertNil(response.error)
        XCTAssertEqual(response.id, .integer(7))
        XCTAssertEqual(
            response.result?["protocolVersion"],
            .string("2025-11-25")
        )
        XCTAssertEqual(
            response.result?["serverInfo"]?["name"],
            .string("clipcanvas")
        )
        XCTAssertNotNil(response.result?["capabilities"]?["tools"])
        XCTAssertNotNil(response.result?["capabilities"]?["resources"])
    }

    private func makeRepository() throws -> ClipboardRepository {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let database = try SQLiteDatabase(url: root.appendingPathComponent("db.sqlite3"))
        let blobs = try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        return ClipboardRepository(database: database, blobStore: blobs)
    }
}
