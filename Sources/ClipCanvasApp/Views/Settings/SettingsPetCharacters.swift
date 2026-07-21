import SwiftUI

struct SettingsPetThumbnail: View {
    let kind: SettingsPetKind

    var body: some View {
        SettingsPetCharacter(
            kind: kind,
            mood: .content,
            isBlinking: false,
            isHovered: false,
            reaction: nil
        )
        .frame(width: 82, height: 82)
        .accessibilityHidden(true)
    }
}

struct SettingsPetCharacter: View {
    let kind: SettingsPetKind
    let mood: SettingsPetMood
    let isBlinking: Bool
    let isHovered: Bool
    let reaction: SettingsPetReaction?

    var body: some View {
        Group {
            if kind == .pip {
                PipCharacter(
                    mood: mood,
                    isBlinking: isBlinking,
                    isHovered: isHovered,
                    reaction: reaction
                )
            } else {
                MotifPetCharacter(
                    kind: kind,
                    mood: mood,
                    isBlinking: isBlinking,
                    isHovered: isHovered,
                    reaction: reaction
                )
            }
        }
    }
}

private struct MotifPetCharacter: View {
    let kind: SettingsPetKind
    let mood: SettingsPetMood
    let isBlinking: Bool
    let isHovered: Bool
    let reaction: SettingsPetReaction?

    private var eyesAreClosed: Bool {
        mood == .sleepy || isBlinking
    }

    var body: some View {
        ZStack {
            rearAccessory
            limbs
            bodySurface
            face
            frontAccessory
            reactionDetails
        }
        .scaleEffect(reaction == .proud ? 1.06 : reaction == .sparkle ? 1.04 : 1)
        .rotationEffect(.degrees(reaction == .nuzzle ? -4 : 0))
    }

    @ViewBuilder
    private var rearAccessory: some View {
        switch kind {
        case .sprig:
            HStack(spacing: 38) {
                PetLeafShape()
                    .fill(kind.secondaryColor.opacity(0.52))
                    .frame(width: 25, height: 40)
                    .rotationEffect(.degrees(-31))
                PetLeafShape()
                    .fill(kind.secondaryColor.opacity(0.52))
                    .frame(width: 25, height: 40)
                    .scaleEffect(x: -1)
                    .rotationEffect(.degrees(31))
            }
            .offset(y: -1)
        case .nova:
            ZStack {
                PetTwinkleShape()
                    .fill(kind.accentColor.opacity(0.3))
                    .frame(width: 82, height: 82)
                HStack(spacing: 37) {
                    Capsule()
                        .fill(kind.secondaryColor.opacity(0.68))
                        .frame(width: 11, height: 38)
                        .rotationEffect(.degrees(34))
                    Capsule()
                        .fill(kind.secondaryColor.opacity(0.68))
                        .frame(width: 11, height: 38)
                        .rotationEffect(.degrees(-34))
                }
                .offset(y: 18)
            }
        case .mallow:
            HStack(spacing: 39) {
                Circle()
                    .fill(kind.secondaryColor.opacity(0.46))
                    .frame(width: 25, height: 25)
                Circle()
                    .fill(kind.secondaryColor.opacity(0.46))
                    .frame(width: 25, height: 25)
            }
            .offset(y: 4)
        case .byte:
            VStack(spacing: 1) {
                Circle()
                    .fill(kind.secondaryColor)
                    .frame(width: 6, height: 6)
                Capsule()
                    .fill(kind.accentColor.opacity(0.8))
                    .frame(width: 3, height: 12)
            }
            .offset(y: -40)
        case .ember:
            HStack(spacing: 43) {
                Circle()
                    .fill(kind.secondaryColor.opacity(0.38))
                    .frame(width: 7, height: 7)
                Circle()
                    .fill(kind.secondaryColor.opacity(0.5))
                    .frame(width: 5, height: 5)
                    .offset(y: -13)
            }
            .offset(y: -17)
        case .pip:
            EmptyView()
        }
    }

    private var limbs: some View {
        ZStack {
            HStack(spacing: kind == .mallow ? 44 : 40) {
                Capsule()
                    .fill(kind.accentColor.opacity(0.62))
                    .frame(width: 7, height: 23)
                    .rotationEffect(.degrees(reaction == .proud ? -58 : 16), anchor: .top)
                Capsule()
                    .fill(kind.accentColor.opacity(0.62))
                    .frame(width: 7, height: 23)
                    .rotationEffect(.degrees(reaction == .nuzzle ? 58 : -16), anchor: .top)
            }
            .offset(y: 6)

            HStack(spacing: 14) {
                Capsule()
                    .fill(kind.accentColor.opacity(0.58))
                    .frame(width: 17, height: 7)
                    .rotationEffect(.degrees(8))
                Capsule()
                    .fill(kind.accentColor.opacity(0.58))
                    .frame(width: 17, height: 7)
                    .rotationEffect(.degrees(-8))
            }
            .offset(y: 32)
        }
    }

    @ViewBuilder
    private var bodySurface: some View {
        switch kind {
        case .sprig:
            Ellipse()
                .fill(kind.accentColor)
                .frame(width: 55, height: 62)
                .overlay {
                    Ellipse()
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
        case .nova:
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(kind.accentColor)
                .frame(width: 58, height: 58)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                }
        case .mallow:
            PetCloudShape()
                .fill(kind.accentColor)
                .frame(width: 67, height: 57)
                .overlay {
                    PetCloudShape()
                        .stroke(.white.opacity(0.17), lineWidth: 1)
                }
        case .byte:
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(kind.accentColor)
                .frame(width: 59, height: 58)
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.black.opacity(0.24))
                        .frame(width: 45, height: 30)
                        .offset(y: -5)
                }
        case .ember:
            PetFlameShape()
                .fill(
                    LinearGradient(
                        colors: [kind.secondaryColor, kind.accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 58, height: 68)
                .overlay {
                    PetFlameShape()
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                }
        case .pip:
            EmptyView()
        }
    }

