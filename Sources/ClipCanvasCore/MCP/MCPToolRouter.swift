import Foundation

public final class MCPToolRouter: @unchecked Sendable {
    public static let protocolVersion = "2025-11-25"
    public static let serverVersion = "0.1.0"
    public static let maximumRepresentationBytes = 2 * 1_024 * 1_024

    private struct Tool {
        let definition: MCPToolDefinition
        let scope: MCPAuthorizationScope
    }

    private let repository: ClipboardRepository
    private let tools: [Tool]

    public init(repository: ClipboardRepository) {
        self.repository = repository
        tools = Self.makeTools().sorted { $0.definition.name < $1.definition.name }
    }

    public func handle(
        request: MCPRequest,
        authorization: MCPAuthorization?
    ) async -> MCPResponse {
        switch request.method {
        case "initialize":
            return initialize(request)
        case "notifications/initialized":
            return MCPResponse(id: request.id, result: .object([:]))
        case "ping":
            return MCPResponse(id: request.id, result: .object([:]))
        case "tools/list":
            guard let authorization else {
                return unauthorized(request)
            }
            let visible = tools.filter { authorization.scopes.contains($0.scope) }
            let result = JSONValue.object([
                "tools": .array(visible.map { encodeTool($0.definition) })
            ])
            audit(authorization, method: request.method, outcome: .success)
            return MCPResponse(id: request.id, result: result)
        case "tools/call":
            return callTool(request, authorization: authorization)
        case "resources/list":
            return listResources(request, authorization: authorization)
        case "resources/read":
            return readResource(request, authorization: authorization)
        default:
            audit(authorization, method: request.method, outcome: .failure, detail: "unknown method")
            return MCPResponse(
                id: request.id,
                error: MCPError(code: -32601, message: "Method not found")
            )
        }
    }

    private func initialize(_ request: MCPRequest) -> MCPResponse {
        let requested = request.params?["protocolVersion"]?.stringValue
        guard requested == nil || requested == Self.protocolVersion else {
            return MCPResponse(
                id: request.id,
                error: MCPError(
                    code: -32602,
                    message: "Unsupported protocol version",
                    data: .object(["supported": .string(Self.protocolVersion)])
                )
            )
        }
        return MCPResponse(
            id: request.id,
            result: .object([
                "protocolVersion": .string(Self.protocolVersion),
                "capabilities": .object([
                    "tools": .object(["listChanged": .bool(false)]),
                    "resources": .object([
                        "subscribe": .bool(false),
                        "listChanged": .bool(false)
                    ])
                ]),
                "serverInfo": .object([
                    "name": .string("clipcanvas"),
                    "title": .string("ClipCanvas"),
                    "version": .string(Self.serverVersion)
                ]),
                "instructions": .string(
                    "Access local clipboard history and Pinboards using explicitly granted scopes."
                )
            ])
        )
    }

    private func callTool(
        _ request: MCPRequest,
        authorization: MCPAuthorization?
    ) -> MCPResponse {
        guard let authorization else {
            return unauthorized(request)
        }
        guard let name = request.params?["name"]?.stringValue,
              let tool = tools.first(where: { $0.definition.name == name }) else {
            return MCPResponse(
                id: request.id,
                error: MCPError(code: -32602, message: "Unknown or missing tool name")
            )
        }
        guard authorization.scopes.contains(tool.scope) else {
            audit(authorization, method: name, outcome: .denied, detail: "missing \(tool.scope.rawValue) scope")
            return toolError(
                request.id,
                code: "forbidden",
                message: "Client lacks the \(tool.scope.rawValue) scope"
            )
        }
        let arguments = request.params?["arguments"]?.objectValue ?? [:]
        do {
            let value = try execute(name, arguments: arguments)
            audit(
                authorization,
                method: name,
                itemID: itemID(from: arguments),
                outcome: .success
            )
            return toolSuccess(request.id, value: value)
        } catch let error as ToolFailure {
            audit(
                authorization,
                method: name,
                itemID: itemID(from: arguments),
                outcome: error.code == "forbidden" ? .denied : .failure,
                detail: error.code
            )
            return toolError(request.id, code: error.code, message: error.message)
        } catch ClipboardRepositoryError.itemNotFound {
            audit(authorization, method: name, outcome: .failure, detail: "not_found")
            return toolError(request.id, code: "not_found", message: "Clipboard item not found")
        } catch ClipboardRepositoryError.pinboardNotFound {
            audit(authorization, method: name, outcome: .failure, detail: "not_found")
            return toolError(request.id, code: "not_found", message: "Pinboard not found")
        } catch {
            audit(authorization, method: name, outcome: .failure, detail: "internal_error")
            return toolError(request.id, code: "internal_error", message: "The operation failed")
        }
    }

