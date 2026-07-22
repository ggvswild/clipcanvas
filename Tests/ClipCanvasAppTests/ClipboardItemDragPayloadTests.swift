import XCTest
@testable import ClipCanvasApp
import UniformTypeIdentifiers

final class ClipboardItemDragPayloadTests: XCTestCase {
    func testPayloadKeepsItemIdentityAndUsesDedicatedContentType() {
        let itemID = UUID()

        let payload = ClipboardItemDragPayload(itemID: itemID)

        XCTAssertEqual(payload.itemID, itemID)
        XCTAssertEqual(
            ClipboardItemDragPayload.contentType.identifier,
            "dev.clipcanvas.clipboard-item"
        )
    }

    func testAppDeclaresDragPayloadAsExportedDataType() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistURL = repositoryRoot
            .appendingPathComponent("Configuration/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [String: Any]
        )
        let declarations = try XCTUnwrap(
            plist["UTExportedTypeDeclarations"] as? [[String: Any]]
        )
        let declaration = try XCTUnwrap(
            declarations.first {
                $0["UTTypeIdentifier"] as? String
                    == ClipboardItemDragPayload.contentType.identifier
            }
        )

        XCTAssertEqual(
            declaration["UTTypeConformsTo"] as? [String],
            [UTType.data.identifier]
        )
    }
}
