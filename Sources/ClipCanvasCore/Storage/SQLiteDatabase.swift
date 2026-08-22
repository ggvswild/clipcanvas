import Foundation
import SQLite3

public enum SQLiteValue: Sendable, Equatable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
}

public struct SQLiteRow: Sendable {
    private let values: [String: SQLiteValue]

    init(values: [String: SQLiteValue]) {
        self.values = values
    }

    public subscript(_ column: String) -> SQLiteValue? {
        values[column]
    }

    public func string(_ column: String) -> String? {
        guard case let .text(value) = values[column] else { return nil }
        return value
    }

    public func integer(_ column: String) -> Int64? {
        guard case let .integer(value) = values[column] else { return nil }
        return value
    }

    public func double(_ column: String) -> Double? {
        switch values[column] {
        case let .real(value):
            return value
        case let .integer(value):
            return Double(value)
        default:
            return nil
        }
    }

    public func data(_ column: String) -> Data? {
        guard case let .blob(value) = values[column] else { return nil }
        return value
    }
}

public struct SQLiteFailure: Error, CustomStringConvertible, Sendable {
    public let code: Int32
    public let message: String
    public let sql: String?

    public var description: String {
        if let sql {
            return "SQLite error \(code): \(message) [\(sql)]"
        }
        return "SQLite error \(code): \(message)"
    }
}

