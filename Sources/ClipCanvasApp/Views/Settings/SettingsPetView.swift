import SwiftUI

struct SettingsPetLayout: Equatable {
    static let standard = SettingsPetLayout(
        height: 150,
        bubbleWidth: 164,
        characterHeight: 78
    )

    let height: CGFloat
    let bubbleWidth: CGFloat
    let characterHeight: CGFloat
}

struct SettingsPetView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let kind: SettingsPetKind
    let itemCount: Int
    let isCapturePaused: Bool

    @State private var isHovered = false
    @State private var tapCount = 0
    @State private var isReacting = false

    private var mood: SettingsPetMood {
        SettingsPetBehavior.mood(
            itemCount: itemCount,
            isCapturePaused: isCapturePaused
        )
    }

    private var status: SettingsPetStatus {
        SettingsPetBehavior.status(
            itemCount: itemCount,
            isCapturePaused: isCapturePaused
        )
    }

    private var reaction: SettingsPetReaction {
        SettingsPetBehavior.reaction(forTapCount: tapCount)
    }

    private var bubbleText: String {
        if isReacting {
            switch reaction {
            case .nuzzle:
                return String(localized: "settings.pet.reaction.nuzzle")
            case .sparkle:
                return String(localized: "settings.pet.reaction.sparkle")
            case .peek:
                return String(localized: "settings.pet.reaction.peek")
            case .proud:
                return String(localized: "settings.pet.reaction.proud")
            }
        }

        switch status {
        case .resting:
            return String(localized: "settings.pet.status.resting")
        case .waiting:
            return String(localized: "settings.pet.status.waiting")
        case let .guarding(itemCount):
            return String.localizedStringWithFormat(
                String(localized: "settings.pet.status.guarding"),
                itemCount
            )
        }
    }

    var body: some View {
        Button {
            tapCount += 1
        } label: {
            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 24.0,
                    paused: reduceMotion
                )
            ) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let idleBob = reduceMotion ? 0 : sin(elapsed * 1.45) * 1.35
                let idleSway = reduceMotion ? 0 : sin(elapsed * 0.72) * 1.1
                let blinkPhase = elapsed.truncatingRemainder(dividingBy: 4.4)
                let isBlinking = !reduceMotion && blinkPhase > 4.22

                ZStack {
                    PipHabitat(phase: elapsed, reduceMotion: reduceMotion)

                    PipCardStack()
                        .offset(y: 49)

                    SettingsPetCharacter(
                        kind: kind,
                        mood: mood,
                        isBlinking: isBlinking,
                        isHovered: isHovered,
                        reaction: isReacting ? reaction : nil
                    )
                    .frame(height: SettingsPetLayout.standard.characterHeight)
                    .rotationEffect(.degrees(idleSway))
                    .offset(
                        x: isReacting && reaction == .peek ? 6 : 0,
                        y: 10 + idleBob
                    )

                    if isHovered || isReacting {
                        PipSpeechBubble(text: bubbleText)
                            .frame(width: SettingsPetLayout.standard.bubbleWidth)
                            .offset(y: -52)
                            .transition(
                                .opacity.combined(
                                    with: .scale(scale: 0.94, anchor: .bottom)
                                )
                            )
                    }

                    HStack(spacing: 5) {
                        Circle()
                            .fill(isCapturePaused ? .orange.opacity(0.8) : .green.opacity(0.72))
                            .frame(width: 5, height: 5)
                        Text(kind.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .offset(y: 68)
                }
                .frame(maxWidth: .infinity)
                .frame(height: SettingsPetLayout.standard.height)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            withAnimation(
                reduceMotion ? nil : .easeOut(duration: 0.22)
            ) {
                isHovered = hovered
            }
        }
        .task(id: tapCount) {
            guard tapCount > 0 else { return }
            withAnimation(
                reduceMotion ? nil : .easeOut(duration: 0.18)
            ) {
                isReacting = true
            }
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(
                reduceMotion ? nil : .easeIn(duration: 0.14)
            ) {
                isReacting = false
            }
        }
        .accessibilityLabel(Text("settings.pet.accessibility_label"))
        .accessibilityValue(Text(bubbleText))
        .accessibilityHint(Text("settings.pet.accessibility_hint"))
    }
}

private struct PipHabitat: View {
    let phase: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.2))
                .frame(width: 106, height: 14)
                .offset(y: 54)

            Path { path in
                path.move(to: CGPoint(x: 24, y: 104))
                path.addCurve(
                    to: CGPoint(x: 166, y: 104),
                    control1: CGPoint(x: 62, y: 98),
                    control2: CGPoint(x: 128, y: 110)
                )
            }
            .stroke(.white.opacity(0.055), lineWidth: 1)

            Circle()
                .fill(.cyan.opacity(0.18))
                .frame(width: 4, height: 4)
                .offset(x: -69, y: 19)
                .opacity(particleOpacity(offset: 0))

            Circle()
                .fill(.purple.opacity(0.16))
                .frame(width: 3, height: 3)
                .offset(x: 72, y: 36)
                .opacity(particleOpacity(offset: 1.7))

            RoundedRectangle(cornerRadius: 1.5)
                .fill(.orange.opacity(0.15))
                .frame(width: 5, height: 5)
                .rotationEffect(.degrees(22))
                .offset(x: 64, y: -2)
                .opacity(particleOpacity(offset: 3.2))
        }
    }

    private func particleOpacity(offset: TimeInterval) -> Double {
        guard !reduceMotion else { return 0.5 }
        return 0.35 + ((sin(phase * 0.8 + offset) + 1) * 0.2)
    }
}

