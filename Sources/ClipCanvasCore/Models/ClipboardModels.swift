import Foundation

public enum ClipboardKind: String, Codable, CaseIterable, Sendable {
    case text
    case richText
    case image
    case link
    case files
    case unknown
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
