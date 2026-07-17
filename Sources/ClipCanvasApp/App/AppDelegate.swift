import AppKit
import ClipCanvasCore
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var repository: ClipboardRepository?
    private var captureService: CaptureService?
    private var pasteService: PasteService?
    private var panelController: PanelController?
    private var hotKeyService: GlobalHotKeyService?
    private var screenSharingMonitor: ScreenSharingMonitor?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureServices()
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
        panelController?.toggle()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func toggleCapture(_ sender: NSMenuItem) {
        AppModel.shared.isCapturePaused.toggle()
        if AppModel.shared.isCapturePaused {
            captureService?.stop()
        } else {
            captureService?.start()
        }
        sender.title = String(
            localized: AppModel.shared.isCapturePaused ? "menu.resume" : "menu.pause"
        )
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func configureServices() {
        do {
            let root = try applicationSupportDirectory()
            let database = try SQLiteDatabase(
                url: root.appendingPathComponent("clipcanvas.sqlite3")
            )
            let blobStore = try BlobStore(rootURL: root.appendingPathComponent("blobs"))
            let repository = ClipboardRepository(database: database, blobStore: blobStore)
            let pasteService = PasteService(repository: repository)
            let settings = SettingsStore.shared
            let panel = PanelController(model: AppModel.shared, settings: settings)
            let linkPreview = LinkPreviewService()
            let capture = CaptureService(
                repository: repository,
                configuration: {
                    settings.privacyConfiguration
                },
                source: {
                    let application = NSWorkspace.shared.frontmostApplication
                    return ClipboardSource(
                        bundleID: application?.bundleIdentifier,
                        name: application?.localizedName ?? String(localized: "source.unknown"),
                        iconPath: application?.bundleURL?
                            .appendingPathComponent("Contents/Resources/AppIcon.icns")
                            .path
                    )
                },
                onCapture: { item in
                    Task { @MainActor in
                        AppModel.shared.received(item)
                        if settings.generateLinkPreviews,
                           item.kind == .link,
                           let text = item.plainText,
                           let url = URL(string: text) {
                            Task {
                                guard let preview = try? await linkPreview.preview(for: url) else {
                                    return
                                }
                                try? repository.updateTitle(id: item.id, title: preview.title)
                                await MainActor.run {
                                    AppModel.shared.reload()
                                }
                            }
                        }
                    }
                }
            )
            let hotKeys = GlobalHotKeyService()
            let sharingMonitor = ScreenSharingMonitor()

            AppModel.shared.configure(
                repository: repository,
                pasteService: pasteService,
                targetApplication: { [weak panel] in
                    panel?.previousApplication
                },
                hidePanel: { [weak panel] in
                    panel?.hide()
                }
            )
            AppModel.shared.pasteStrategy = settings.pasteStrategy
            AppModel.shared.alwaysPastePlainText = settings.alwaysPastePlainText
            configureSettingsBindings(
                settings: settings,
                hotKeys: hotKeys,
                panel: panel
            )
            sharingMonitor.onChange = { [weak panel] isSharing in
                AppModel.shared.isScreenSharingActive = isSharing
                if isSharing, !settings.showDuringScreenSharing {
                    panel?.hide()
                }
            }
            sharingMonitor.start()
            AppModel.shared.enforceRetention(settings.retentionPeriod)
            capture.start()

            self.repository = repository
            self.pasteService = pasteService
            captureService = capture
            panelController = panel
            hotKeyService = hotKeys
            screenSharingMonitor = sharingMonitor

            if ProcessInfo.processInfo.arguments.contains("--show-panel") {
                DispatchQueue.main.async {
                    panel.show()
                }
            } else if ProcessInfo.processInfo.arguments.contains("--show-settings") {
                DispatchQueue.main.async { [weak self] in
                    self?.openSettings()
                }
            }
        } catch {
            AppModel.shared.errorMessage = error.localizedDescription
        }
    }

    private func configureSettingsBindings(
        settings: SettingsStore,
        hotKeys: GlobalHotKeyService,
        panel: PanelController
    ) {
        settings.$pasteStrategy
            .sink { strategy in
                AppModel.shared.pasteStrategy = strategy
            }
            .store(in: &cancellables)
        settings.$alwaysPastePlainText
            .sink { enabled in
                AppModel.shared.alwaysPastePlainText = enabled
            }
            .store(in: &cancellables)
        settings.$retentionPeriod
            .dropFirst()
            .sink { period in
                AppModel.shared.enforceRetention(period)
            }
            .store(in: &cancellables)
        settings.$shortcuts
            .sink { [weak self] _ in
                self?.registerHotKeys(hotKeys, panel: panel)
            }
            .store(in: &cancellables)
    }

    private func registerHotKeys(
        _ hotKeys: GlobalHotKeyService,
        panel: PanelController
    ) {
        let defaults = SettingsStore.shared.shortcuts
        if let shortcut = defaults[.activate] {
            hotKeys.register(action: .activate, shortcut: shortcut) { [weak panel] in
                Task { @MainActor in panel?.toggle() }
            }
        }
        if let shortcut = defaults[.activateStack] {
            hotKeys.register(action: .activateStack, shortcut: shortcut) { [weak panel] in
                Task { @MainActor in panel?.toggle(stackMode: true) }
            }
        }
        if let shortcut = defaults[.previousPinboard] {
            hotKeys.register(action: .previousPinboard, shortcut: shortcut) { [weak panel] in
                Task { @MainActor in
                    if AppModel.shared.isPanelPresented {
                        AppModel.shared.selectAdjacentPinboard(offset: -1)
                    } else {
                        panel?.show()
                    }
                }
            }
        }
        if let shortcut = defaults[.nextPinboard] {
            hotKeys.register(action: .nextPinboard, shortcut: shortcut) { [weak panel] in
                Task { @MainActor in
                    if AppModel.shared.isPanelPresented {
                        AppModel.shared.selectAdjacentPinboard(offset: 1)
                    } else {
                        panel?.show()
                    }
                }
            }
        }
    }

    private func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent("ClipCanvas", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        return root
    }
}
