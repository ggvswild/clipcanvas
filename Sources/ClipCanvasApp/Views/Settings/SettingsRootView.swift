import SwiftUI

struct SettingsRootView: View {
    enum Section: String, CaseIterable, Identifiable {
        case general
        case privacy
        case shortcuts
        case mcp
        case about

        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .general: "settings.general"
            case .privacy: "settings.privacy"
            case .shortcuts: "settings.shortcuts"
            case .mcp: "settings.mcp"
            case .about: "settings.about"
            }
        }

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .privacy: "hand.raised"
            case .shortcuts: "keyboard"
            case .mcp: "point.3.connected.trianglepath.dotted"
            case .about: "info.circle"
            }
        }
    }

    @State private var selection: Section? = .general

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
                    .padding(.vertical, 5)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 235)
            .safeAreaInset(edge: .bottom) {
                Label("settings.local_only", systemImage: "externaldrive.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        } detail: {
            ScrollView {
                Group {
                    switch selection ?? .general {
                    case .general:
                        GeneralSettingsView()
                    case .privacy:
                        PrivacySettingsView()
                    case .shortcuts:
                        ShortcutsSettingsView()
                    case .mcp:
                        MCPSettingsView()
                    case .about:
                        AboutView()
                    }
                }
                .padding(28)
                .frame(maxWidth: 620, alignment: .topLeading)
            }
            .navigationTitle(selection?.title ?? Section.general.title)
        }
        .frame(width: 820, height: 650)
        .preferredColorScheme(.dark)
    }
}

struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 18)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
    }
}

struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                if let description {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 13)
    }
}
