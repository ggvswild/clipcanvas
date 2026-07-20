import ClipCanvasCore
import SwiftUI

struct ShortcutsSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard {
                shortcutRow(.activate)
                Divider()
                shortcutRow(.activateStack)
            }

            SettingsCard {
                shortcutRow(.nextPinboard)
                Divider()
                shortcutRow(.previousPinboard)
            }

            SettingsCard {
                HStack {
                    Text("shortcuts.quick_paste")
                    Spacer()
                    Text("⌘ + 1…9")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 14)
                Divider()
                HStack {
                    Text("shortcuts.plain_mode")
                    Spacer()
                    Text("⇧ Shift")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 14)
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
        HStack {
            Text(String(localized: action.titleKey))
            Spacer()
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
        .padding(.vertical, 11)
    }
}

private extension ShortcutAction {
    var titleKey: String.LocalizationValue {
        switch self {
        case .activate: "shortcuts.activate"
        case .activateStack: "shortcuts.activate_stack"
        case .previousPinboard: "shortcuts.previous_pinboard"
        case .nextPinboard: "shortcuts.next_pinboard"
        }
    }
}