public final class SQLiteDatabase: @unchecked Sendable {
    private let handle: OpaquePointer
    private let lock = NSRecursiveLock()
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(url.path, &database, flags, nil)
        guard result == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open database"
            if let database {
                sqlite3_close(database)
            }
            throw SQLiteFailure(code: result, message: message, sql: nil)
        }

        handle = database
        sqlite3_busy_timeout(database, 2_000)

        do {
            try execute("PRAGMA foreign_keys = ON")
            try execute("PRAGMA journal_mode = WAL")
            try migrate()
        } catch {
            sqlite3_close(database)
            throw error
        }
    }

    deinit {
        sqlite3_close(handle)
    }

    public func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        try lock.withLock {
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }
            try bind(bindings, to: statement, sql: sql)

            let result = sqlite3_step(statement)
            guard result == SQLITE_DONE || result == SQLITE_ROW else {
                throw failure(code: result, sql: sql)
            }
        }
    }

    public func rows(_ sql: String, bindings: [SQLiteValue] = []) throws -> [SQLiteRow] {
        try lock.withLock {
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }
            try bind(bindings, to: statement, sql: sql)

            var output: [SQLiteRow] = []
            while true {
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE {
                    return output
                }
                guard result == SQLITE_ROW else {
                    throw failure(code: result, sql: sql)
                }

                var values: [String: SQLiteValue] = [:]
                for index in 0..<sqlite3_column_count(statement) {
                    let name = String(cString: sqlite3_column_name(statement, index))
                    switch sqlite3_column_type(statement, index) {
                    case SQLITE_INTEGER:
                        values[name] = .integer(sqlite3_column_int64(statement, index))
                    case SQLITE_FLOAT:
                        values[name] = .real(sqlite3_column_double(statement, index))
                    case SQLITE_TEXT:
                        values[name] = .text(String(cString: sqlite3_column_text(statement, index)))
                    case SQLITE_BLOB:
                        let count = Int(sqlite3_column_bytes(statement, index))
                        if let bytes = sqlite3_column_blob(statement, index) {
                            values[name] = .blob(Data(bytes: bytes, count: count))
                        } else {
                            values[name] = .blob(Data())
                        }
                    default:
                        values[name] = .null
                    }
                }
                output.append(SQLiteRow(values: values))
            }
        }
    }

    public func scalarInt(_ sql: String, bindings: [SQLiteValue] = []) throws -> Int {
        guard let row = try rows(sql, bindings: bindings).first,
              case let .integer(value)? = row[try firstColumnName(sql)] else {
            return 0
        }
        return Int(value)
    }

    public func tableNames() throws -> Set<String> {
        Set(
            try rows(
                """
                SELECT name
                FROM sqlite_master
                WHERE type IN ('table', 'view')
                """
            ).compactMap { $0.string("name") }
        )
    }

    public func transaction<T>(_ body: () throws -> T) throws -> T {
        try lock.withLock {
            try execute("BEGIN IMMEDIATE")
            do {
                let value = try body()
                try execute("COMMIT")
                return value
            } catch {
                try? execute("ROLLBACK")
                throw error
            }
        }
    }

    private func migrate() throws {
        let version = try rows("PRAGMA user_version").first?.integer("user_version") ?? 0
        if version < 1 {
            try migrateToVersion1()
        }
        if version < 2 {
            try migrateToVersion2()
        }
    }

    private func migrateToVersion1() throws {
        try transaction {
            try execute(
                """
                CREATE TABLE IF NOT EXISTS clipboard_items (
                    id TEXT PRIMARY KEY NOT NULL,
                    kind TEXT NOT NULL,
                    plain_text TEXT,
                    title TEXT,
                    source_bundle_id TEXT,
                    source_name TEXT,
                    source_icon_path TEXT,
                    content_hash TEXT NOT NULL UNIQUE,
                    created_at REAL NOT NULL,
                    last_copied_at REAL NOT NULL,
                    copy_count INTEGER NOT NULL DEFAULT 1,
                    is_sensitive INTEGER NOT NULL DEFAULT 0,
                    metadata_json BLOB
                )
                """
            )
            try execute(
                """
                CREATE INDEX IF NOT EXISTS clipboard_items_recency
                ON clipboard_items(last_copied_at DESC, id DESC)
                """
            )
            try execute(
                """
                CREATE TABLE IF NOT EXISTS item_representations (
                    id TEXT PRIMARY KEY NOT NULL,
                    item_id TEXT NOT NULL REFERENCES clipboard_items(id) ON DELETE CASCADE,
                    uti TEXT NOT NULL,
                    storage TEXT NOT NULL,
                    inline_data BLOB,
                    file_path TEXT,
                    byte_count INTEGER NOT NULL
                )
                """
            )
            try execute(
                """
                CREATE VIRTUAL TABLE IF NOT EXISTS clipboard_fts
                USING fts5(item_id UNINDEXED, plain_text, title, source_name)
                """
            )
            try execute(
                """
                CREATE TABLE IF NOT EXISTS pinboards (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    color TEXT NOT NULL,
                    symbol TEXT NOT NULL,
                    sort_index INTEGER NOT NULL,
                    is_system INTEGER NOT NULL DEFAULT 0,
                    created_at REAL NOT NULL
                )
                """
            )
            try execute(
                """
                CREATE TABLE IF NOT EXISTS pinboard_items (
                    pinboard_id TEXT NOT NULL REFERENCES pinboards(id) ON DELETE CASCADE,
                    item_id TEXT NOT NULL REFERENCES clipboard_items(id) ON DELETE CASCADE,
                    sort_index INTEGER NOT NULL,
                    created_at REAL NOT NULL,
                    PRIMARY KEY(pinboard_id, item_id)
                )
                """
            )
            try execute(
                """
                CREATE TABLE IF NOT EXISTS authorized_clients (
                    id TEXT PRIMARY KEY NOT NULL,
                    display_name TEXT NOT NULL,
                    token_hash TEXT NOT NULL UNIQUE,
                    scopes TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    last_used_at REAL,
                    revoked_at REAL
                )
                """
            )
            try execute(
                """
                CREATE TABLE IF NOT EXISTS audit_events (
                    id TEXT PRIMARY KEY NOT NULL,
                    client_id TEXT,
                    method TEXT NOT NULL,
                    item_id TEXT,
                    outcome TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    detail TEXT
                )
                """
            )
            try execute(
                """
                INSERT OR IGNORE INTO pinboards
                (id, name, color, symbol, sort_index, is_system, created_at)
                VALUES (?, 'Useful Links', 'pink', 'link', 0, 1, ?)
                """,
                bindings: [
                    .text(Pinboard.usefulLinksID.uuidString),
                    .real(Date().timeIntervalSince1970)
                ]
            )
            try execute("PRAGMA user_version = 1")
        }
    }

    private func migrateToVersion2() throws {
        try transaction {
            try execute(
                "ALTER TABLE clipboard_items ADD COLUMN sort_index INTEGER"
            )
            try execute(
                """
                WITH ranked AS (
                    SELECT id,
                           (ROW_NUMBER() OVER (
                               ORDER BY last_copied_at DESC, id DESC
                           ) - 1) AS new_sort
                    FROM clipboard_items
                )
                UPDATE clipboard_items
                SET sort_index = (
                    SELECT new_sort
                    FROM ranked
                    WHERE ranked.id = clipboard_items.id
                )
                """
            )
            try execute(
                """
                CREATE INDEX IF NOT EXISTS clipboard_items_sort
                ON clipboard_items(sort_index ASC, last_copied_at DESC, id DESC)
                """
            )
            try execute("PRAGMA user_version = 2")
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw failure(code: result, sql: sql)
        }
        return statement
    }

    private func bind(_ values: [SQLiteValue], to statement: OpaquePointer, sql: String) throws {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .null:
                result = sqlite3_bind_null(statement, index)
            case let .integer(value):
                result = sqlite3_bind_int64(statement, index, value)
            case let .real(value):
                result = sqlite3_bind_double(statement, index, value)
            case let .text(value):
                result = sqlite3_bind_text(statement, index, value, -1, Self.transient)
            case let .blob(value):
                result = value.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), Self.transient)
                }
            }
            guard result == SQLITE_OK else {
                throw failure(code: result, sql: sql)
            }
        }
    }

    private func failure(code: Int32, sql: String?) -> SQLiteFailure {
        SQLiteFailure(
            code: code,
            message: String(cString: sqlite3_errmsg(handle)),
            sql: sql
        )
    }

    private func firstColumnName(_ sql: String) throws -> String {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_column_count(statement) > 0 else {
            return ""
        }
        return String(cString: sqlite3_column_name(statement, 0))
    }
}

private extension NSRecursiveLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
