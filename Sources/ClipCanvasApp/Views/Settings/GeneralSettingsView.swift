import ApplicationServices
import ClipCanvasCore
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var model: AppModel
    @StateObject private var loginItem = LoginItemService()
    @State private var eraseConfirmation = false

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: SettingsLayoutMetrics.standard.sectionSpacing
        ) {
            SettingsCard {
                SettingsToggleRow(
                    title: "general.open_login",
                    description: "general.open_login.description",
                    isOn: Binding(
                        get: { loginItem.isEnabled },
                        set: { loginItem.setEnabled($0) }
                    )
                )
                Divider()
                SettingsToggleRow(
                    title: "general.sound",
                    description: nil,
                    isOn: $settings.soundEffects
                )
            }

            VStack(
                alignment: .leading,
                spacing: SettingsLayoutMetrics.standard.sectionTitleSpacing
            ) {
                Text("general.paste_items")
                    .font(.headline)
                SettingsCard {
                    Picker("", selection: $settings.pasteStrategy) {
                        VStack(alignment: .leading) {
                            Text("general.to_active")
                            Text("general.to_active.description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(PasteStrategy.activeApp)
                        VStack(alignment: .leading) {
                            Text("general.to_clipboard")
                            Text("general.to_clipboard.description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(PasteStrategy.clipboardOnly)
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    Divider()
                    SettingsToggleRow(
                        title: "general.always_plain",
                        description: nil,
                        isOn: $settings.alwaysPastePlainText
                    )
                }
            }

            VStack(
                alignment: .leading,
                spacing: SettingsLayoutMetrics.standard.sectionTitleSpacing
            ) {
                Text("general.keep_history")
                    .font(.headline)
                SettingsCard {
                    Picker("", selection: $settings.retentionPeriod) {
                        Text("retention.day").tag(RetentionPeriod.day)
                        Text("retention.week").tag(RetentionPeriod.week)
                        Text("retention.month").tag(RetentionPeriod.month)
                        Text("retention.year").tag(RetentionPeriod.year)
                        Text("retention.forever").tag(RetentionPeriod.forever)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    Divider()
                    SettingsRow {
                        Text("general.erase_description")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } trailing: {
                        Button("general.erase", role: .destructive) {
                            eraseConfirmation = true
                        }
                    }
                }
            }

            SettingsCard {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("general.accessibility")
                            .font(.body.weight(.medium))
                        Text("general.accessibility.description")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } trailing: {
                    Button("general.request_accessibility") {
                        let options = [
                            "AXTrustedCheckOptionPrompt": true
                        ] as CFDictionary
                        AXIsProcessTrustedWithOptions(options)
                    }
                }
            }
        }
        .alert("general.erase", isPresented: $eraseConfirmation) {
            Button("common.cancel", role: .cancel) {}
            Button("general.erase_keep_pins", role: .destructive) {
                model.eraseHistory(preservingPinned: true)
            }
            Button("general.erase_all", role: .destructive) {
                model.eraseHistory(preservingPinned: false)
            }
        } message: {
            Text("general.erase_confirmation")
        }
    }
}