private struct PipCardStack: View {
    var body: some View {
        ZStack {
            card(color: .orange, rotation: -7, x: -7, y: 2)
            card(color: .purple, rotation: 5, x: 7, y: -1)
            card(color: .cyan, rotation: -1, x: 0, y: -5)
        }
    }

    private func card(
        color: Color,
        rotation: Double,
        x: CGFloat,
        y: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color.opacity(0.22))
            .frame(width: 56, height: 22)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.16))
                    .frame(width: 24, height: 2)
                    .padding(.leading, 9)
            }
            .rotationEffect(.degrees(rotation))
            .offset(x: x, y: y)
    }
}

struct PipCharacter: View {
    let mood: SettingsPetMood
    let isBlinking: Bool
    let isHovered: Bool
    let reaction: SettingsPetReaction?

    private var eyesAreClosed: Bool {
        mood == .sleepy || isBlinking
    }

    private var bodyScale: CGFloat {
        switch reaction {
        case .sparkle:
            1.04
        case .proud:
            1.06
        default:
            1
        }
    }

    private var bodyRotation: Double {
        reaction == .nuzzle ? -4 : 0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 3)
                .frame(width: 22, height: 30)
                .rotationEffect(.degrees(15))
                .offset(x: 19, y: -30)

            HStack(spacing: 42) {
                PipArm(isRaised: reaction == .proud)
                    .rotationEffect(.degrees(18))
                PipArm(isRaised: reaction == .nuzzle)
                    .rotationEffect(.degrees(-18))
            }
            .offset(y: 7)

            HStack(spacing: 13) {
                Capsule()
                    .fill(.blue.opacity(0.5))
                    .frame(width: 17, height: 7)
                    .rotationEffect(.degrees(7))
                Capsule()
                    .fill(.blue.opacity(0.5))
                    .frame(width: 17, height: 7)
                    .rotationEffect(.degrees(-7))
            }
            .offset(y: 32)

            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(red: 0.24, green: 0.55, blue: 0.78))
                .frame(width: 55, height: 61)
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(.white.opacity(0.17), lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    PipFoldShape()
                        .fill(.white.opacity(0.2))
                        .frame(width: 15, height: 15)
                        .padding(4)
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(.white.opacity(0.28))
                        .frame(width: 22, height: 7)
                        .offset(y: -4)
                }
                .overlay {
                    VStack(spacing: 6) {
                        HStack(spacing: 11) {
                            PipEye(
                                isClosed: eyesAreClosed,
                                pupilOffset: pupilOffset
                            )
                            PipEye(
                                isClosed: eyesAreClosed,
                                pupilOffset: pupilOffset
                            )
                        }

                        PipMouth(mood: mood)
                            .stroke(
                                Color.black.opacity(0.58),
                                style: StrokeStyle(
                                    lineWidth: 1.8,
                                    lineCap: .round
                                )
                            )
                            .frame(width: 13, height: 7)

                        VStack(spacing: 3) {
                            Capsule()
                                .fill(.white.opacity(0.21))
                                .frame(width: 23, height: 2)
                            Capsule()
                                .fill(.white.opacity(0.14))
                                .frame(width: 16, height: 2)
                        }
                    }
                    .offset(y: 2)
                }

            if mood == .sleepy {
                Text("z")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .offset(x: 38, y: -24)
            }

            if reaction == .sparkle {
                Image(systemName: "sparkle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow.opacity(0.82))
                    .offset(x: -39, y: -25)

                Image(systemName: "sparkle")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.cyan.opacity(0.72))
                    .offset(x: 39, y: -9)
            }
        }
        .scaleEffect(bodyScale)
        .rotationEffect(.degrees(bodyRotation))
    }

    private var pupilOffset: CGSize {
        if reaction == .peek {
            return CGSize(width: 1.5, height: 0)
        }
        if isHovered {
            return CGSize(width: 0, height: -0.8)
        }
        return .zero
    }
}

private struct PipArm: View {
    let isRaised: Bool

    var body: some View {
        Capsule()
            .fill(.blue.opacity(0.62))
            .frame(width: 6, height: 24)
            .rotationEffect(.degrees(isRaised ? 64 : 0), anchor: .top)
            .offset(y: isRaised ? -3 : 0)
    }
}

private struct PipEye: View {
    let isClosed: Bool
    let pupilOffset: CGSize

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.black.opacity(0.64))
                .frame(width: 8, height: 10)
                .scaleEffect(y: isClosed ? 0.16 : 1)

            if !isClosed {
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 2.5, height: 2.5)
                    .offset(pupilOffset)
                    .offset(x: -1, y: -2)
            }
        }
        .frame(width: 8, height: 10)
    }
}

private struct PipMouth: Shape {
    let mood: SettingsPetMood

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch mood {
        case .curious:
            path.addEllipse(
                in: CGRect(
                    x: rect.midX - 2,
                    y: rect.midY - 2,
                    width: 4,
                    height: 4
                )
            )
        case .sleepy, .content:
            path.move(to: CGPoint(x: rect.minX + 1, y: rect.midY - 1))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - 1, y: rect.midY - 1),
                control: CGPoint(x: rect.midX, y: rect.maxY)
            )
        }
        return path
    }
}

private struct PipFoldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct PipSpeechBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        }
                }

            PipBubbleTail()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
                .frame(width: 10, height: 6)
        }
        .shadow(color: .black.opacity(0.2), radius: 7, y: 3)
    }
}

private struct PipBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
