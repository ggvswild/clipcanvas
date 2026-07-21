import SwiftUI

struct SettingsRootView: View {
    typealias Section = SettingsSection

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var navigation: SettingsNavigationCoordinator

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: selectionBinding) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
                    .padding(.vertical, 5)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 235)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    SettingsPetView(
                        kind: settings.selectedPet,
                        itemCount: model.items.count,
                        isCapturePaused: model.isCapturePaused
                    )
                    Label("settings.local_only", systemImage: "externaldrive.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        } detail: {
            detailView
                .navigationTitle(navigation.selection?.title ?? Section.general.title)
        }
        .frame(
            width: SettingsLayoutMetrics.standard.windowWidth,
            height: SettingsLayoutMetrics.standard.windowHeight
        )
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var detailView: some View {
        let section = navigation.selection ?? .general
        if section == .pinboards {
            PinboardsSettingsView()
                .frame(
                    maxWidth: SettingsLayoutMetrics.standard.contentWidth,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .padding(SettingsLayoutMetrics.standard.pagePadding)
        } else {
            ScrollView {
                settingsContent(for: section)
                    .frame(
                        maxWidth: SettingsLayoutMetrics.standard.contentWidth,
                        alignment: .topLeading
                    )
                    .padding(SettingsLayoutMetrics.standard.pagePadding)
            }
        }
    }

    private var selectionBinding: Binding<Section?> {
        Binding(
            get: { navigation.selection },
            set: { selection in
                if let selection {
                    navigation.select(selection)
                }
            }
        )
    }

    @ViewBuilder
    private func settingsContent(for section: Section) -> some View {
        switch section {
        case .general:
            GeneralSettingsView()
        case .pinboards:
            EmptyView()
        case .pets:
            PetsSettingsView()
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
}

struct SettingsLayoutMetrics: Equatable {
    static let standard = SettingsLayoutMetrics(
        spacingUnit: 4,
        windowWidth: 900,
        windowHeight: 650,
        contentWidth: 620,
        pagePadding: 28,
        sectionSpacing: 24,
        sectionTitleSpacing: 8,
        cardHorizontalPadding: 20,
        rowVerticalPadding: 12,
        columnSpacing: 16,
        trailingColumnWidth: 192
    )

    let spacingUnit: CGFloat
    let windowWidth: CGFloat
    let windowHeight: CGFloat
    let contentWidth: CGFloat
    let pagePadding: CGFloat
    let sectionSpacing: CGFloat
    let sectionTitleSpacing: CGFloat
    let cardHorizontalPadding: CGFloat
    let rowVerticalPadding: CGFloat
    let columnSpacing: CGFloat
    let trailingColumnWidth: CGFloat
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SettingsLayoutMetrics.standard.cardHorizontalPadding)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
    }
}

struct SettingsRow<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(
        @ViewBuilder _ leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: SettingsLayoutMetrics.standard.columnSpacing) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
                .frame(
                    width: SettingsLayoutMetrics.standard.trailingColumnWidth,
                    alignment: .trailing
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SettingsLayoutMetrics.standard.rowVerticalPadding)
    }
}

struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey?
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow {
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
        } trailing: {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}
