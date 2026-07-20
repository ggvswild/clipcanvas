import AppKit
import ClipCanvasCore
import SwiftUI

struct ShortcutRecorderButton: View {
    let shortcut: ClipCanvasCore.KeyboardShortcut?
    let onCapture: (ClipCanvasCore.KeyboardShortcut) -> Void
    let onClear: () -> Void
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isRecording.toggle()
            } label: {
                Text(displayText)
                    .frame(minWidth: 92)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if shortcut != nil {
                Divider()
                    .frame(height: 14)

                Button {
                    isRecording = false
                    onClear()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.bold())
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("shortcuts.clear"))
                .help("shortcuts.clear")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, shortcut == nil ? 10 : 6)
        .frame(height: 28)
        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.white.opacity(isRecording ? 0.34 : 0.12), lineWidth: 1)
        }
        .background {
            ShortcutCaptureView(
                isRecording: $isRecording,
                onCapture: onCapture
            )
        }
    }

    private var displayText: String {
        if isRecording {
            return String(localized: "shortcuts.recording")
        }
        return shortcut?.displayText ?? String(localized: "shortcuts.unassigned")
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
