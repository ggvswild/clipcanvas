import SwiftUI

struct PanelPetPerchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let kind: SettingsPetKind
    let itemCount: Int
    let isCapturePaused: Bool
    let isActive: Bool

    private var mood: SettingsPetMood {
        SettingsPetBehavior.mood(
            itemCount: itemCount,
            isCapturePaused: isCapturePaused
        )
    }

    var body: some View {
        let layout = PanelPetPerchLayout.standard

        TimelineView(
            .animation(
                minimumInterval: 1.0 / 20.0,
                paused: reduceMotion || !isActive
            )
        ) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let idleBob = reduceMotion || !isActive ? 0 : sin(elapsed * 1.25) * 0.9
            let idleSway = reduceMotion || !isActive ? 0 : sin(elapsed * 0.6) * 0.65
            let blinkPhase = elapsed.truncatingRemainder(dividingBy: 4.8)
            let isBlinking = !reduceMotion && isActive && blinkPhase > 4.62

            ZStack(alignment: .top) {
                SettingsPetCharacter(
                    kind: kind,
                    mood: mood,
                    isBlinking: isBlinking,
                    isHovered: false,
                    reaction: nil
                )
                .frame(width: layout.petWidth, height: layout.petHeight)
                .scaleEffect(0.88)
                .rotationEffect(.degrees(idleSway))
                .offset(
                    y: layout.windowHeight - layout.petHeight - 3 + idleBob
                )
            }
            .frame(
                width: layout.windowWidth,
                height: layout.windowHeight,
                alignment: .top
            )
            .overlay(alignment: .bottom) {
                perch
            }
        }
        .accessibilityHidden(true)
    }

    private var perch: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(kind.accentColor.opacity(0.16))
                .frame(width: 62, height: 9)

            Capsule()
                .fill(.white.opacity(0.15))
                .frame(width: 72, height: 3)
        }
        .frame(height: 9, alignment: .bottom)
    }
}

struct PanelPetHostView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @State private var isHovered = false

    let onOpenSettings: () -> Void

    var body: some View {
        Button(action: onOpenSettings) {
            PanelPetPerchView(
                kind: settings.selectedPet,
                itemCount: model.items.count,
                isCapturePaused: model.isCapturePaused,
                isActive: model.isPanelPresented
            )
            .scaleEffect(isHovered ? 1.025 : 1, anchor: .bottom)
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help(String(localized: "panel.pet.open_settings"))
        .accessibilityLabel(Text("panel.pet.open_settings"))
        .accessibilityHint(Text("panel.pet.open_settings_hint"))
    }
}
