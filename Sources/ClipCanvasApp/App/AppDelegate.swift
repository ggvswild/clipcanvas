import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.stack.badge.plus",
            accessibilityDescription: String(localized: "app.name")
        )

        let menu = NSMenu()
        menu.addItem(
            withTitle: String(localized: "menu.open"),
            action: #selector(togglePanel),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: String(localized: "menu.settings"),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: String(localized: "menu.pause"),
            action: #selector(toggleCapture),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: String(localized: "menu.quit"),
            action: #selector(quit),
            keyEquivalent: "q"
        )

        for menuItem in menu.items {
            menuItem.target = self
        }
        item.menu = menu
        statusItem = item
    }

    @objc private func togglePanel() {
        AppModel.shared.togglePanel()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func toggleCapture(_ sender: NSMenuItem) {
        AppModel.shared.isCapturePaused.toggle()
        sender.title = String(
            localized: AppModel.shared.isCapturePaused ? "menu.resume" : "menu.pause"
        )
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