    private var face: some View {
        VStack(spacing: 6) {
            HStack(spacing: kind == .byte ? 13 : 11) {
                MotifPetEye(
                    isClosed: eyesAreClosed,
                    isPixel: kind == .byte,
                    pupilOffset: pupilOffset
                )
                MotifPetEye(
                    isClosed: eyesAreClosed,
                    isPixel: kind == .byte,
                    pupilOffset: pupilOffset
                )
            }

            MotifPetMouth(mood: mood)
                .stroke(
                    .black.opacity(0.58),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                )
                .frame(width: 13, height: 7)
        }
        .offset(y: kind == .byte ? -4 : 2)
    }

    @ViewBuilder
    private var frontAccessory: some View {
        switch kind {
        case .sprig:
            PetLeafShape()
                .fill(kind.secondaryColor)
                .frame(width: 15, height: 24)
                .rotationEffect(.degrees(13))
                .offset(x: 3, y: -35)
        case .nova:
            PetTwinkleShape()
                .fill(.white.opacity(0.72))
                .frame(width: 17, height: 17)
                .offset(y: -29)
        case .mallow:
            HStack(spacing: 31) {
                Circle()
                    .fill(kind.secondaryColor.opacity(0.78))
                    .frame(width: 7, height: 5)
                Circle()
                    .fill(kind.secondaryColor.opacity(0.78))
                    .frame(width: 7, height: 5)
            }
            .offset(y: 10)
        case .byte:
            HStack(spacing: 46) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(kind.secondaryColor.opacity(0.74))
                    .frame(width: 8, height: 13)
                RoundedRectangle(cornerRadius: 2)
                    .fill(kind.secondaryColor.opacity(0.74))
                    .frame(width: 8, height: 13)
            }
            .offset(y: 13)
        case .ember:
            PetFlameShape()
                .fill(.yellow.opacity(0.24))
                .frame(width: 25, height: 30)
                .offset(y: 17)
        case .pip:
            EmptyView()
        }

        if mood == .sleepy {
            Text("z")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .offset(x: 38, y: -24)
        }
    }

    @ViewBuilder
    private var reactionDetails: some View {
        if reaction == .sparkle {
            Image(systemName: "sparkle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(kind.secondaryColor.opacity(0.9))
                .offset(x: -39, y: -25)

            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(kind.accentColor.opacity(0.82))
                .offset(x: 39, y: -9)
        }
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

private struct MotifPetEye: View {
    let isClosed: Bool
    let isPixel: Bool
    let pupilOffset: CGSize

    var body: some View {
        ZStack {
            if isPixel {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.black.opacity(0.64))
                    .frame(width: 8, height: 10)
                    .scaleEffect(y: isClosed ? 0.16 : 1)
            } else {
                Capsule()
                    .fill(Color.black.opacity(0.64))
                    .frame(width: 8, height: 10)
                    .scaleEffect(y: isClosed ? 0.16 : 1)
            }

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

private struct MotifPetMouth: Shape {
    let mood: SettingsPetMood

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if mood == .curious {
            path.addEllipse(
                in: CGRect(
                    x: rect.midX - 2,
                    y: rect.midY - 2,
                    width: 4,
                    height: 4
                )
            )
        } else {
            path.move(to: CGPoint(x: rect.minX + 1, y: rect.midY - 1))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - 1, y: rect.midY - 1),
                control: CGPoint(x: rect.midX, y: rect.maxY)
            )
        }
        return path
    }
}

private struct PetLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.28),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.72)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.height * 0.72),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.28)
        )
        return path
    }
}

private struct PetTwinkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.width * 0.66, y: rect.height * 0.34)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.width * 0.66, y: rect.height * 0.66)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control: CGPoint(x: rect.width * 0.34, y: rect.height * 0.66)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.width * 0.34, y: rect.height * 0.34)
        )
        return path
    }
}

private struct PetCloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.78))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.24, y: rect.height * 0.35),
            control1: CGPoint(x: rect.minX, y: rect.height * 0.72),
            control2: CGPoint(x: rect.width * 0.02, y: rect.height * 0.38)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.2),
            control1: CGPoint(x: rect.width * 0.29, y: rect.height * 0.04),
            control2: CGPoint(x: rect.width * 0.47, y: rect.height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.37),
            control1: CGPoint(x: rect.width * 0.56, y: rect.minY),
            control2: CGPoint(x: rect.width * 0.78, y: rect.height * 0.05)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.79),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.38),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.72)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.78),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

private struct PetFlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.62),
            control1: CGPoint(x: rect.width * 0.73, y: rect.height * 0.19),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.33)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.9),
            control2: CGPoint(x: rect.width * 0.73, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.height * 0.59),
            control1: CGPoint(x: rect.width * 0.2, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.86)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.36, y: rect.height * 0.19),
            control1: CGPoint(x: rect.minX, y: rect.height * 0.34),
            control2: CGPoint(x: rect.width * 0.24, y: rect.height * 0.33)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.width * 0.43, y: rect.height * 0.09)
        )
        path.closeSubpath()
        return path
    }
}
