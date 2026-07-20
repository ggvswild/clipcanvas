import ClipCanvasCore
import Combine

@MainActor
final class ShortcutBindingCoordinator {
    private var cancellable: AnyCancellable?

    init(
        settings: SettingsStore,
        onChange: @escaping ([ShortcutAction: KeyboardShortcut]) -> Void
    ) {
        cancellable = settings.$shortcuts.sink(receiveValue: onChange)
    }
}