    private func execute(
        _ name: String,
        arguments: [String: JSONValue]
    ) throws -> JSONValue {
        switch name {
        case "clipboard_list":
            let limit = try validatedLimit(arguments["limit"])
            let kind = try validatedKind(arguments["kind"])
            let page = try repository.list(.init(limit: limit, kind: kind))
            return .object([
                "items": .array(page.items.map(encodeItemSummary)),
                "nextCursor": page.nextCursor.map {
                    .string(ISO8601DateFormatter().string(from: $0))
                } ?? .null
            ])
        case "clipboard_search":
            let query = try requiredString(arguments, "query", maximum: 500)
            let limit = try validatedLimit(arguments["limit"])
            let page = try repository.search(query, limit: limit)
            return .object(["items": .array(page.items.map(encodeItemSummary))])
        case "clipboard_read":
            let id = try requiredUUID(arguments, "id")
            let includeRepresentations = arguments["includeRepresentations"]?.boolValue ?? false
            return try encodeItem(
                repository.item(id: id),
                includeRepresentations: includeRepresentations
            )
        case "clipboard_write":
            let text = try requiredString(
                arguments,
                "text",
                maximum: Self.maximumRepresentationBytes
            )
            let title = try optionalString(arguments, "title", maximum: 500)
            let kind: ClipboardKind = URL(string: text)?.scheme == nil ? .text : .link
            let item = try repository.upsert(
                ClipboardDraft(
                    kind: kind,
                    plainText: text,
                    title: title,
                    source: .init(bundleID: "dev.clipcanvas.mcp", name: "MCP"),
                    representations: [
                        .init(uti: "public.utf8-plain-text", data: Data(text.utf8))
                    ]
                )
            )
            return encodeItemSummary(item)
        case "clipboard_delete":
            let id = try requiredUUID(arguments, "id")
            try repository.delete(id: id)
            return .object(["deleted": .bool(true), "id": .string(id.uuidString)])
        case "clipboard_pin":
            let itemID = try requiredUUID(arguments, "itemId")
            let pinboardID = try requiredUUID(arguments, "pinboardId")
            try repository.pin(itemID: itemID, to: pinboardID)
            return .object([
                "pinned": .bool(true),
                "itemId": .string(itemID.uuidString),
                "pinboardId": .string(pinboardID.uuidString)
            ])
        case "pinboard_list":
            return .object([
                "pinboards": .array(try repository.listPinboards().map(encodePinboard))
            ])
        case "pinboard_read":
            let id = try requiredUUID(arguments, "id")
            guard let board = try repository.listPinboards().first(where: { $0.id == id }) else {
                throw ClipboardRepositoryError.pinboardNotFound
            }
            let limit = try validatedLimit(arguments["limit"])
            return .object([
                "pinboard": encodePinboard(board),
                "items": .array(
                    try repository.items(in: id, limit: limit).items.map(encodeItemSummary)
                )
            ])
        case "pinboard_create":
            let name = try requiredString(arguments, "name", maximum: 100)
            let color = try optionalString(arguments, "color", maximum: 30) ?? "cyan"
            let symbol = try optionalString(arguments, "symbol", maximum: 80) ?? "pin.fill"
            return encodePinboard(
                try repository.createPinboard(name: name, color: color, symbol: symbol)
            )
        case "pinboard_delete":
            let id = try requiredUUID(arguments, "id")
            try repository.deletePinboard(id: id)
            return .object(["deleted": .bool(true), "id": .string(id.uuidString)])
        default:
            throw ToolFailure(code: "not_found", message: "Unknown tool")
        }
    }

