import Foundation
import SQLite3

public enum PasteImportError: Error, LocalizedError, Sendable {
    case missingExportFile
    case invalidTimestamp(String)
    case missingPinboard(Int)
    case missingImageArchive(Int)
    case invalidImageArchive(Int)
    case invalidItem(Int)

    public var errorDescription: String? {
        switch self {
        case .missingExportFile:
            "pinboard-export.json was not found."
        case let .invalidTimestamp(timestamp):
            "The Paste timestamp is invalid: \(timestamp)"
        case let .missingPinboard(id):
            "The Paste Pinboard is missing: \(id)"
        case let .missingImageArchive(index):
            "The Paste image archive is missing for item \(index)."
        case let .invalidImageArchive(index):
            "The Paste image archive is invalid for item \(index)."
        case let .invalidItem(index):
            "The Paste item has no usable content: \(index)."
        }
    }
}

public struct PasteImportSummary: Equatable, Sendable {
    public let pinboardsProcessed: Int
    public let itemsProcessed: Int
    public let imagesRecovered: Int

    public init(
        pinboardsProcessed: Int,
        itemsProcessed: Int,
        imagesRecovered: Int
    ) {
        self.pinboardsProcessed = pinboardsProcessed
        self.itemsProcessed = itemsProcessed
        self.imagesRecovered = imagesRecovered
    }
}

public final class PastePinboardImporter {
    private let repository: ClipboardRepository
    private let decoder = JSONDecoder()

    public init(repository: ClipboardRepository) {
        self.repository = repository
    }

    public func importDirectory(_ directory: URL) throws -> PasteImportSummary {
        let exportURL = directory.appendingPathComponent("pinboard-export.json")
        guard FileManager.default.fileExists(atPath: exportURL.path) else {
            throw PasteImportError.missingExportFile
        }

        let export = try decoder.decode(
            PasteExport.self,
            from: Data(contentsOf: exportURL)
        )
        let databaseURL = directory
            .appendingPathComponent("raw-db-backup", isDirectory: true)
            .appendingPathComponent("Paste.db")
        let imageReader = FileManager.default.fileExists(atPath: databaseURL.path)
            ? try PasteDatabaseReader(url: databaseURL)
            : nil
        let preparedItems = try export.items.map { item in
            (
                item: item,
                draft: try makeDraft(item, imageReader: imageReader)
            )
        }

        var pinboardIDs: [Int: UUID] = [:]
        var existingPinboards = try repository.listPinboards()
        for exportedPinboard in export.pinboards.sorted(by: {
            $0.displayOrder < $1.displayOrder
        }) {
            let pinboard: Pinboard
            if let existing = existingPinboards.first(where: {
                $0.name == exportedPinboard.name
            }) {
                pinboard = existing
            } else {
                pinboard = try repository.createPinboard(name: exportedPinboard.name)
                existingPinboards.append(pinboard)
            }
            pinboardIDs[exportedPinboard.id] = pinboard.id
        }

        var imagesRecovered = 0
        for prepared in preparedItems.sorted(by: {
            if $0.item.pinboardID == $1.item.pinboardID {
                return $0.item.orderInPinboard < $1.item.orderInPinboard
            }
            return $0.item.index < $1.item.index
        }) {
            guard let pinboardID = pinboardIDs[prepared.item.pinboardID] else {
                throw PasteImportError.missingPinboard(prepared.item.pinboardID)
            }
            let imported = try repository.upsert(prepared.draft)
            try repository.pin(itemID: imported.id, to: pinboardID)
            if prepared.item.type == "image" {
                imagesRecovered += 1
            }
        }

        return PasteImportSummary(
            pinboardsProcessed: export.pinboards.count,
            itemsProcessed: preparedItems.count,
            imagesRecovered: imagesRecovered
        )
    }

