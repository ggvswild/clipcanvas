import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var isPanelPresented = false
    @Published var isCapturePaused = false

    func togglePanel() {
        isPanelPresented.toggle()
    }

    func hidePanel() {
        isPanelPresented = false
    }
}
