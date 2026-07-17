import AppKit
import ClipCanvasCore
import SwiftUI

struct ShortcutRecorderButton: View {
    let shortcut: ClipCanvasCore.KeyboardShortcut
    let onCapture: (ClipCanvasCore.KeyboardShortcut) -> Void
    @State private var isRecording = false

    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            Text(isRecording ? "shortcuts.recording" : shortcut.displayText)
                .frame(minWidth: 92)
        }
        .buttonStyle(.bordered)
        .background {
            ShortcutCaptureView(
                isRecording: $isRecording,
                onCapture: onCapture
            )
        }
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (ClipCanvasCore.KeyboardShortcut) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
        isRecording ? context.coordinator.start() : context.coordinator.stop()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        var parent: ShortcutCaptureView
        private var monitor: Any?

        init(parent: ShortcutCaptureView) {
            self.parent = parent
        }

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                var modifiers: ShortcutModifiers = []
                if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
                if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
                if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
                if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
                let shortcut = ClipCanvasCore.KeyboardShortcut(
                    keyCode: UInt32(event.keyCode),
                    modifiers: modifiers
                )
                MainActor.assumeIsolated {
                    parent.onCapture(shortcut)
                    parent.isRecording = false
                    stop()
                }
                return nil
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
