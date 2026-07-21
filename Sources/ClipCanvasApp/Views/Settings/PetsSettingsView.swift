import SwiftUI

struct PetsSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("settings.pets.title")
                    .font(.title2.weight(.semibold))
                Text("settings.pets.description")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            selectedPetPreview

            VStack(alignment: .leading, spacing: 10) {
                Text("settings.pets.choose")
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(SettingsPetKind.allCases) { kind in
                        petOption(kind)
                    }
                }
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: settings.selectedPet
        )
    }

    private var selectedPetPreview: some View {
        SettingsCard {
            HStack(spacing: 20) {
                SettingsPetView(
                    kind: settings.selectedPet,
                    itemCount: model.items.count,
                    isCapturePaused: model.isCapturePaused
                )
                .frame(width: 220)

                VStack(alignment: .leading, spacing: 7) {
                    Text(settings.selectedPet.title)
                        .font(.title3.weight(.semibold))

                    Text(settings.selectedPet.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Label("settings.pets.selected", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(settings.selectedPet.accentColor)
                        .padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 5)
        }
    }

    private func petOption(_ kind: SettingsPetKind) -> some View {
        let isSelected = settings.selectedPet == kind

        return Button {
            settings.selectedPet = kind
        } label: {
            HStack(spacing: 10) {
                SettingsPetThumbnail(kind: kind)
                    .frame(width: 72, height: 74)

                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(kind.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        isSelected ? kind.accentColor : Color.secondary.opacity(0.35)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        isSelected
                            ? kind.accentColor.opacity(0.13)
                            : Color.white.opacity(0.045)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        isSelected
                            ? kind.accentColor.opacity(0.46)
                            : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.title)
        .accessibilityValue(
            Text(isSelected ? "settings.pets.selected" : "settings.pets.not_selected")
        )
    }
}
