import SwiftUI

struct MCPSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard {
                SettingsToggleRow(
                    title: "mcp.enable",
                    description: "mcp.enable.description",
                    isOn: $settings.enableMCP
                )
            }
            Label("mcp.authorization_hint", systemImage: "lock.shield.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
