import SwiftUI

@main
struct ClipCanvasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var mcpService = MCPService.shared
    @StateObject private var settingsNavigation = SettingsNavigationCoordinator.shared

    var body: some Scene {
        Settings {
            SettingsRootView()
                .environmentObject(model)
                .environmentObject(settings)
                .environmentObject(mcpService)
                .environmentObject(settingsNavigation)
        }
    }
}