    private func listResources(
        _ request: MCPRequest,
        authorization: MCPAuthorization?
    ) -> MCPResponse {
        guard let authorization else { return unauthorized(request) }
        guard authorization.scopes.contains(.read) else {
            return MCPResponse(
                id: request.id,
                error: MCPError(code: -32003, message: "Read scope required")
            )
        }
        do {
            var resources: [JSONValue] = [
                .object([
                    "uri": .string("clipcanvas://recent"),
                    "name": .string("Recent clipboard history"),
                    "mimeType": .string("application/json")
                ])
            ]
            resources.append(contentsOf: try repository.listPinboards().map { board in
                .object([
                    "uri": .string("clipcanvas://pinboards/\(board.id.uuidString)"),
                    "name": .string(board.name),
                    "mimeType": .string("application/json")
                ])
            })
            audit(authorization, method: request.method, outcome: .success)
            return MCPResponse(id: request.id, result: .object(["resources": .array(resources)]))
        } catch {
            audit(authorization, method: request.method, outcome: .failure)
            return MCPResponse(
                id: request.id,
                error: MCPError(code: -32603, message: "Unable to list resources")
            )
        }
    }

    private func readResource(
        _ request: MCPRequest,
        authorization: MCPAuthorization?
    ) -> MCPResponse {
        guard let authorization else { return unauthorized(request) }
        guard authorization.scopes.contains(.read) else {
            return MCPResponse(
                id: request.id,
                error: MCPError(code: -32003, message: "Read scope required")
            )
        }
        guard let uri = request.params?["uri"]?.stringValue else {
            return MCPResponse(
                id: request.id,
                error: MCPError(code: -32602, message: "Resource URI is required")
            )
        }
        do {
            let payload: JSONValue
            if uri == "clipcanvas://recent" {
                payload = .object([
                    "items": .array(try repository.list(.init(limit: 50)).items.map(encodeItemSummary))
                ])
            } else if let identifier = uri.split(separator: "/").last,
                      let id = UUID(uuidString: String(identifier)),
                      try repository.listPinboards().contains(where: { $0.id == id }) {
                payload = .object([
                    "items": .array(
                        try repository.items(in: id, limit: 100).items.map(encodeItemSummary)
                    )
                ])
            } else {
                return MCPResponse(
                    id: request.id,
                    error: MCPError(code: -32002, message: "Resource not found")
                )
            }
            let data = try JSONEncoder().encode(payload)
            let text = String(decoding: data, as: UTF8.self)
            audit(authorization, method: request.method, outcome: .success)
            return MCPResponse(
                id: request.id,
                result: .object([
                    "contents": .array([
                        .object([
                            "uri": .string(uri),
                            "mimeType": .string("application/json"),
                            "text": .string(text)
                        ])
                    ])
                ])
            )
        } catch {
            audit(authorization, method: request.method, outcome: .failure)
            return MCPResponse(
                id: request.id,
                error: MCPError(code: -32603, message: "Unable to read resource")
            )
        }
    }

    private func encodeItemSummary(_ item: ClipboardItem) -> JSONValue {
        .object([
            "id": .string(item.id.uuidString),
            "kind": .string(item.kind.rawValue),
            "text": item.plainText.map(JSONValue.string) ?? .null,
            "title": item.title.map(JSONValue.string) ?? .null,
            "source": .object([
                "bundleId": item.source.bundleID.map(JSONValue.string) ?? .null,
                "name": .string(item.source.name)
            ]),
            "lastCopiedAt": .string(ISO8601DateFormatter().string(from: item.lastCopiedAt)),
            "copyCount": .integer(item.copyCount),
            "isSensitive": .bool(item.isSensitive)
        ])
    }

