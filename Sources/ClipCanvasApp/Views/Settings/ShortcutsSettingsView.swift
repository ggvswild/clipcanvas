import ClipCanvasCore
import SwiftUI

struct ShortcutsSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var validationMessage: String?

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: SettingsLayoutMetrics.standard.sectionSpacing
        ) {
            SettingsCard {
                shortcutRow(.activate)
            }

            SettingsCard {
                shortcutRow(.nextPinboard)
                Divider()
                shortcutRow(.previousPinboard)
            }

            SettingsCard {
                SettingsRow {
                    Text("shortcuts.quick_paste")
                } trailing: {
                    Text("⌘ + 1…9")
                        .foregroundStyle(.secondary)
                }
                Divider()
                SettingsRow {
                    Text("shortcuts.plain_mode")
                } trailing: {
                    Text("⇧ Shift")
                        .foregroundStyle(.secondary)
                }
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("shortcuts.reset") {
                    settings.resetShortcuts()
                    validationMessage = nil
                }
            }
        }
    }

    private func shortcutRow(_ action: ShortcutAction) -> some View {
        SettingsRow {
            Text(String(localized: action.titleKey))
        } trailing: {
            ShortcutRecorderButton(
                shortcut: settings.shortcuts[action],
                onCapture: { shortcut in
                    let result = ShortcutValidator.validate(
                        action: action,
                        shortcut: shortcut,
                        existing: settings.shortcuts
                    )
                    switch result {
                    case .valid:
                        settings.shortcuts[action] = shortcut
                        validationMessage = nil
                    case .missingModifier:
                        validationMessage = String(localized: "shortcuts.error_modifier")
                    case let .conflictsWith(conflict):
                        validationMessage = String(
                            format: String(localized: "shortcuts.error_conflict %@"),
                            String(localized: conflict.titleKey)
                        )
                    }
                },
                onClear: {
                    settings.clearShortcut(action)
                    validationMessage = nil
                }
            )
        }
    }
}

private extension ShortcutAction {
    var titleKey: String.LocalizationValue {
        switch self {
        case .activate: "shortcuts.activate"
        case .previousPinboard: "shortcuts.previous_pinboard"
        case .nextPinboard: "shortcuts.next_pinboard"
        }
    }
}
