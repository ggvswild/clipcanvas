import AppKit
import ClipCanvasCore
import SwiftUI
import UniformTypeIdentifiers

struct PrivacySettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var selectedApplicationID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard {
                SettingsToggleRow(
                    title: "privacy.screen_sharing",
                    description: "privacy.screen_sharing.description",
                    isOn: $settings.showDuringScreenSharing
                )
                Divider()
                SettingsToggleRow(
                    title: "privacy.link_previews",
                    description: "privacy.link_previews.description",
                    isOn: $settings.generateLinkPreviews
                )
            }

            SettingsCard {
                SettingsToggleRow(
                    title: "privacy.confidential",
                    description: "privacy.confidential.description",
                    isOn: $settings.ignoreConfidential
                )
                Divider()
                SettingsToggleRow(
                    title: "privacy.transient",
                    description: "privacy.transient.description",
                    isOn: $settings.ignoreTransient
                )
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("privacy.ignore_apps")
                    .font(.headline)
                Text("privacy.ignore_apps.description")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                SettingsCard {
                    List(settings.ignoredApplications, selection: $selectedApplicationID) { application in
                        HStack(spacing: 10) {
                            applicationIcon(application)
                            Text(application.name)
                            Spacer()
                            Text(application.bundleID)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .tag(application.bundleID)
                    }
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)

                    Divider()
                    HStack(spacing: 14) {
                        Button {
                            addApplication()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        Button {
                            removeSelectedApplication()
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedApplicationID == nil)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
            }

            Label("privacy.best_effort", systemImage: "shield.lefthalf.filled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func applicationIcon(_ application: IgnoredApplication) -> some View {
        if let path = application.path {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "app.fill")
                .frame(width: 28, height: 28)
        }
    }

    private func addApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier else {
                continue
            }
            settings.addIgnoredApplication(
                IgnoredApplication(
                    bundleID: bundleID,
                    name: bundle.object(
                        forInfoDictionaryKey: "CFBundleDisplayName"
                    ) as? String ?? url.deletingPathExtension().lastPathComponent,
                    path: url.path
                )
            )
        }
    }

    private func removeSelectedApplication() {
        guard let selectedApplicationID,
              let application = settings.ignoredApplications.first(
                where: { $0.bundleID == selectedApplicationID }
              ) else {
            return
        }
        settings.removeIgnoredApplication(application)
        self.selectedApplicationID = nil
    }
}
