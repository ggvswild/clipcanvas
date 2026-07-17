import Foundation
import XCTest
@testable import ClipCanvasCore

final class MCPToolRouterTests: XCTestCase {
    private var root: URL!
    private var repository: ClipboardRepository!
    private var router: MCPToolRouter!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let database = try SQLiteDatabase(url: root.appendingPathComponent("db.sqlite3"))
        let blobs = try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        repository = ClipboardRepository(database: database, blobStore: blobs)
        router = MCPToolRouter(repository: repository)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testToolsListIsDeterministicAndIncludesReadWriteAndManageTools() async {
        let response = await router.handle(
            request: MCPRequest(id: .integer(1), method: "tools/list"),
            authorization: authorization(scopes: [.read, .write, .manage])
        )
        let names = response.result?["tools"]?.arrayValue?
            .compactMap { $0["name"]?.stringValue }

        XCTAssertEqual(names, names?.sorted())
        XCTAssertEqual(
            Set(names ?? []),
            [
                "clipboard_delete", "clipboard_list", "clipboard_pin",
                "clipboard_read", "clipboard_search", "clipboard_write",
                "pinboard_create", "pinboard_delete", "pinboard_list",
                "pinboard_read"
            ]
        )
    }

    func testReadClientCanListButCannotWrite() async throws {
        _ = try repository.upsert(textDraft("hello MCP"))
        let read = authorization(scopes: [.read])

        let list = await call("clipboard_list", arguments: ["limit": .integer(10)], as: read)
        let write = await call("clipboard_write", arguments: ["text": .string("denied")], as: read)

        XCTAssertNil(list.error)
        XCTAssertEqual(list.result?["isError"], .bool(false))
        XCTAssertNil(write.error)
        XCTAssertEqual(write.result?["isError"], .bool(true))
        XCTAssertEqual(write.result?["structuredContent"]?["code"], .string("forbidden"))
        XCTAssertEqual(try repository.list().items.count, 1)
    }

    func testInvalidArgumentsAndMissingItemReturnToolErrors() async {
        let auth = authorization(scopes: [.read, .write])
        let invalid = await call("clipboard_list", arguments: ["limit": .integer(1000)], as: auth)
        let missing = await call(
            "clipboard_read",
            arguments: ["id": .string(UUID().uuidString)],
            as: auth
        )

        XCTAssertEqual(invalid.result?["isError"], .bool(true))
        XCTAssertEqual(invalid.result?["structuredContent"]?["code"], .string("invalid_arguments"))
        XCTAssertEqual(missing.result?["isError"], .bool(true))
        XCTAssertEqual(missing.result?["structuredContent"]?["code"], .string("not_found"))
    }

    func testResourcesListAndReadExposePinboardWithoutBinaryContent() async throws {
        let item = try repository.upsert(textDraft("resource text"))
        try repository.pin(itemID: item.id, to: Pinboard.usefulLinksID)
        let auth = authorization(scopes: [.read])

        let listed = await router.handle(
            request: MCPRequest(id: .integer(1), method: "resources/list"),
            authorization: auth
        )
        let read = await router.handle(
            request: MCPRequest(
                id: .integer(2),
                method: "resources/read",
                params: .object([
                    "uri": .string("clipcanvas://pinboards/\(Pinboard.usefulLinksID.uuidString)")
                ])
            ),
            authorization: auth
        )

        XCTAssertNotNil(listed.result?["resources"]?.arrayValue?
            .first(where: { $0["uri"]?.stringValue?.contains("pinboards") == true }))
        XCTAssertEqual(
            read.result?["contents"]?.arrayValue?.first?["mimeType"],
            .string("application/json")
        )
        XCTAssertFalse(
            read.result?["contents"]?.arrayValue?.first?["text"]?.stringValue?
                .contains("base64") ?? true
        )
    }

    private func call(
        _ name: String,
        arguments: [String: JSONValue],
        as authorization: MCPAuthorization
    ) async -> MCPResponse {
        await router.handle(
            request: MCPRequest(
                id: .integer(1),
                method: "tools/call",
                params: .object([
                    "name": .string(name),
                    "arguments": .object(arguments)
                ])
            ),
            authorization: authorization
        )
    }

    private func authorization(scopes: Set<MCPAuthorizationScope>) -> MCPAuthorization {
        MCPAuthorization(
            clientID: UUID(),
            displayName: "Tests",
            scopes: scopes
        )
    }

    private func textDraft(_ text: String) -> ClipboardDraft {
        ClipboardDraft(
            kind: .text,
            plainText: text,
            source: .init(bundleID: "tests", name: "Tests"),
            representations: [
                .init(uti: "public.utf8-plain-text", data: Data(text.utf8))
            ]
        )
    }
}
