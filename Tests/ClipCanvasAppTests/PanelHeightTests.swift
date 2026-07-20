import AppKit
import ClipCanvasCore
import Foundation
import SwiftUI
import XCTest
@testable import ClipCanvasApp

@MainActor
final class PanelHeightTests: XCTestCase {
    func testClipboardCardGrowsWithMainPanel() {
        let date = Date()
        let item = ClipboardItem(
            id: UUID(),
            kind: .text,
            plainText: "Sample",
            title: nil,
            source: .init(bundleID: "com.apple.TextEdit", name: "TextEdit"),
            contentHash: UUID().uuidString,
            createdAt: date,
            lastCopiedAt: date,
            copyCount: 1,
            isSensitive: false,
            metadata: .init(byteCount: 6),
            representations: []
        )
        let card = NSHostingView(
            rootView: ClipboardCardView(
                item: item,
                isSelected: false,
                quickPasteIndex: 1,
                imageData: nil
            )
        )
        card.layoutSubtreeIfNeeded()
        let panelGrowth = PinboardEditorView.height - 250

        XCTAssertEqual(
            card.fittingSize.height,
            180 + panelGrowth,
            accuracy: 1
        )
    }

    func testMainPanelMatchesPinboardEditorHeight() throws {
        let suite = "dev.clipcanvas.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let controller = PanelController(
            model: AppModel(),
            settings: SettingsStore(defaults: defaults)
        )
        let panel = try XCTUnwrap(
            Mirror(reflecting: controller).children
                .first(where: { $0.label == "panel" })?
                .value as? NSPanel
        )
        let editor = NSHostingView(
            rootView: PinboardEditorView { _, _, _ in }
        )
        editor.layoutSubtreeIfNeeded()

        controller.show()
        defer { controller.hide() }

        XCTAssertEqual(
            panel.frame.height,
            editor.fittingSize.height,
            accuracy: 1
        )
    }
}