    private func makeDraft(
        _ item: PasteExportItem,
        imageReader: PasteDatabaseReader?
    ) throws -> ClipboardDraft {
        let timestamp = try parseTimestamp(item.timestamp)
        let source = ClipboardSource(
            bundleID: nonEmpty(item.sourceBundle),
            name: nonEmpty(item.sourceApp) ?? "Paste"
        )
        let title = nonEmpty(item.title) ?? nonEmpty(item.urlName)

        if item.type == "image" {
            guard let archive = try imageReader?.archiveData(snippetID: item.databaseID) else {
                throw PasteImportError.missingImageArchive(item.index)
            }
            guard let image = PasteArchiveDecoder.imageData(from: archive) else {
                throw PasteImportError.invalidImageArchive(item.index)
            }
            return ClipboardDraft(
                kind: .image,
                title: title,
                source: source,
                capturedAt: timestamp,
                metadata: .init(byteCount: image.count),
                representations: [
                    .init(uti: "public.png", data: image, fileExtension: "png")
                ]
            )
        }

        let plainText = nonEmpty(item.url) ?? nonEmpty(item.text)
        guard let plainText else {
            throw PasteImportError.invalidItem(item.index)
        }
        let html = nonEmpty(item.html)
        let kind: ClipboardKind
        if item.type == "link" {
            kind = .link
        } else if html != nil {
            kind = .richText
        } else {
            kind = .text
        }

        var representations: [ClipboardRepresentationDraft] = []
        if kind == .link {
            representations.append(
                .init(uti: "public.url", data: Data(plainText.utf8))
            )
        } else {
            if let html {
                representations.append(
                    .init(uti: "public.html", data: Data(html.utf8))
                )
            }
            representations.append(
                .init(uti: "public.utf8-plain-text", data: Data(plainText.utf8))
            )
        }

        return ClipboardDraft(
            kind: kind,
            plainText: plainText,
            title: title,
            source: source,
            capturedAt: timestamp,
            metadata: .init(
                byteCount: representations.reduce(0) { $0 + $1.data.count },
                domain: URL(string: plainText)?.host
            ),
            representations: representations
        )
    }

    private func parseTimestamp(_ timestamp: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        guard let date = formatter.date(from: timestamp) else {
            throw PasteImportError.invalidTimestamp(timestamp)
        }
        return date
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

enum PasteArchiveDecoder {
    static func imageData(from archive: Data) -> Data? {
        var propertyListData = archive
        if propertyListData.first == 0x01,
           propertyListData.dropFirst().starts(with: Data("bplist00".utf8)) {
            propertyListData.removeFirst()
        }
        guard let propertyList = try? PropertyListSerialization.propertyList(
            from: propertyListData,
            options: [],
            format: nil
        ),
        let dictionary = propertyList as? [String: Any],
        let objects = dictionary["$objects"] as? [Any] else {
            return nil
        }
        return objects
            .compactMap { $0 as? Data }
            .first(where: isSupportedImage)
    }

    private static func isSupportedImage(_ data: Data) -> Bool {
        data.starts(with: Data([0x89, 0x50, 0x4E, 0x47]))
            || data.starts(with: Data([0xFF, 0xD8, 0xFF]))
            || data.starts(with: Data("GIF8".utf8))
            || data.starts(with: Data([0x49, 0x49, 0x2A, 0x00]))
            || data.starts(with: Data([0x4D, 0x4D, 0x00, 0x2A]))
    }
}

private final class PasteDatabaseReader {
    private var handle: OpaquePointer?

    init(url: URL) throws {
        let result = sqlite3_open_v2(
            url.path,
            &handle,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK, handle != nil else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) }
                ?? "Unable to open Paste.db"
            if let handle {
                sqlite3_close(handle)
            }
            throw SQLiteFailure(code: result, message: message, sql: nil)
        }
    }

    deinit {
        if let handle {
            sqlite3_close(handle)
        }
    }

    func archiveData(snippetID: Int64) throws -> Data? {
        let sql = """
        SELECT ZPASTEBOARDITEMS
        FROM ZSNIPPETDATA
        WHERE ZSNIPPET = ?
        LIMIT 1
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw failure(sql: sql)
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, snippetID)
        let result = sqlite3_step(statement)
        if result == SQLITE_DONE {
            return nil
        }
        guard result == SQLITE_ROW else {
            throw failure(sql: sql)
        }
        let count = Int(sqlite3_column_bytes(statement, 0))
        guard let bytes = sqlite3_column_blob(statement, 0) else {
            return Data()
        }
        return Data(bytes: bytes, count: count)
    }

    private func failure(sql: String) -> SQLiteFailure {
        SQLiteFailure(
            code: sqlite3_errcode(handle),
            message: String(cString: sqlite3_errmsg(handle)),
            sql: sql
        )
    }
}

private struct PasteExport: Decodable {
    let pinboards: [PasteExportPinboard]
    let items: [PasteExportItem]
}

private struct PasteExportPinboard: Decodable {
    let id: Int
    let name: String
    let displayOrder: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayOrder = "display_order"
    }
}

private struct PasteExportItem: Decodable {
    let index: Int
    let databaseID: Int64
    let pinboardID: Int
    let orderInPinboard: Int
    let type: String
    let title: String?
    let urlName: String?
    let timestamp: String
    let sourceApp: String?
    let sourceBundle: String?
    let text: String?
    let html: String?
    let url: String?

    private enum CodingKeys: String, CodingKey {
        case index
        case databaseID = "db_pk"
        case pinboardID = "pinboard_id"
        case orderInPinboard = "order_in_pinboard"
        case type
        case title
        case urlName = "url_name"
        case timestamp
        case sourceApp = "source_app"
        case sourceBundle = "source_bundle"
        case text
        case html
        case url
    }
}
