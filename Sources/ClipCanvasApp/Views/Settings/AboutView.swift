import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(
            alignment: .leading,
            spacing: SettingsLayoutMetrics.standard.sectionSpacing
        ) {
            HStack(spacing: 20) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text("app.name")
                        .font(.largeTitle.bold())
                    Text("about.tagline")
                        .foregroundStyle(.secondary)
                    Text("about.version")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            SettingsCard {
                aboutRow("about.local", value: "about.local.value")
                Divider()
                aboutRow("about.license", value: "MIT")
                Divider()
                aboutRow("about.platform", value: "macOS 14+")
            }

            Text("about.description")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label("about.no_cloud", systemImage: "checkmark.shield.fill")
                .foregroundStyle(.green)
        }
    }

    private func aboutRow(_ title: LocalizedStringKey, value: LocalizedStringKey) -> some View {
        SettingsRow {
            Text(title)
        } trailing: {
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
