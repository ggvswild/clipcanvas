import ClipCanvasCore
import Darwin
import Foundation

guard CommandLine.arguments.count == 2
        || (
            CommandLine.arguments.count == 4
                && CommandLine.arguments[2] == "--destination"
        ) else {
    fputs(
        "usage: clipcanvas-import-paste <Paste export directory> [--destination <directory>]\n",
        stderr
    )
    exit(64)
}

do {
    let exportDirectory = URL(
        fileURLWithPath: CommandLine.arguments[1],
        isDirectory: true
    )
    let destination: URL
    if CommandLine.arguments.count == 4 {
        destination = URL(
            fileURLWithPath: CommandLine.arguments[3],
            isDirectory: true
        )
    } else {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        destination = applicationSupport
            .appendingPathComponent("ClipCanvas", isDirectory: true)
    }
    try FileManager.default.createDirectory(
        at: destination,
        withIntermediateDirectories: true
    )

    let repository = ClipboardRepository(
        database: try SQLiteDatabase(
            url: destination.appendingPathComponent("clipcanvas.sqlite3")
        ),
        blobStore: try BlobStore(
            rootURL: destination.appendingPathComponent("blobs")
        )
    )
    let summary = try PastePinboardImporter(repository: repository)
        .importDirectory(exportDirectory)

    print("Pinboards: \(summary.pinboardsProcessed)")
    print("Items: \(summary.itemsProcessed)")
    print("Images: \(summary.imagesRecovered)")
} catch {
    fputs("Paste import failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
