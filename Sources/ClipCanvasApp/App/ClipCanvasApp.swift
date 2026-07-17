import SwiftUI

@main
struct ClipCanvasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        Settings {
            SettingsRootView()
                .environmentObject(model)
                .environmentObject(settings)
        }
    }
}