    private func encodeItem(
        _ item: ClipboardItem,
        includeRepresentations: Bool
    ) throws -> JSONValue {
        guard includeRepresentations else { return encodeItemSummary(item) }
        var total = 0
        var representations: [JSONValue] = []
        for representation in item.representations {
            total += representation.byteCount
            guard total <= Self.maximumRepresentationBytes else {
                throw ToolFailure(
                    code: "payload_too_large",
                    message: "Representations exceed the 2 MiB response limit"
                )
            }
            let data = try repository.representationData(representation)
            representations.append(
                .object([
                    "uti": .string(representation.uti),
                    "byteCount": .integer(representation.byteCount),
                    "data": .string(data.base64EncodedString())
                ])
            )
        }
        guard case var .object(value) = encodeItemSummary(item) else {
            return encodeItemSummary(item)
        }
        value["representations"] = .array(representations)
        return .object(value)
    }

    private func encodePinboard(_ pinboard: Pinboard) -> JSONValue {
        .object([
            "id": .string(pinboard.id.uuidString),
            "name": .string(pinboard.name),
            "color": .string(pinboard.color),
            "symbol": .string(pinboard.symbol),
            "isSystem": .bool(pinboard.isSystem)
        ])
    }

    private func toolSuccess(_ id: MCPIdentifier?, value: JSONValue) -> MCPResponse {
        let text: String
        if let data = try? JSONEncoder().encode(value) {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = "{}"
        }
        return MCPResponse(
            id: id,
            result: .object([
                "content": .array([.object(["type": .string("text"), "text": .string(text)])]),
                "structuredContent": value,
                "isError": .bool(false)
            ])
        )
    }

    private func toolError(
        _ id: MCPIdentifier?,
        code: String,
        message: String
    ) -> MCPResponse {
        MCPResponse(
            id: id,
            result: .object([
                "content": .array([.object(["type": .string("text"), "text": .string(message)])]),
                "structuredContent": .object([
                    "code": .string(code),
                    "message": .string(message)
                ]),
                "isError": .bool(true)
            ])
        )
    }

    private func unauthorized(_ request: MCPRequest) -> MCPResponse {
        MCPResponse(
            id: request.id,
            error: MCPError(code: -32001, message: "Authorization required")
        )
    }

    private func audit(
        _ authorization: MCPAuthorization?,
        method: String,
        itemID: UUID? = nil,
        outcome: MCPAuditOutcome,
        detail: String? = nil
    ) {
        try? repository.recordAudit(
            clientID: authorization?.clientID,
            method: method,
            itemID: itemID,
            outcome: outcome,
            detail: detail
        )
    }

    private func itemID(from arguments: [String: JSONValue]) -> UUID? {
        let text = arguments["id"]?.stringValue ?? arguments["itemId"]?.stringValue
        return text.flatMap(UUID.init(uuidString:))
    }

    private func requiredUUID(
        _ arguments: [String: JSONValue],
        _ key: String
    ) throws -> UUID {
        guard let text = arguments[key]?.stringValue,
              let value = UUID(uuidString: text) else {
            throw ToolFailure(code: "invalid_arguments", message: "\(key) must be a UUID")
        }
        return value
    }

    private func requiredString(
        _ arguments: [String: JSONValue],
        _ key: String,
        maximum: Int
    ) throws -> String {
        guard let value = arguments[key]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              value.utf8.count <= maximum else {
            throw ToolFailure(
                code: "invalid_arguments",
                message: "\(key) is required and must be at most \(maximum) bytes"
            )
        }
        return value
    }

    private func optionalString(
        _ arguments: [String: JSONValue],
        _ key: String,
        maximum: Int
    ) throws -> String? {
        guard let raw = arguments[key] else { return nil }
        guard let value = raw.stringValue,
              value.utf8.count <= maximum else {
            throw ToolFailure(code: "invalid_arguments", message: "\(key) is invalid")
        }
        return value
    }

    private func validatedLimit(_ raw: JSONValue?) throws -> Int {
        guard let raw else { return 50 }
        guard let value = raw.integerValue, (1...200).contains(value) else {
            throw ToolFailure(
                code: "invalid_arguments",
                message: "limit must be between 1 and 200"
            )
        }
        return value
    }

