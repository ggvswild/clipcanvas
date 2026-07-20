import Combine
import ServiceManagement

enum LoginItemRegistrationStatus {
    case notRegistered
    case enabled
    case requiresApproval
    case unavailable
}

@MainActor
protocol LoginItemControlling {
    var status: LoginItemRegistrationStatus { get }

    func register() throws
    func unregister() throws
    func openSystemSettings()
}

@MainActor
struct SystemLoginItemController: LoginItemControlling {
    var status: LoginItemRegistrationStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
final class LoginItemService: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published var errorMessage: String?

    private let controller: any LoginItemControlling

    init(controller: any LoginItemControlling = SystemLoginItemController()) {
        self.controller = controller
        refresh()
    }

    func refresh() {
        let status = controller.status
        isEnabled = status == .enabled || status == .requiresApproval
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try controller.register()
            } else {
                try controller.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() {
        controller.openSystemSettings()
    }
}
