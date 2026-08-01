import AppKit
import Combine
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let settings: SettingsStore
    private let onOpenPetSettings: @MainActor () -> Void
    private let panel: ClipCanvasPanel
    private let petWindow: ClipCanvasPetWindow
    private var keyMonitor: Any?
    private var petVisibilityCancellable: AnyCancellable?
    private(set) var previousApplication: NSRunningApplication?

    init(
        model: AppModel,
        settings: SettingsStore,
        onOpenPetSettings: @escaping @MainActor () -> Void = {}
    ) {
        self.model = model
        self.settings = settings
        self.onOpenPetSettings = onOpenPetSettings
        panel = ClipCanvasPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        petWindow = ClipCanvasPetWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        super.init()
        panel.delegate = self
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient
        ]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(
            rootView: HistoryPanelView()
                .environmentObject(model)
        )

        petWindow.backgroundColor = .clear
        petWindow.isOpaque = false
        petWindow.hasShadow = false
        petWindow.level = .statusBar
        petWindow.collectionBehavior = panel.collectionBehavior
        petWindow.isReleasedWhenClosed = false
        petWindow.ignoresMouseEvents = false
        petWindow.onClick = onOpenPetSettings
        let petHostView = NSHostingView(
            rootView: PanelPetHostView(onOpenSettings: onOpenPetSettings)
                .environmentObject(model)
                .environmentObject(settings)
        )
        petHostView.wantsLayer = true
        petHostView.layer?.backgroundColor = NSColor.clear.cgColor
        petWindow.contentView = petHostView

        petVisibilityCancellable = settings.$showPetOnPanel
            .removeDuplicates()
            .sink { [weak self] isVisible in
                guard let self else { return }
                if isVisible, panel.isVisible {
                    showPetPanel()
                } else {
                    hidePetPanel()
                }
            }
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        guard settings.showDuringScreenSharing || !model.isScreenSharingActive else {
            model.errorMessage = String(localized: "privacy.panel_hidden")
            return
        }
        previousApplication = NSWorkspace.shared.frontmostApplication
        model.reload()
        positionPanel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        showPetPanelIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        installKeyMonitor()
        if !model.isPanelPresented {
            model.togglePanel()
        }
    }

    func hide() {
        guard panel.isVisible else {
            hidePetPanel()
            model.hidePanel()
            return
        }
        removeKeyMonitor()
        hidePetPanel()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
                panel?.alphaValue = 1
            }
        })
        model.hidePanel()
    }

    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if Self.shouldHideAfterFocusChange(
                isPanelVisible: panel.isVisible,
                isPresentingSheet: model.isPresentingSheet,
                panelIsKey: panel.isKeyWindow
            ) {
                hide()
            }
        }
    }

    static func shouldHideAfterFocusChange(
        isPanelVisible: Bool,
        isPresentingSheet: Bool,
        panelIsKey: Bool
    ) -> Bool {
        isPanelVisible && !isPresentingSheet && !panelIsKey
    }

    private func positionPanel() {
        let targetScreen = screenContainingMouse() ?? NSScreen.main
        guard let visibleFrame = targetScreen?.visibleFrame else { return }
        let horizontalMargin: CGFloat = 12
        let bottomMargin: CGFloat = 10
        let frame = NSRect(
            x: visibleFrame.minX + horizontalMargin,
            y: visibleFrame.minY + bottomMargin,
            width: max(720, visibleFrame.width - horizontalMargin * 2),
            height: PinboardEditorView.height
        )
        panel.setFrame(frame, display: true)
        positionPetPanel()
    }

    private func showPetPanelIfNeeded() {
        if settings.showPetOnPanel {
            showPetPanel()
        } else {
            hidePetPanel()
        }
    }

    private func showPetPanel() {
        positionPetPanel()
        if petWindow.parent !== panel {
            panel.addChildWindow(petWindow, ordered: .above)
        }
        petWindow.alphaValue = 1
        petWindow.order(.above, relativeTo: panel.windowNumber)
    }

    private func hidePetPanel() {
        if petWindow.parent === panel {
            panel.removeChildWindow(petWindow)
        }
        petWindow.orderOut(nil)
    }

    private func positionPetPanel() {
        let frame = PanelPetPerchLayout.standard.petWindowFrame(
            above: panel.frame
        )
        petWindow.setFrame(frame, display: true)
    }

    private func screenContainingMouse() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) })
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return handleKeyDown(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard Self.shouldRoutePanelKeyboardEvent(
            isPresentingSheet: model.isPresentingSheet
        ) else {
            return false
        }
        let command = event.modifierFlags.contains(.command)
        if event.keyCode == 3, command {
            model.toggleSearchFocus()
            return true
        }
        guard Self.shouldRoutePanelKeyboardEvent(
            isPresentingSheet: false,
            firstResponder: panel.firstResponder
        ) else {
            return false
        }
        switch event.keyCode {
        case 123 where command:
            model.selectAdjacentPinboard(offset: -1)
        case 124 where command:
            model.selectAdjacentPinboard(offset: 1)
        case 123:
            model.moveSelection(by: -1)
        case 124:
            model.moveSelection(by: 1)
        case 36:
            Task { await model.pasteSelected(forcePlainText: event.modifierFlags.contains(.shift)) }
        case 49:
            model.isPreviewPresented.toggle()
        case 51 where Self.shouldHandleDeleteShortcut(firstResponder: panel.firstResponder):
            model.requestDeleteSelected()
        case 51:
            return false
        case 53:
            hide()
        case let keyCode where command:
            guard let index = Self.quickPasteIndex(for: keyCode) else {
                return false
            }
            if let item = model.itemForQuickPaste(index: index) {
                Task {
                    await model.paste(
                        item,
                        forcePlainText: event.modifierFlags.contains(.shift)
                    )
                }
            }
        default:
            return false
        }
        return true
    }

    static func shouldRoutePanelKeyboardEvent(
        isPresentingSheet: Bool,
        firstResponder: NSResponder? = nil
    ) -> Bool {
        !isPresentingSheet && shouldHandleDeleteShortcut(firstResponder: firstResponder)
    }

    static func shouldHandleDeleteShortcut(firstResponder: NSResponder?) -> Bool {
        if let textEditor = firstResponder as? NSTextView {
            return !textEditor.isEditable
        }
        if let textField = firstResponder as? NSTextField {
            return !textField.isEditable
        }
        return true
    }

    private static func quickPasteIndex(for keyCode: UInt16) -> Int? {
        let mapping: [UInt16: Int] = [
            18: 1, 19: 2, 20: 3, 21: 4, 23: 5,
            22: 6, 26: 7, 28: 8, 25: 9
        ]
        return mapping[keyCode]
    }
}

private final class ClipCanvasPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class ClipCanvasPetWindow: NSWindow {
    var onClick: (@MainActor () -> Void)?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            onClick?()
            return
        }
        super.sendEvent(event)
    }
}
