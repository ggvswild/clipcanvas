import AppKit
import Foundation
import XCTest
@testable import ClipCanvasApp
import ClipCanvasCore

final class PasteboardSnapshotTests: XCTestCase {
    private let reader = PasteboardSnapshotReader()
    private var pasteboard: NSPasteboard!
    private let source = ClipboardSource(
        bundleID: "com.apple.TextEdit",
        name: "TextEdit"
    )

    override func setUp() {
        pasteboard = NSPasteboard(name: .init("dev.clipcanvas.tests.\(UUID().uuidString)"))
        pasteboard.clearContents()
    }

    func testPlainTextBecomesTextDraft() throws {
        pasteboard.setString("Hello ClipCanvas", forType: .string)

        let draft = try XCTUnwrap(reader.read(from: pasteboard, source: source))

        XCTAssertEqual(draft.kind, .text)
        XCTAssertEqual(draft.plainText, "Hello ClipCanvas")
        XCTAssertEqual(draft.representations.first?.uti, NSPasteboard.PasteboardType.string.rawValue)
    }

    func testWebURLBecomesLinkDraft() throws {
        pasteboard.writeObjects([URL(string: "https://example.com/path")! as NSURL])

        let draft = try XCTUnwrap(reader.read(from: pasteboard, source: source))

        XCTAssertEqual(draft.kind, .link)
        XCTAssertEqual(draft.plainText, "https://example.com/path")
        XCTAssertEqual(draft.metadata.domain, "example.com")
    }

    func testHTMLKeepsRichRepresentationAndPlainFallback() throws {
        pasteboard.setString("<b>Hello</b>", forType: .html)
        pasteboard.setString("Hello", forType: .string)

        let draft = try XCTUnwrap(reader.read(from: pasteboard, source: source))

        XCTAssertEqual(draft.kind, .richText)
        XCTAssertEqual(draft.plainText, "Hello")
        XCTAssertTrue(draft.representations.contains(where: { $0.uti == NSPasteboard.PasteboardType.html.rawValue }))
    }

    func testPNGImageBecomesImageDraft() throws {
        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 8,
                pixelsHigh: 6,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        pasteboard.setData(png, forType: .png)

        let draft = try XCTUnwrap(reader.read(from: pasteboard, source: source))

        XCTAssertEqual(draft.kind, .image)
        XCTAssertEqual(draft.metadata.imageWidth, 8)
        XCTAssertEqual(draft.metadata.imageHeight, 6)
        XCTAssertEqual(draft.representations.first?.fileExtension, "png")
    }

    func testMultipleFileURLsBecomeOneFilesDraft() throws {
        let first = URL(fileURLWithPath: "/tmp/first.txt")
        let second = URL(fileURLWithPath: "/tmp/second.png")
        pasteboard.writeObjects([first as NSURL, second as NSURL])

        let draft = try XCTUnwrap(reader.read(from: pasteboard, source: source))

        XCTAssertEqual(draft.kind, .files)
        XCTAssertEqual(draft.metadata.fileCount, 2)
        XCTAssertEqual(draft.metadata.fileNames, ["first.txt", "second.png"])
    }
}
