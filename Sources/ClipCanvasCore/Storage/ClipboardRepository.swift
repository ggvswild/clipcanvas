import CryptoKit
import Foundation

public enum ClipboardRepositoryError: Error, Equatable, Sendable {
    case itemNotFound
    case pinboardNotFound
    case systemPinboardCannotBeDeleted
    case invalidStoredData
}

public final class ClipboardRepository: @unchecked Sendable {
    private let database: SQLiteDatabase
    private let blobStore: BlobStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let inlineThreshold = 64 * 1_024

    public init(database: SQLiteDatabase, blobStore: BlobStore) {
        self.database = database
        self.blobStore = blobStore
    }

    @discardableResult
    public func upsert(_ draft: ClipboardDraft) throws -> ClipboardItem {
        let hash = contentHash(for: draft)
        if let existing = try item(withHash: hash) {
            try database.transaction {
                try database.execute(
                    """
                    UPDATE clipboard_items
                    SET last_copied_at = ?,
                        copy_count = copy_count + 1,
                        source_bundle_id = ?,
                        source_name = ?,
                        source_icon_path = ?
                    WHERE id = ?
                    """,
                    bindings: [
                        .real(draft.capturedAt.timeIntervalSince1970),
                        draft.source.bundleID.map(SQLiteValue.text) ?? .null,
                        .text(draft.source.name),
                        draft.source.iconPath.map(SQLiteValue.text) ?? .null,
                        .text(existing.id.uuidString)
                    ]
                )
                try replaceFTS(
                    itemID: existing.id,
                    plainText: existing.plainText,
                    title: existing.title,
                    sourceName: draft.source.name
                )
            }
            return try item(id: existing.id)
        }

        let id = UUID()
        let metadataData = try encoder.encode(draft.metadata)
        let representations = try draft.representations.map { representation in
            if representation.data.count > inlineThreshold || draft.kind == .image {
                let reference = try blobStore.put(
                    representation.data,
                    fileExtension: representation.fileExtension
                )
                return ClipboardRepresentation(
                    uti: representation.uti,
                    blob: reference,
                    byteCount: representation.data.count
                )
            }
            return ClipboardRepresentation(
                uti: representation.uti,
                inlineData: representation.data,
                byteCount: representation.data.count
            )
        }

        try database.transaction {
            try database.execute(
                """
                INSERT INTO clipboard_items
                (id, kind, plain_text, title, source_bundle_id, source_name,
                 source_icon_path, content_hash, created_at, last_copied_at,
                 copy_count, is_sensitive, metadata_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
                """,
                bindings: [
                    .text(id.uuidString),
                    .text(draft.kind.rawValue),
                    draft.plainText.map(SQLiteValue.text) ?? .null,
                    draft.title.map(SQLiteValue.text) ?? .null,
                    draft.source.bundleID.map(SQLiteValue.text) ?? .null,
                    .text(draft.source.name),
                    draft.source.iconPath.map(SQLiteValue.text) ?? .null,
                    .text(hash),
                    .real(draft.capturedAt.timeIntervalSince1970),
                    .real(draft.capturedAt.timeIntervalSince1970),
                    .integer(draft.isSensitive ? 1 : 0),
                    .blob(metadataData)
                ]
            )

            for representation in representations {
                try database.execute(
                    """
                    INSERT INTO item_representations
                    (id, item_id, uti, storage, inline_data, file_path, byte_count)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        .text(representation.id.uuidString),
                        .text(id.uuidString),
                        .text(representation.uti),
                        .text(representation.blob == nil ? "inline" : "blob"),
                        representation.inlineData.map(SQLiteValue.blob) ?? .null,
                        representation.blob.map { .text($0.relativePath) } ?? .null,
                        .integer(Int64(representation.byteCount))
                    ]
                )
            }

            try replaceFTS(
                itemID: id,
                plainText: draft.plainText,
                title: draft.title,
                sourceName: draft.source.name
            )
        }

        return try item(id: id)
    }

    public func item(id: UUID) throws -> ClipboardItem {
        guard let row = try database.rows(
            "SELECT * FROM clipboard_items WHERE id = ?",
            bindings: [.text(id.uuidString)]
        ).first else {
            throw ClipboardRepositoryError.itemNotFound
        }
        return try decodeItem(row)
    }

    public func list(_ query: HistoryQuery = .init()) throws -> HistoryPage {
        var sql = "SELECT * FROM clipboard_items"
        var conditions: [String] = []
        var bindings: [SQLiteValue] = []

        if let kind = query.kind {
            conditions.append("kind = ?")
            bindings.append(.text(kind.rawValue))
        }
        if let before = query.before {
            conditions.append("last_copied_at < ?")
            bindings.append(.real(before.timeIntervalSince1970))
        }
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY last_copied_at DESC, id DESC LIMIT ?"
        bindings.append(.integer(Int64(query.limit)))

        let items = try database.rows(sql, bindings: bindings).map(decodeItem)
        return HistoryPage(
            items: items,
            nextCursor: items.count == query.limit ? items.last?.lastCopiedAt : nil
        )
    }

    public func search(_ query: String, limit: Int = 50) throws -> HistoryPage {
        let tokens = query
            .split(whereSeparator: \.isWhitespace)
            .map { $0.replacingOccurrences(of: "\"", with: "\"\"") }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else {
            return try list(.init(limit: limit))
        }
        let match = tokens.map { "\"\($0)\"*" }.joined(separator: " AND ")
        let rows = try database.rows(
            """
            SELECT clipboard_items.*
            FROM clipboard_fts
            JOIN clipboard_items ON clipboard_items.id = clipboard_fts.item_id
            WHERE clipboard_fts MATCH ?
            ORDER BY clipboard_items.last_copied_at DESC
            LIMIT ?
            """,
            bindings: [.text(match), .integer(Int64(max(1, min(limit, 200))))]
        )
        let items = try rows.map(decodeItem)
        return HistoryPage(items: items, nextCursor: nil)
    }

    public func delete(id: UUID) throws {
        _ = try item(id: id)
        try database.execute(
            "DELETE FROM clipboard_items WHERE id = ?",
            bindings: [.text(id.uuidString)]
        )
        try database.execute(
            "DELETE FROM clipboard_fts WHERE item_id = ?",
            bindings: [.text(id.uuidString)]
        )
    }

    public func eraseHistory(preservingPinned: Bool = true) throws {
        if preservingPinned {
            try database.execute(
                """
                DELETE FROM clipboard_items
                WHERE id NOT IN (SELECT item_id FROM pinboard_items)
                """
            )
            try database.execute(
                """
                DELETE FROM clipboard_fts
                WHERE item_id NOT IN (SELECT id FROM clipboard_items)
                """
            )
        } else {
            try database.execute("DELETE FROM clipboard_items")
            try database.execute("DELETE FROM clipboard_fts")
        }
    }

    public func deleteItems(
        olderThan cutoff: Date,
        preservingPinned: Bool = true
    ) throws {
        if preservingPinned {
            try database.execute(
                """
                DELETE FROM clipboard_items
                WHERE last_copied_at < ?
                  AND id NOT IN (SELECT item_id FROM pinboard_items)
                """,
                bindings: [.real(cutoff.timeIntervalSince1970)]
            )
        } else {
            try database.execute(
                "DELETE FROM clipboard_items WHERE last_copied_at < ?",
                bindings: [.real(cutoff.timeIntervalSince1970)]
            )
        }
        try database.execute(
            """
            DELETE FROM clipboard_fts
            WHERE item_id NOT IN (SELECT id FROM clipboard_items)
            """
        )
    }

    public func updateTitle(id: UUID, title: String?) throws {
        let existing = try item(id: id)
        try database.transaction {
            try database.execute(
                "UPDATE clipboard_items SET title = ? WHERE id = ?",
                bindings: [
                    title.map(SQLiteValue.text) ?? .null,
                    .text(id.uuidString)
                ]
            )
            try replaceFTS(
                itemID: id,
                plainText: existing.plainText,
                title: title,
                sourceName: existing.source.name
            )
        }
    }

    public func listPinboards() throws -> [Pinboard] {
        try database.rows(
            "SELECT * FROM pinboards ORDER BY sort_index ASC, created_at ASC"
        ).map(decodePinboard)
    }

    public func createPinboard(
        name: String,
        color: String = "cyan",
        symbol: String = "pin.fill"
    ) throws -> Pinboard {
        let nextIndex = try database.scalarInt(
            "SELECT COALESCE(MAX(sort_index), 0) + 1 AS value FROM pinboards"
        )
        let pinboard = Pinboard(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            color: color,
            symbol: symbol,
            sortIndex: nextIndex
        )
        try database.execute(
            """
            INSERT INTO pinboards
            (id, name, color, symbol, sort_index, is_system, created_at)
            VALUES (?, ?, ?, ?, ?, 0, ?)
            """,
            bindings: [
                .text(pinboard.id.uuidString),
                .text(pinboard.name),
                .text(pinboard.color),
                .text(pinboard.symbol),
                .integer(Int64(pinboard.sortIndex)),
                .real(pinboard.createdAt.timeIntervalSince1970)
            ]
        )
        return pinboard
    }

    public func deletePinboard(id: UUID) throws {
        guard let board = try listPinboards().first(where: { $0.id == id }) else {
            throw ClipboardRepositoryError.pinboardNotFound
        }
        guard !board.isSystem else {
            throw ClipboardRepositoryError.systemPinboardCannotBeDeleted
        }
        try database.execute(
            "DELETE FROM pinboards WHERE id = ?",
            bindings: [.text(id.uuidString)]
        )
    }

    public func pin(itemID: UUID, to pinboardID: UUID) throws {
        _ = try item(id: itemID)
        guard try listPinboards().contains(where: { $0.id == pinboardID }) else {
            throw ClipboardRepositoryError.pinboardNotFound
        }
        let nextIndex = try database.scalarInt(
            """
            SELECT COALESCE(MAX(sort_index), -1) + 1 AS value
            FROM pinboard_items WHERE pinboard_id = ?
            """,
            bindings: [.text(pinboardID.uuidString)]
        )
        try database.execute(
            """
            INSERT OR REPLACE INTO pinboard_items
            (pinboard_id, item_id, sort_index, created_at)
            VALUES (?, ?, ?, ?)
            """,
            bindings: [
                .text(pinboardID.uuidString),
                .text(itemID.uuidString),
                .integer(Int64(nextIndex)),
                .real(Date().timeIntervalSince1970)
            ]
        )
    }

    public func unpin(itemID: UUID, from pinboardID: UUID) throws {
        try database.execute(
            "DELETE FROM pinboard_items WHERE pinboard_id = ? AND item_id = ?",
            bindings: [.text(pinboardID.uuidString), .text(itemID.uuidString)]
        )
    }

    public func items(in pinboardID: UUID, limit: Int = 50) throws -> HistoryPage {
        let rows = try database.rows(
            """
            SELECT clipboard_items.*
            FROM pinboard_items
            JOIN clipboard_items ON clipboard_items.id = pinboard_items.item_id
            WHERE pinboard_items.pinboard_id = ?
            ORDER BY pinboard_items.sort_index ASC
            LIMIT ?
            """,
            bindings: [
                .text(pinboardID.uuidString),
                .integer(Int64(max(1, min(limit, 200))))
            ]
        )
        return HistoryPage(items: try rows.map(decodeItem), nextCursor: nil)
    }

    public func representationData(_ representation: ClipboardRepresentation) throws -> Data {
        if let inlineData = representation.inlineData {
            return inlineData
        }
        if let blob = representation.blob {
            return try blobStore.data(for: blob)
        }
        throw ClipboardRepositoryError.invalidStoredData
    }

    private func item(withHash hash: String) throws -> ClipboardItem? {
        guard let row = try database.rows(
            "SELECT * FROM clipboard_items WHERE content_hash = ?",
            bindings: [.text(hash)]
        ).first else {
            return nil
        }
        return try decodeItem(row)
    }

    private func decodeItem(_ row: SQLiteRow) throws -> ClipboardItem {
        guard let idText = row.string("id"),
              let id = UUID(uuidString: idText),
              let kindText = row.string("kind"),
              let kind = ClipboardKind(rawValue: kindText),
              let hash = row.string("content_hash"),
              let createdAt = row.double("created_at"),
              let lastCopiedAt = row.double("last_copied_at"),
              let copyCount = row.integer("copy_count") else {
            throw ClipboardRepositoryError.invalidStoredData
        }
        let metadata: ClipboardMetadata
        if let data = row.data("metadata_json") {
            metadata = (try? decoder.decode(ClipboardMetadata.self, from: data)) ?? .init()
        } else {
            metadata = .init()
        }
        let representations = try database.rows(
            "SELECT * FROM item_representations WHERE item_id = ? ORDER BY rowid",
            bindings: [.text(id.uuidString)]
        ).map { representationRow in
            guard let representationIDText = representationRow.string("id"),
                  let representationID = UUID(uuidString: representationIDText),
                  let uti = representationRow.string("uti"),
                  let byteCount = representationRow.integer("byte_count") else {
                throw ClipboardRepositoryError.invalidStoredData
            }
            let filePath = representationRow.string("file_path")
            let blob = filePath.map {
                BlobReference(
                    digest: URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent,
                    relativePath: $0,
                    byteCount: Int(byteCount)
                )
            }
            return ClipboardRepresentation(
                id: representationID,
                uti: uti,
                inlineData: representationRow.data("inline_data"),
                blob: blob,
                byteCount: Int(byteCount)
            )
        }
        return ClipboardItem(
            id: id,
            kind: kind,
            plainText: row.string("plain_text"),
            title: row.string("title"),
            source: ClipboardSource(
                bundleID: row.string("source_bundle_id"),
                name: row.string("source_name") ?? "Unknown",
                iconPath: row.string("source_icon_path")
            ),
            contentHash: hash,
            createdAt: Date(timeIntervalSince1970: createdAt),
            lastCopiedAt: Date(timeIntervalSince1970: lastCopiedAt),
            copyCount: Int(copyCount),
            isSensitive: (row.integer("is_sensitive") ?? 0) != 0,
            metadata: metadata,
            representations: representations
        )
    }

    private func decodePinboard(_ row: SQLiteRow) throws -> Pinboard {
        guard let idText = row.string("id"),
              let id = UUID(uuidString: idText),
              let name = row.string("name"),
              let color = row.string("color"),
              let symbol = row.string("symbol"),
              let sortIndex = row.integer("sort_index"),
              let createdAt = row.double("created_at") else {
            throw ClipboardRepositoryError.invalidStoredData
        }
        return Pinboard(
            id: id,
            name: name,
            color: color,
            symbol: symbol,
            sortIndex: Int(sortIndex),
            isSystem: (row.integer("is_system") ?? 0) != 0,
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }

    private func replaceFTS(
        itemID: UUID,
        plainText: String?,
        title: String?,
        sourceName: String
    ) throws {
        try database.execute(
            "DELETE FROM clipboard_fts WHERE item_id = ?",
            bindings: [.text(itemID.uuidString)]
        )
        try database.execute(
            """
            INSERT INTO clipboard_fts(item_id, plain_text, title, source_name)
            VALUES (?, ?, ?, ?)
            """,
            bindings: [
                .text(itemID.uuidString),
                plainText.map(SQLiteValue.text) ?? .null,
                title.map(SQLiteValue.text) ?? .null,
                .text(sourceName)
            ]
        )
    }

    private func contentHash(for draft: ClipboardDraft) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(draft.kind.rawValue.utf8))
        if let plainText = draft.plainText {
            hasher.update(data: Data(plainText.precomposedStringWithCanonicalMapping.utf8))
        }
        for representation in draft.representations.sorted(by: { $0.uti < $1.uti }) {
            hasher.update(data: Data(representation.uti.utf8))
            hasher.update(data: representation.data)
        }
        return hasher.finalize().hexString
    }
}
