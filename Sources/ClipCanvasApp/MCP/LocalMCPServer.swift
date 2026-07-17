import ClipCanvasCore
import Foundation
import Network

struct LocalHTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    static func parse(_ data: Data) throws -> LocalHTTPRequest {
        guard let boundary = data.range(of: Data("\r\n\r\n".utf8)) else {
            throw LocalHTTPParseError.incomplete
        }
        let headerData = data[..<boundary.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw LocalHTTPParseError.malformed
        }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw LocalHTTPParseError.malformed
        }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 3, parts[2].hasPrefix("HTTP/1.") else {
            throw LocalHTTPParseError.malformed
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else {
                throw LocalHTTPParseError.malformed
            }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { throw LocalHTTPParseError.malformed }
            headers[key] = value
        }
        let bodyStart = boundary.upperBound
        return LocalHTTPRequest(
            method: String(parts[0]).uppercased(),
            path: String(parts[1]),
            headers: headers,
            body: Data(data[bodyStart...])
        )
    }
}

struct LocalHTTPResponse: Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    init(
        statusCode: Int,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    var wireData: Data {
        let reason = switch statusCode {
        case 200: "OK"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 411: "Length Required"
        case 413: "Payload Too Large"
        case 415: "Unsupported Media Type"
        case 500: "Internal Server Error"
        case 503: "Service Unavailable"
        default: "Error"
        }
        var merged = headers
        merged["Content-Length"] = String(body.count)
        merged["Connection"] = "close"
        var text = "HTTP/1.1 \(statusCode) \(reason)\r\n"
        for (key, value) in merged.sorted(by: { $0.key < $1.key }) {
            text += "\(key): \(value)\r\n"
        }
        text += "\r\n"
        var data = Data(text.utf8)
        data.append(body)
        return data
    }
}

enum LocalHTTPParseError: Error {
    case incomplete
    case malformed
}

enum LocalMCPServerStatus: Equatable, Sendable {
    case stopped
    case starting
    case running
    case failed(String)
}

final class LocalMCPServer: @unchecked Sendable {
    static let maximumBodyBytes = 2 * 1_024 * 1_024

    let bindHost: String
    let port: UInt16

    private let repository: ClipboardRepository
    private let router: MCPToolRouter
    private let isEnabled: () -> Bool
    private let queue = DispatchQueue(label: "dev.clipcanvas.mcp.http")
    private let lock = NSLock()
    private var listener: NWListener?
    private var storedStatus: LocalMCPServerStatus = .stopped

    var status: LocalMCPServerStatus {
        lock.withLock { storedStatus }
    }

    init(
        repository: ClipboardRepository,
        bindHost: String = "127.0.0.1",
        port: UInt16 = 49_219,
        isEnabled: @escaping () -> Bool
    ) {
        self.repository = repository
        self.router = MCPToolRouter(repository: repository)
        self.bindHost = bindHost
        self.port = port
        self.isEnabled = isEnabled
    }

    func start() throws {
        guard listener == nil else { return }
        guard let address = IPv4Address(bindHost),
              let networkPort = NWEndpoint.Port(rawValue: port) else {
            throw LocalMCPServerError.invalidEndpoint
        }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(
            host: .ipv4(address),
            port: networkPort
        )
        let listener = try NWListener(using: parameters)
        self.listener = listener
        setStatus(.starting)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.setStatus(.running)
            case let .failed(error):
                self.setStatus(.failed(error.localizedDescription))
                self.stop()
            case .cancelled:
                self.setStatus(.stopped)
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
    }

    func stop() {
        lock.withLock {
            listener?.cancel()
            listener = nil
            storedStatus = .stopped
        }
    }

