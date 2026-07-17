import CryptoKit
import Foundation

public final class BlobStore: @unchecked Sendable {
    public let rootURL: URL

    public init(rootURL: URL) throws {
        self.rootURL = rootURL
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
    }

    public func put(_ data: Data, fileExtension: String?) throws -> BlobReference {
        let digest = SHA256.hash(data: data).hexString
        let first = String(digest.prefix(2))
        let second = String(digest.dropFirst(2).prefix(2))
        let normalizedExtension = fileExtension?
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .lowercased()
        let fileName = normalizedExtension.flatMap { $0.isEmpty ? nil : "\(digest).\($0)" } ?? digest
        let relativePath = "\(first)/\(second)/\(fileName)"
        let destination = rootURL.appendingPathComponent(relativePath)

        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: destination, options: .atomic)
        }

        return BlobReference(
            digest: digest,
            relativePath: relativePath,
            byteCount: data.count
        )
    }

    public func url(for reference: BlobReference) -> URL {
        rootURL.appendingPathComponent(reference.relativePath)
    }

    public func data(for reference: BlobReference) throws -> Data {
        try Data(contentsOf: url(for: reference), options: .mappedIfSafe)
    }

    public func remove(_ reference: BlobReference) throws {
        let fileURL = url(for: reference)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
