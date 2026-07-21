import ClipCanvasCore
import Combine
import Foundation

private enum StoredShortcutAction: String, Codable, Hashable {
    case activate
    case activateStack
    case previousPinboard
    case nextPinboard

    var supportedAction: ShortcutAction? {
        switch self {
        case .activate:
            .activate
        case .activateStack:
            nil
        case .previousPinboard:
            .previousPinboard
        case .nextPinboard:
            .nextPinboard
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private enum Key {
        static let soundEffects = "soundEffects"
        static let pasteStrategy = "pasteStrategy"
        static let alwaysPastePlainText = "alwaysPastePlainText"
        static let retentionPeriod = "retentionPeriod"
        static let showDuringScreenSharing = "showDuringScreenSharing"
        static let generateLinkPreviews = "generateLinkPreviews"
        static let ignoreConfidential = "ignoreConfidential"
        static let ignoreTransient = "ignoreTransient"
        static let ignoredApplications = "ignoredApplications"
        static let shortcuts = "shortcuts"
        static let enableMCP = "enableMCP"
        static let selectedPet = "selectedPet"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Published var soundEffects: Bool {
        didSet { defaults.set(soundEffects, forKey: Key.soundEffects) }
    }
    @Published var pasteStrategy: PasteStrategy {
        didSet { defaults.set(pasteStrategy.rawValue, forKey: Key.pasteStrategy) }
    }
    @Published var alwaysPastePlainText: Bool {
        didSet { defaults.set(alwaysPastePlainText, forKey: Key.alwaysPastePlainText) }
    }
    @Published var retentionPeriod: RetentionPeriod {
        didSet { defaults.set(retentionPeriod.rawValue, forKey: Key.retentionPeriod) }
    }
    @Published var showDuringScreenSharing: Bool {
        didSet { defaults.set(showDuringScreenSharing, forKey: Key.showDuringScreenSharing) }
    }
    @Published var generateLinkPreviews: Bool {
        didSet { defaults.set(generateLinkPreviews, forKey: Key.generateLinkPreviews) }
    }
    @Published var ignoreConfidential: Bool {
        didSet { defaults.set(ignoreConfidential, forKey: Key.ignoreConfidential) }
    }
    @Published var ignoreTransient: Bool {
        didSet { defaults.set(ignoreTransient, forKey: Key.ignoreTransient) }
    }
    @Published var ignoredApplications: [IgnoredApplication] {
        didSet {
            defaults.set(
                try? encoder.encode(ignoredApplications),
                forKey: Key.ignoredApplications
            )
        }
    }
    @Published var shortcuts: [ShortcutAction: KeyboardShortcut] {
        didSet {
            defaults.set(
                try? encoder.encode(shortcuts),
                forKey: Key.shortcuts
            )
        }
    }
    @Published var enableMCP: Bool {
        didSet { defaults.set(enableMCP, forKey: Key.enableMCP) }
    }
    @Published var selectedPet: SettingsPetKind {
        didSet { defaults.set(selectedPet.rawValue, forKey: Key.selectedPet) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        soundEffects = defaults.object(forKey: Key.soundEffects) as? Bool ?? true
        pasteStrategy = defaults.string(forKey: Key.pasteStrategy)
            .flatMap(PasteStrategy.init(rawValue:)) ?? .activeApp
        alwaysPastePlainText = defaults.object(forKey: Key.alwaysPastePlainText) as? Bool ?? false
        retentionPeriod = defaults.string(forKey: Key.retentionPeriod)
            .flatMap(RetentionPeriod.init(rawValue:)) ?? .month
        showDuringScreenSharing = defaults.object(forKey: Key.showDuringScreenSharing) as? Bool ?? false
        generateLinkPreviews = defaults.object(forKey: Key.generateLinkPreviews) as? Bool ?? false
        ignoreConfidential = defaults.object(forKey: Key.ignoreConfidential) as? Bool ?? true
        ignoreTransient = defaults.object(forKey: Key.ignoreTransient) as? Bool ?? true
        enableMCP = defaults.object(forKey: Key.enableMCP) as? Bool ?? false
        selectedPet = defaults.string(forKey: Key.selectedPet)
            .flatMap(SettingsPetKind.init(rawValue:)) ?? .defaultPet

        if let data = defaults.data(forKey: Key.ignoredApplications),
           let decoded = try? decoder.decode([IgnoredApplication].self, from: data) {
            ignoredApplications = decoded
        } else {
            ignoredApplications = [
                IgnoredApplication(
                    bundleID: "com.apple.keychainaccess",
                    name: "Keychain Access"
                ),
                IgnoredApplication(
                    bundleID: "com.apple.Passwords",
                    name: "Passwords"
                )
            ]
        }

        if let data = defaults.data(forKey: Key.shortcuts),
           let decoded = try? decoder.decode(
               [StoredShortcutAction: KeyboardShortcut].self,
               from: data
           ) {
            shortcuts = decoded.reduce(into: [:]) { result, entry in
                guard let action = entry.key.supportedAction else {
                    return
                }
                result[action] = entry.value
            }
            defaults.set(
                try? encoder.encode(shortcuts),
                forKey: Key.shortcuts
            )
        } else {
            shortcuts = ShortcutAction.defaultShortcuts
        }
    }

    var privacyConfiguration: PrivacyConfiguration {
        PrivacyConfiguration(
            ignoreConfidential: ignoreConfidential,
            ignoreTransient: ignoreTransient,
            ignoredBundleIDs: Set(ignoredApplications.map(\.bundleID))
        )
    }

    func resetShortcuts() {
        shortcuts = ShortcutAction.defaultShortcuts
    }

    func clearShortcut(_ action: ShortcutAction) {
        shortcuts.removeValue(forKey: action)
    }

    func addIgnoredApplication(_ application: IgnoredApplication) {
        guard !ignoredApplications.contains(where: { $0.bundleID == application.bundleID }) else {
            return
        }
        ignoredApplications.append(application)
    }

    func removeIgnoredApplication(_ application: IgnoredApplication) {
        ignoredApplications.removeAll(where: { $0.bundleID == application.bundleID })
    }
}
