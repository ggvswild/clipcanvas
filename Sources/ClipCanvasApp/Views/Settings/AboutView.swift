import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 18) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.cyan.gradient)
                    .frame(width: 84, height: 84)
                    .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 5) {
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
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 13)
    }
}
