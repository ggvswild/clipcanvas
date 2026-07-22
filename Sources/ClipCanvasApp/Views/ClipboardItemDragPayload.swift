import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ClipboardItemDragPayload: Codable, Equatable, Transferable {
    static let contentType = UTType(
        exportedAs: "dev.clipcanvas.clipboard-item",
        conformingTo: .data
    )

    let itemID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: contentType)
    }
}
