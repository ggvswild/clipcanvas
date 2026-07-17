import ClipCanvasCore
import SwiftUI

struct MCPSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var service: MCPService
    @State private var isAddingClient = false
    @State private var issuedToken: IssuedMCPToken?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard {
                SettingsToggleRow(
                    title: "mcp.enable",
                    description: "mcp.enable.description",
                    isOn: $settings.enableMCP
                )
                Divider()
                HStack {
                    Label("mcp.endpoint", systemImage: "network")
                    Spacer()
                    Text("127.0.0.1:49219")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                    statusBadge
                }
                .padding(.vertical, 13)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("mcp.authorized_clients")
                        .font(.headline)
                    Spacer()
                    Button {
                        isAddingClient = true
                    } label: {
                        Label("mcp.add_client", systemImage: "plus")
                    }
                    .disabled(!settings.enableMCP)
                }
                SettingsCard {
                    if service.clients.isEmpty {
                        ContentUnavailableView(
                            "mcp.no_clients",
                            systemImage: "person.crop.circle.badge.questionmark",
                            description: Text("mcp.no_clients.description")
                        )
                        .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        ForEach(Array(service.clients.enumerated()), id: \.element.id) { index, client in
                            clientRow(client)
                            if index < service.clients.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("mcp.recent_activity")
                        .font(.headline)
                    Spacer()
                    Button {
                        service.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
                SettingsCard {
                    if service.auditEvents.isEmpty {
                        Text("mcp.no_activity")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 70)
                    } else {
                        ForEach(Array(service.auditEvents.prefix(8).enumerated()), id: \.element.id) {
                            index, event in
                            HStack(spacing: 10) {
                                Image(systemName: event.outcome == .success
                                    ? "checkmark.circle.fill"
                                    : "exclamationmark.triangle.fill")
                                    .foregroundStyle(event.outcome == .success ? .green : .orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.method)
                                        .font(.system(.callout, design: .monospaced))
                                    Text(event.createdAt, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(event.outcome.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 9)
                            if index < min(service.auditEvents.count, 8) - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }

            Label("mcp.authorization_hint", systemImage: "lock.shield.fill")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let error = service.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .onAppear { service.refresh() }
        .sheet(isPresented: $isAddingClient) {
            AddMCPClientView { issued in
                issuedToken = issued
                isAddingClient = false
            }
            .environmentObject(service)
        }
        .sheet(item: $issuedToken) { issued in
            IssuedMCPTokenView(issued: issued)
                .environmentObject(service)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let tuple: (LocalizedStringKey, Color) = switch service.status {
        case .running: ("mcp.status.running", .green)
        case .starting: ("mcp.status.starting", .orange)
        case .failed: ("mcp.status.failed", .red)
        case .stopped: ("mcp.status.stopped", .secondary)
        }
        HStack(spacing: 5) {
            Circle()
                .fill(tuple.1)
                .frame(width: 7, height: 7)
            Text(tuple.0)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func clientRow(_ client: AuthorizedClient) -> some View {
        HStack(spacing: 12) {
            Image(systemName: client.isActive ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark")
                .font(.title3)
                .foregroundStyle(client.isActive ? .cyan : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(client.displayName)
                        .font(.body.weight(.medium))
                    if !client.isActive {
                        Text("mcp.revoked")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.2), in: Capsule())
                    }
                }
                Text(client.scopes.map(\.rawValue).sorted().joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if client.isActive {
                Button("mcp.revoke", role: .destructive) {
                    service.revoke(client)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 12)
    }
}

private struct AddMCPClientView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var service: MCPService
    @State private var name = ""
    @State private var scopes: Set<MCPAuthorizationScope> = [.read]
    @State private var errorMessage: String?
    let onIssue: (IssuedMCPToken) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("mcp.add_client")
                .font(.title2.bold())
            TextField("mcp.client_name", text: $name)
                .textFieldStyle(.roundedBorder)

            Text("mcp.permissions")
                .font(.headline)
            ForEach(MCPAuthorizationScope.allCases, id: \.self) { scope in
                Toggle(isOn: scopeBinding(scope)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(scopeTitle(scope))
                        Text(scopeDescription(scope))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("common.cancel") { dismiss() }
                Button("mcp.authorize") { issue() }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || scopes.isEmpty
                    )
            }
        }
        .padding(26)
        .frame(width: 460)
    }

    private func scopeBinding(_ scope: MCPAuthorizationScope) -> Binding<Bool> {
        Binding(
            get: { scopes.contains(scope) },
            set: { enabled in
                if enabled { scopes.insert(scope) } else { scopes.remove(scope) }
            }
        )
    }

    private func scopeTitle(_ scope: MCPAuthorizationScope) -> LocalizedStringKey {
        switch scope {
        case .read: "mcp.scope.read"
        case .write: "mcp.scope.write"
        case .manage: "mcp.scope.manage"
        }
    }

    private func scopeDescription(_ scope: MCPAuthorizationScope) -> LocalizedStringKey {
        switch scope {
        case .read: "mcp.scope.read.description"
        case .write: "mcp.scope.write.description"
        case .manage: "mcp.scope.manage.description"
        }
    }

    private func issue() {
        do {
            onIssue(try service.authorizeClient(name: name, scopes: scopes))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct IssuedMCPTokenView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var service: MCPService
    let issued: IssuedMCPToken

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("mcp.authorization_created", systemImage: "checkmark.shield.fill")
                .font(.title2.bold())
                .foregroundStyle(.green)
            Text("mcp.token_once")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 7) {
                Text("mcp.token")
                    .font(.headline)
                copyField(issued.token)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("mcp.client_config")
                    .font(.headline)
                ScrollView([.horizontal, .vertical]) {
                    Text(service.clientConfiguration(for: issued))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(height: 190)
                .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
                Button {
                    service.copy(service.clientConfiguration(for: issued))
                } label: {
                    Label("mcp.copy_config", systemImage: "doc.on.doc")
                }
            }

            HStack {
                Spacer()
                Button("mcp.done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(26)
        .frame(width: 570)
    }

    private func copyField(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .textSelection(.enabled)
            Spacer()
            Button {
                service.copy(text)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 9))
    }
}

extension IssuedMCPToken: Identifiable {
    public var id: UUID { client.id }
}
