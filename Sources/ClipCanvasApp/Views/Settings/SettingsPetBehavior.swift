enum SettingsPetMood: Equatable {
    case sleepy
    case curious
    case content
}

enum SettingsPetStatus: Equatable {
    case resting
    case waiting
    case guarding(itemCount: Int)
}

enum SettingsPetReaction: CaseIterable, Equatable {
    case nuzzle
    case sparkle
    case peek
    case proud
}

enum SettingsPetBehavior {
    static func status(
        itemCount: Int,
        isCapturePaused: Bool
    ) -> SettingsPetStatus {
        if isCapturePaused {
            return .resting
        }
        if itemCount == 0 {
            return .waiting
        }
        return .guarding(itemCount: itemCount)
    }

    static func mood(
        itemCount: Int,
        isCapturePaused: Bool
    ) -> SettingsPetMood {
        switch status(itemCount: itemCount, isCapturePaused: isCapturePaused) {
        case .resting:
            .sleepy
        case .waiting:
            .curious
        case .guarding:
            .content
        }
    }

    static func reaction(forTapCount tapCount: Int) -> SettingsPetReaction {
        let reactions = SettingsPetReaction.allCases
        let index = max(0, tapCount - 1) % reactions.count
        return reactions[index]
    }
}
