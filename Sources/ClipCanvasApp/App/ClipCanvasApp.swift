import SwiftUI

@main
struct ClipCanvasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        Settings {
            VStack(spacing: 16) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text("app.name")
                    .font(.title2.bold())
                Text("settings.placeholder")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 520, height: 360)
            .environmentObject(model)
        }
    }
}
