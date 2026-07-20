import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let rootView: AnyView
    private var windowController: NSWindowController?

    init(rootView: AnyView) {
        self.rootView = rootView
    }

    var isVisible: Bool {
        windowController?.window?.isVisible == true
    }

    func show() {
        let controller = windowController ?? makeWindowController()
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        windowController?.close()
    }

    private func makeWindowController() -> NSWindowController {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "settings.title")
        window.contentViewController = NSHostingController(rootView: rootView)
        window.isReleasedWhenClosed = false
        window.center()
        return NSWindowController(window: window)
    }
}
