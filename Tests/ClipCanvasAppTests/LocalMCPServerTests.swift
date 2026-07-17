import Foundation
import XCTest
@testable import ClipCanvasApp
import ClipCanvasCore

final class LocalMCPServerTests: XCTestCase {
    private var root: URL!
    private var repository: ClipboardRepository!
    private var enabled = true
    private var server: LocalMCPServer!
    private var issued: IssuedMCPToken!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let database = try SQLiteDatabase(url: root.appendingPathComponent("db.sqlite3"))
        repository = ClipboardRepository(
            database: database,
            blobStore: try BlobStore(rootURL: root.appendingPathComponent("blobs"))
        )
        issued = try repository.createAuthorizedClient(
            displayName: "HTTP tests",
            scopes: [.read, .write]
        )
        server = LocalMCPServer(repository: repository, isEnabled: { [weak self] in
            self?.enabled ?? false
        })
    }

    override func tearDownWithError() throws {
        server.stop()
        try? FileManager.default.removeItem(at: root)
    }

    func testServerBindsOnlyToIPv4Loopback() {
        XCTAssertEqual(server.bindHost, "127.0.0.1")
        XCTAssertEqual(server.port, 49_219)
    }

    func testDisabledServerRejectsRequests() async throws {
        enabled = false

        let response = await post(token: issued.token)

        XCTAssertEqual(response.statusCode, 503)
    }

    func testMissingTokenIsUnauthorized() async throws {
        let response = await post(token: nil)

        XCTAssertEqual(response.statusCode, 401)
        XCTAssertEqual(response.headers["WWW-Authenticate"], "Bearer")
    }

    func testInvalidOriginAndNonLoopbackPeerAreForbidden() async throws {
        let badOrigin = await post(
            token: issued.token,
            headers: ["Origin": "https://evil.example"]
        )
        let remotePeer = await post(token: issued.token, remoteIsLoopback: false)

        XCTAssertEqual(badOrigin.statusCode, 403)
        XCTAssertEqual(remotePeer.statusCode, 403)
    }

    func testRevokedTokenIsUnauthorizedImmediately() async throws {
        try repository.revokeAuthorizedClient(id: issued.client.id)

        let response = await post(token: issued.token)

        XCTAssertEqual(response.statusCode, 401)
    }

    func testInitializeRoundTripReturnsJSONRPC() async throws {
        let response = await post(token: issued.token)
        let decoded = try JSONDecoder().decode(MCPResponse.self, from: response.body)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(decoded.id, .integer(1))
        XCTAssertEqual(
            decoded.result?["protocolVersion"],
            .string(MCPToolRouter.protocolVersion)
        )
    }

    func testOnlyPostMCPWithBoundedJSONBodyIsAccepted() async {
        let wrongPath = await server.handle(
            LocalHTTPRequest(
                method: "POST",
                path: "/other",
                headers: authorizationHeaders(issued.token),
                body: initializeBody()
            ),
            remoteIsLoopback: true
        )
        let missingLength = await server.handle(
            LocalHTTPRequest(
                method: "POST",
                path: "/mcp",
                headers: authorizationHeaders(issued.token)
                    .filter { $0.key != "Content-Length" },
                body: initializeBody()
            ),
            remoteIsLoopback: true
        )

        XCTAssertEqual(wrongPath.statusCode, 404)
        XCTAssertEqual(missingLength.statusCode, 411)
    }

    func testNetworkListenerAndStdioBridgeRoundTrip() async throws {
        try server.start()
        for _ in 0..<20 where server.status != .running {
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertEqual(server.status, .running)

        var request = URLRequest(url: URL(string: "http://127.0.0.1:49219/mcp")!)
        request.httpMethod = "POST"
        request.httpBody = initializeBody()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(issued.token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(
            try JSONDecoder().decode(MCPResponse.self, from: data).id,
            .integer(1)
        )

        let executable = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/debug/clipcanvas-mcp")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path))
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executable
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["CLIPCANVAS_TOKEN": issued.token],
            uniquingKeysWith: { _, token in token }
        )
        try process.run()
        input.fileHandleForWriting.write(initializeBody())
        input.fileHandleForWriting.write(Data("\n".utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()

        let bridgeData = output.fileHandleForReading.readDataToEndOfFile()
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(
            try JSONDecoder().decode(MCPResponse.self, from: bridgeData).id,
            .integer(1),
            String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    private func post(
        token: String?,
        headers: [String: String] = [:],
        remoteIsLoopback: Bool = true
    ) async -> LocalHTTPResponse {
        var allHeaders = headers
        if let token {
            allHeaders["Authorization"] = "Bearer \(token)"
        }
        allHeaders["Content-Type"] = "application/json"
        allHeaders["Content-Length"] = String(initializeBody().count)
        return await server.handle(
            LocalHTTPRequest(
                method: "POST",
                path: "/mcp",
                headers: allHeaders,
                body: initializeBody()
            ),
            remoteIsLoopback: remoteIsLoopback
        )
    }

    private func authorizationHeaders(_ token: String) -> [String: String] {
        [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json",
            "Content-Length": String(initializeBody().count)
        ]
    }

    private func initializeBody() -> Data {
        Data(
            """
            {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"tests","version":"1"}}}
            """.utf8
        )
    }
}
