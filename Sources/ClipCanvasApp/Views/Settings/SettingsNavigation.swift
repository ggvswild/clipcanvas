import Combine
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case pinboards
    case pets
    case privacy
    case shortcuts
    case mcp
    case about

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .general: "settings.general"
        case .pinboards: "settings.pinboards"
        case .pets: "settings.pets"
        case .privacy: "settings.privacy"
        case .shortcuts: "settings.shortcuts"
        case .mcp: "settings.mcp"
        case .about: "settings.about"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .pinboards: "square.grid.2x2"
        case .pets: "pawprint"
        case .privacy: "hand.raised"
        case .shortcuts: "keyboard"
        case .mcp: "point.3.connected.trianglepath.dotted"
        case .about: "info.circle"
        }
    }
}

@MainActor
final class SettingsNavigationCoordinator: ObservableObject {
    static let shared = SettingsNavigationCoordinator()

    @Published private(set) var selection: SettingsSection?

    init(selection: SettingsSection? = .general) {
        self.selection = selection
    }

    func select(_ section: SettingsSection) {
        selection = section
    }
}
