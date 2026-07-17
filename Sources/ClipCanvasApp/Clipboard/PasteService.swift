import AppKit
import ApplicationServices
import ClipCanvasCore
import Foundation

enum PasteStrategy: String, Codable, CaseIterable {
    case activeApp
    case clipboardOnly
}

enum PasteError: Error, Equatable {
    case accessibilityDenied
    case missingRepresentation
}

@MainActor
final class PasteService {
    private let pasteboard: NSPasteboard
    private let repository: ClipboardRepository

    init(
        pasteboard: NSPasteboard = .general,
        repository: ClipboardRepository
    ) {
        self.pasteboard = pasteboard
        self.repository = repository
    }

    func perform(
        item: ClipboardItem,
        strategy: PasteStrategy,
        plainText: Bool,
        targetApplication: NSRunningApplication?
    ) async throws {
        try write(item: item, plainText: plainText)
        guard strategy == .activeApp else { return }
        guard AXIsProcessTrusted() else {
            throw PasteError.accessibilityDenied
        }

        targetApplication?.activate(options: [.activateAllWindows])
        try await Task.sleep(for: .milliseconds(90))
        emitCommandV()
    }

    func write(item: ClipboardItem, plainText: Bool) throws {
        pasteboard.clearContents()
        pasteboard.setData(Data(), forType: .init(PrivacyPolicy.internalMarkerType))

        if plainText, let text = item.plainText {
            pasteboard.setString(text, forType: .string)
            return
        }

        var wroteRepresentation = false
        for representation in item.representations {
            let data = try repository.representationData(representation)
            pasteboard.setData(data, forType: .init(representation.uti))
            wroteRepresentation = true
        }
        if let text = item.plainText {
            pasteboard.setString(text, forType: .string)
            wroteRepresentation = true
        }
        guard wroteRepresentation else {
            throw PasteError.missingRepresentation
        }
    }

    private func emitCommandV() {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(
                keyboardEventSource: source,
                virtualKey: 9,
                keyDown: true
              ),
              let up = CGEvent(
                keyboardEventSource: source,
                virtualKey: 9,
                keyDown: false
              ) else {
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
