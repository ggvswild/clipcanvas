import AppKit
import ClipCanvasCore
import Combine
import Foundation

@MainActor
final class MCPService: ObservableObject {
    static let shared = MCPService()

    @Published private(set) var status: LocalMCPServerStatus = .stopped
    @Published private(set) var clients: [AuthorizedClient] = []
    @Published private(set) var auditEvents: [MCPAuditEvent] = []
    @Published var errorMessage: String?

    private var repository: ClipboardRepository?
    private var server: LocalMCPServer?
    private var statusRefreshTask: Task<Void, Never>?
    private let enabledState = EnabledState()

    func configure(repository: ClipboardRepository, enabled: Bool) {
        self.repository = repository
        enabledState.value = enabled
        server = LocalMCPServer(
            repository: repository,
            isEnabled: { [enabledState] in enabledState.value }
        )
        refresh()
        setEnabled(enabled)
    }

    func setEnabled(_ enabled: Bool) {
        enabledState.value = enabled
        guard let server else { return }
        if enabled {
            do {
                try server.start()
                status = server.status
                scheduleStatusRefresh()
                errorMessage = nil
            } catch {
                status = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        } else {
            server.stop()
            status = .stopped
        }
    }

    @discardableResult
    func authorizeClient(
        name: String,
        scopes: Set<MCPAuthorizationScope>
    ) throws -> IssuedMCPToken {
        guard let repository else {
            throw MCPServiceError.notConfigured
        }
        let issued = try repository.createAuthorizedClient(
            displayName: name,
            scopes: scopes
        )
        refresh()
        return issued
    }

    func revoke(_ client: AuthorizedClient) {
        do {
            try repository?.revokeAuthorizedClient(id: client.id)
            refresh()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() {
        guard let repository else { return }
        do {
            clients = try repository.listAuthorizedClients()
            auditEvents = try repository.listAuditEvents(limit: 50)
            if let server { status = server.status }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clientConfiguration(for issued: IssuedMCPToken) -> String {
        let command = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/clipcanvas-mcp").path
        let object: [String: Any] = [
            "mcpServers": [
                "clipcanvas": [
                    "command": command,
                    "env": ["CLIPCANVAS_TOKEN": issued.token]
                ]
            ]
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return "{}"
        }
        return String(decoding: data, as: UTF8.self)
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func scheduleStatusRefresh() {
        statusRefreshTask?.cancel()
        statusRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}

private final class EnabledState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = false

    var value: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            storedValue = newValue
            lock.unlock()
        }
    }
}

enum MCPServiceError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        "MCP service is not configured"
    }
}
