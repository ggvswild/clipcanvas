import Foundation

public enum ClipboardKind: String, Codable, CaseIterable, Sendable {
    case text
    case richText
    case image
    case link
    case files
    case unknown
}

public struct ClipboardSource: Codable, Hashable, Sendable {
    public var bundleID: String?
    public var name: String
    public var iconPath: String?

    public init(bundleID: String?, name: String, iconPath: String? = nil) {
        self.bundleID = bundleID
        self.name = name
        self.iconPath = iconPath
    }
}

public struct ClipboardMetadata: Codable, Hashable, Sendable {
    public var imageWidth: Int?
    public var imageHeight: Int?
    public var fileCount: Int?
    public var fileNames: [String]
    public var byteCount: Int?
    public var domain: String?

    public init(
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        fileCount: Int? = nil,
        fileNames: [String] = [],
        byteCount: Int? = nil,
        domain: String? = nil
    ) {
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.fileCount = fileCount
        self.fileNames = fileNames
        self.byteCount = byteCount
        self.domain = domain
    }
}

public struct ClipboardRepresentationDraft: Hashable, Sendable {
    public var uti: String
    public var data: Data
    public var fileExtension: String?

    public init(uti: String, data: Data, fileExtension: String? = nil) {
        self.uti = uti
        self.data = data
        self.fileExtension = fileExtension
    }
}

public struct BlobReference: Codable, Hashable, Sendable {
    public let digest: String
    public let relativePath: String
    public let byteCount: Int

    public init(digest: String, relativePath: String, byteCount: Int) {
        self.digest = digest
        self.relativePath = relativePath
        self.byteCount = byteCount
    }
}

public struct ClipboardRepresentation: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let uti: String
    public let inlineData: Data?
    public let blob: BlobReference?
    public let byteCount: Int

    public init(
        id: UUID = UUID(),
        uti: String,
        inlineData: Data? = nil,
        blob: BlobReference? = nil,
        byteCount: Int
    ) {
        self.id = id
        self.uti = uti
        self.inlineData = inlineData
        self.blob = blob
        self.byteCount = byteCount
    }
}

public struct ClipboardDraft: Sendable {
    public var kind: ClipboardKind
    public var plainText: String?
    public var title: String?
    public var source: ClipboardSource
    public var capturedAt: Date
    public var isSensitive: Bool
    public var metadata: ClipboardMetadata
    public var representations: [ClipboardRepresentationDraft]

    public init(
        kind: ClipboardKind,
        plainText: String? = nil,
        title: String? = nil,
        source: ClipboardSource,
        capturedAt: Date = Date(),
        isSensitive: Bool = false,
        metadata: ClipboardMetadata = .init(),
        representations: [ClipboardRepresentationDraft] = []
    ) {
        self.kind = kind
        self.plainText = plainText
        self.title = title
        self.source = source
        self.capturedAt = capturedAt
        self.isSensitive = isSensitive
        self.metadata = metadata
        self.representations = representations
    }
}

public struct ClipboardItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let kind: ClipboardKind
    public let plainText: String?
    public let title: String?
    public let source: ClipboardSource
    public let contentHash: String
    public let createdAt: Date
    public let lastCopiedAt: Date
    public let copyCount: Int
    public let isSensitive: Bool
    public let metadata: ClipboardMetadata
    public let representations: [ClipboardRepresentation]

    public init(
        id: UUID,
        kind: ClipboardKind,
        plainText: String?,
        title: String?,
        source: ClipboardSource,
        contentHash: String,
        createdAt: Date,
        lastCopiedAt: Date,
        copyCount: Int,
        isSensitive: Bool,
        metadata: ClipboardMetadata,
        representations: [ClipboardRepresentation]
    ) {
        self.id = id
        self.kind = kind
        self.plainText = plainText
        self.title = title
        self.source = source
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.lastCopiedAt = lastCopiedAt
        self.copyCount = copyCount
        self.isSensitive = isSensitive
        self.metadata = metadata
        self.representations = representations
    }
}

public struct HistoryQuery: Sendable {
    public var limit: Int
    public var kind: ClipboardKind?
    public var before: Date?

    public init(limit: Int = 50, kind: ClipboardKind? = nil, before: Date? = nil) {
        self.limit = max(1, min(limit, 200))
        self.kind = kind
        self.before = before
    }
}

public struct HistoryPage: Sendable {
    public let items: [ClipboardItem]
    public let nextCursor: Date?

    public init(items: [ClipboardItem], nextCursor: Date?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct Pinboard: Identifiable, Codable, Hashable, Sendable {
    public static let usefulLinksID = UUID(uuidString: "B044167B-0C25-4B11-9B68-65FBF63B74CC")!

    public let id: UUID
    public var name: String
    public var color: String
    public var symbol: String
    public var sortIndex: Int
    public var isSystem: Bool
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        color: String = "cyan",
        symbol: String = "pin.fill",
        sortIndex: Int = 0,
        isSystem: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.symbol = symbol
        self.sortIndex = sortIndex
        self.isSystem = isSystem
        self.createdAt = createdAt
    }
}
