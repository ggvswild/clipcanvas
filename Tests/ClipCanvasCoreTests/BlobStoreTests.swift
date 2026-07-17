import Foundation
import XCTest
@testable import ClipCanvasCore

final class BlobStoreTests: XCTestCase {
    func testEqualDataUsesSameContentAddress() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try BlobStore(rootURL: root)
        let data = Data("clipcanvas-image".utf8)

        let first = try store.put(data, fileExtension: "png")
        let second = try store.put(data, fileExtension: "png")

        XCTAssertEqual(first, second)
        XCTAssertEqual(try store.data(for: first), data)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url(for: first).path))
    }
}
