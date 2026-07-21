import SwiftUI

enum SettingsPetMotif: Equatable {
    case clipboard
    case forestTime
    case wishStar
    case cloud
    case pixel
    case ember
}

enum SettingsPetKind: String, CaseIterable, Codable, Identifiable {
    case pip
    case sprig
    case nova
    case mallow
    case byte
    case ember

    static let defaultPet: SettingsPetKind = .pip

    var id: String { rawValue }

    var motif: SettingsPetMotif {
        switch self {
        case .pip: .clipboard
        case .sprig: .forestTime
        case .nova: .wishStar
        case .mallow: .cloud
        case .byte: .pixel
        case .ember: .ember
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .pip: "settings.pets.pip.name"
        case .sprig: "settings.pets.sprig.name"
        case .nova: "settings.pets.nova.name"
        case .mallow: "settings.pets.mallow.name"
        case .byte: "settings.pets.byte.name"
        case .ember: "settings.pets.ember.name"
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .pip: "settings.pets.pip.description"
        case .sprig: "settings.pets.sprig.description"
        case .nova: "settings.pets.nova.description"
        case .mallow: "settings.pets.mallow.description"
        case .byte: "settings.pets.byte.description"
        case .ember: "settings.pets.ember.description"
        }
    }

    var accentColor: Color {
        switch self {
        case .pip:
            Color(red: 0.24, green: 0.55, blue: 0.78)
        case .sprig:
            Color(red: 0.29, green: 0.72, blue: 0.55)
        case .nova:
            Color(red: 0.96, green: 0.76, blue: 0.31)
        case .mallow:
            Color(red: 0.76, green: 0.55, blue: 0.86)
        case .byte:
            Color(red: 0.34, green: 0.62, blue: 0.96)
        case .ember:
            Color(red: 0.95, green: 0.42, blue: 0.23)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .pip:
            .cyan
        case .sprig:
            Color(red: 0.68, green: 0.91, blue: 0.48)
        case .nova:
            Color(red: 0.55, green: 0.76, blue: 0.95)
        case .mallow:
            Color(red: 0.96, green: 0.65, blue: 0.78)
        case .byte:
            Color(red: 0.41, green: 0.93, blue: 0.91)
        case .ember:
            Color(red: 1, green: 0.73, blue: 0.28)
        }
    }
}
