import Foundation
import XCTest
@testable import ClipCanvasApp

final class LinkPreviewServiceTests: XCTestCase {
    func testOpenGraphTitleWinsOverHTMLTitle() async throws {
        let html = """
        <html><head>
        <title>Fallback</title>
        <meta property="og:title" content="Open Graph Title">
        </head></html>
        """
        let service = LinkPreviewService(fetchData: { _ in Data(html.utf8) })

        let preview = try await service.preview(for: URL(string: "https://example.com")!)

        XCTAssertEqual(preview.title, "Open Graph Title")
    }

    func testHTMLTitleIsDecodedAndTrimmed() async throws {
        let html = "<title>  Local &amp; Private  </title>"
        let service = LinkPreviewService(fetchData: { _ in Data(html.utf8) })

        let preview = try await service.preview(for: URL(string: "https://example.com")!)

        XCTAssertEqual(preview.title, "Local & Private")
    }
}