    func handle(
        _ request: LocalHTTPRequest,
        remoteIsLoopback: Bool
    ) async -> LocalHTTPResponse {
        guard isEnabled() else {
            return jsonError(status: 503, message: "MCP is disabled")
        }
        guard remoteIsLoopback else {
            return jsonError(status: 403, message: "Loopback connections only")
        }
        guard isAllowedOrigin(request.header("Origin")) else {
            return jsonError(status: 403, message: "Origin is not allowed")
        }

        if request.method == "GET", request.path == "/health" {
            return json(
                status: 200,
                value: .object([
                    "service": .string("clipcanvas-mcp"),
                    "status": .string("ready"),
                    "protocolVersion": .string(MCPToolRouter.protocolVersion)
                ])
            )
        }
        guard request.path == "/mcp" else {
            return jsonError(status: 404, message: "Not found")
        }
        guard request.method == "POST" else {
            return LocalHTTPResponse(
                statusCode: 405,
                headers: ["Allow": "POST", "Content-Type": "application/json"],
                body: Data(#"{"error":"POST required"}"#.utf8)
            )
        }
        guard let lengthText = request.header("Content-Length"),
              let length = Int(lengthText),
              length >= 0 else {
            return jsonError(status: 411, message: "Content-Length required")
        }
        guard length == request.body.count else {
            return jsonError(status: 400, message: "Content-Length mismatch")
        }
        guard length <= Self.maximumBodyBytes else {
            return jsonError(status: 413, message: "Request exceeds 2 MiB")
        }
        guard request.header("Content-Type")?
            .lowercased().hasPrefix("application/json") == true else {
            return jsonError(status: 415, message: "application/json required")
        }
        guard let authorizationHeader = request.header("Authorization"),
              authorizationHeader.hasPrefix("Bearer "),
              let authorization = try? repository.authorize(
                  token: String(authorizationHeader.dropFirst("Bearer ".count))
              ) else {
            return LocalHTTPResponse(
                statusCode: 401,
                headers: [
                    "Content-Type": "application/json",
                    "WWW-Authenticate": "Bearer"
                ],
                body: Data(#"{"error":"Valid bearer token required"}"#.utf8)
            )
        }
        do {
            let request = try JSONDecoder().decode(MCPRequest.self, from: request.body)
            let response = await router.handle(
                request: request,
                authorization: authorization
            )
            let data = try JSONEncoder().encode(response)
            return LocalHTTPResponse(
                statusCode: 200,
                headers: [
                    "Content-Type": "application/json",
                    "MCP-Protocol-Version": MCPToolRouter.protocolVersion
                ],
                body: data
            )
        } catch {
            return jsonError(status: 400, message: "Invalid JSON-RPC request")
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            if case .ready = state, let connection {
                self?.receive(on: connection, accumulated: Data())
            } else if case .failed = state {
                connection?.cancel()
            }
        }
        connection.start(queue: queue)
    }

    private func receive(on connection: NWConnection, accumulated: Data) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 64 * 1_024
        ) { [weak self] content, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var data = accumulated
            if let content { data.append(content) }
            if data.count > Self.maximumBodyBytes + 32 * 1_024 {
                self.send(
                    self.jsonError(status: 413, message: "Request exceeds 2 MiB"),
                    on: connection
                )
                return
            }
            if let request = try? LocalHTTPRequest.parse(data),
               let lengthText = request.header("Content-Length"),
               let length = Int(lengthText),
               request.body.count >= length {
                let remoteIsLoopback = Self.isLoopback(connection.endpoint)
                Task {
                    let response = await self.handle(
                        LocalHTTPRequest(
                            method: request.method,
                            path: request.path,
                            headers: request.headers,
                            body: Data(request.body.prefix(length))
                        ),
                        remoteIsLoopback: remoteIsLoopback
                    )
                    self.send(response, on: connection)
                }
            } else if isComplete || error != nil {
                self.send(
                    self.jsonError(status: 400, message: "Malformed HTTP request"),
                    on: connection
                )
            } else {
                self.receive(on: connection, accumulated: data)
            }
        }
    }

    private func send(_ response: LocalHTTPResponse, on connection: NWConnection) {
        connection.send(
            content: response.wireData,
            completion: .contentProcessed { _ in connection.cancel() }
        )
    }

    private func isAllowedOrigin(_ value: String?) -> Bool {
        guard let value else { return true }
        guard let url = URL(string: value),
              let host = url.host?.lowercased() else {
            return false
        }
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    private static func isLoopback(_ endpoint: NWEndpoint) -> Bool {
        guard case let .hostPort(host, _) = endpoint else { return false }
        switch host {
        case let .ipv4(address):
            return address == IPv4Address("127.0.0.1")
        case let .ipv6(address):
            return address == IPv6Address("::1")
        case let .name(name, _):
            return name.lowercased() == "localhost"
        @unknown default:
            return false
        }
    }

    private func json(status: Int, value: JSONValue) -> LocalHTTPResponse {
        let data = (try? JSONEncoder().encode(value)) ?? Data("{}".utf8)
        return LocalHTTPResponse(
            statusCode: status,
            headers: ["Content-Type": "application/json"],
            body: data
        )
    }

    private func jsonError(status: Int, message: String) -> LocalHTTPResponse {
        json(status: status, value: .object(["error": .string(message)]))
    }

    private func setStatus(_ status: LocalMCPServerStatus) {
        lock.withLock { storedStatus = status }
    }
}

enum LocalMCPServerError: Error {
    case invalidEndpoint
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
