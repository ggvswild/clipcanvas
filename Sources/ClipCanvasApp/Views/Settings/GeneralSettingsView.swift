import ApplicationServices
import ClipCanvasCore
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var model: AppModel
    @StateObject private var loginItem = LoginItemService()
    @State private var eraseConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
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

            VStack(alignment: .leading, spacing: 9) {
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
                    .padding(.vertical, 12)
                    Divider()
                    Toggle("general.always_plain", isOn: $settings.alwaysPastePlainText)
                        .padding(.vertical, 13)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
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
                    .padding(.vertical, 16)
                    Divider()
                    HStack {
                        Text("general.erase_description")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("general.erase", role: .destructive) {
                            eraseConfirmation = true
                        }
                    }
                    .padding(.vertical, 13)
                }
            }

            SettingsCard {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("general.accessibility")
                            .font(.body.weight(.medium))
                        Text("general.accessibility.description")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("general.request_accessibility") {
                        let options = [
                            "AXTrustedCheckOptionPrompt": true
                        ] as CFDictionary
                        AXIsProcessTrustedWithOptions(options)
                    }
                }
                .padding(.vertical, 13)
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
