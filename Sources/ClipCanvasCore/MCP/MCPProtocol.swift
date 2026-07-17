import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case integer(Int)
    case double(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .integer(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public subscript(_ key: String) -> JSONValue? {
        guard case let .object(value) = self else { return nil }
        return value[key]
    }

    public var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    public var arrayValue: [JSONValue]? {
        guard case let .array(value) = self else { return nil }
        return value
    }

    public var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    public var integerValue: Int? {
        guard case let .integer(value) = self else { return nil }
        return value
    }

    public var boolValue: Bool? {
        guard case let .bool(value) = self else { return nil }
        return value
    }
}

public enum MCPIdentifier: Codable, Equatable, Sendable {
    case integer(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .integer(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        }
    }
}

public struct MCPRequest: Codable, Equatable, Sendable {
    public var jsonrpc = "2.0"
    public let id: MCPIdentifier?
    public let method: String
    public let params: JSONValue?

    public init(
        id: MCPIdentifier? = nil,
        method: String,
        params: JSONValue? = nil
    ) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct MCPError: Codable, Equatable, Sendable {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public struct MCPResponse: Codable, Equatable, Sendable {
    public var jsonrpc = "2.0"
    public let id: MCPIdentifier?
    public let result: JSONValue?
    public let error: MCPError?

    public init(
        id: MCPIdentifier?,
        result: JSONValue? = nil,
        error: MCPError? = nil
    ) {
        self.id = id
        self.result = result
        self.error = error
    }
}

public struct MCPToolDefinition: Codable, Equatable, Sendable {
    public let name: String
    public let title: String
    public let description: String
    public let inputSchema: JSONValue

    public init(
        name: String,
        title: String,
        description: String,
        inputSchema: JSONValue
    ) {
        self.name = name
        self.title = title
        self.description = description
        self.inputSchema = inputSchema
    }
}