    private func validatedKind(_ raw: JSONValue?) throws -> ClipboardKind? {
        guard let raw else { return nil }
        guard let value = raw.stringValue,
              let kind = ClipboardKind(rawValue: value) else {
            throw ToolFailure(code: "invalid_arguments", message: "kind is invalid")
        }
        return kind
    }

    private func encodeTool(_ definition: MCPToolDefinition) -> JSONValue {
        .object([
            "name": .string(definition.name),
            "title": .string(definition.title),
            "description": .string(definition.description),
            "inputSchema": definition.inputSchema
        ])
    }

    private static func makeTools() -> [Tool] {
        [
            tool("clipboard_list", "List clipboard items", "List recent clipboard history.", .read, [
                "limit": integerSchema(minimum: 1, maximum: 200),
                "kind": enumSchema(ClipboardKind.allCases.map(\.rawValue))
            ]),
            tool("clipboard_search", "Search clipboard", "Search local clipboard text and titles.", .read, [
                "query": stringSchema(),
                "limit": integerSchema(minimum: 1, maximum: 200)
            ], required: ["query"]),
            tool("clipboard_read", "Read clipboard item", "Read one item and optionally its representations.", .read, [
                "id": stringSchema(format: "uuid"),
                "includeRepresentations": .object(["type": .string("boolean")])
            ], required: ["id"]),
            tool("clipboard_write", "Write clipboard item", "Add a local text or link item.", .write, [
                "text": stringSchema(),
                "title": stringSchema()
            ], required: ["text"]),
            tool("clipboard_pin", "Pin clipboard item", "Pin an item to a Pinboard.", .write, [
                "itemId": stringSchema(format: "uuid"),
                "pinboardId": stringSchema(format: "uuid")
            ], required: ["itemId", "pinboardId"]),
            tool("clipboard_delete", "Delete clipboard item", "Delete one clipboard item.", .write, [
                "id": stringSchema(format: "uuid")
            ], required: ["id"]),
            tool("pinboard_list", "List Pinboards", "List local Pinboards.", .read),
            tool("pinboard_read", "Read Pinboard", "Read items from one Pinboard.", .read, [
                "id": stringSchema(format: "uuid"),
                "limit": integerSchema(minimum: 1, maximum: 200)
            ], required: ["id"]),
            tool("pinboard_create", "Create Pinboard", "Create a local Pinboard.", .manage, [
                "name": stringSchema(),
                "color": stringSchema(),
                "symbol": stringSchema()
            ], required: ["name"]),
            tool("pinboard_delete", "Delete Pinboard", "Delete a non-system Pinboard.", .manage, [
                "id": stringSchema(format: "uuid")
            ], required: ["id"])
        ]
    }

    private static func tool(
        _ name: String,
        _ title: String,
        _ description: String,
        _ scope: MCPAuthorizationScope,
        _ properties: [String: JSONValue] = [:],
        required: [String] = []
    ) -> Tool {
        var schema: [String: JSONValue] = [
            "type": .string("object"),
            "properties": .object(properties),
            "additionalProperties": .bool(false)
        ]
        if !required.isEmpty {
            schema["required"] = .array(required.map(JSONValue.string))
        }
        return Tool(
            definition: MCPToolDefinition(
                name: name,
                title: title,
                description: description,
                inputSchema: .object(schema)
            ),
            scope: scope
        )
    }

    private static func stringSchema(format: String? = nil) -> JSONValue {
        var value: [String: JSONValue] = ["type": .string("string")]
        if let format { value["format"] = .string(format) }
        return .object(value)
    }

    private static func integerSchema(minimum: Int, maximum: Int) -> JSONValue {
        .object([
            "type": .string("integer"),
            "minimum": .integer(minimum),
            "maximum": .integer(maximum)
        ])
    }

    private static func enumSchema(_ values: [String]) -> JSONValue {
        .object([
            "type": .string("string"),
            "enum": .array(values.map(JSONValue.string))
        ])
    }
}

private struct ToolFailure: Error {
    let code: String
    let message: String
}
