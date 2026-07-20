import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let settings: SettingsStore
    private let panel: ClipCanvasPanel
    private var keyMonitor: Any?
    private(set) var previousApplication: NSRunningApplication?

    init(model: AppModel, settings: SettingsStore) {
        self.model = model
        self.settings = settings
        panel = ClipCanvasPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
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
            model.hidePanel()
            return
        }
        removeKeyMonitor()
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
        if panel.isVisible, !model.isPresentingSheet {
            hide()
        }
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
        switch event.keyCode {
        case 3 where command:
            model.toggleSearchFocus()
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

    static func shouldRoutePanelKeyboardEvent(isPresentingSheet: Bool) -> Bool {
        !isPresentingSheet
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
