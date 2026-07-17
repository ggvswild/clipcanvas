import AppKit
import ClipCanvasCore
import Foundation
import UniformTypeIdentifiers

struct PasteboardSnapshotReader {
    func read(
        from pasteboard: NSPasteboard,
        source: ClipboardSource,
        capturedAt: Date = Date()
    ) -> ClipboardDraft? {
        if let files = fileURLs(from: pasteboard), !files.isEmpty {
            let encoded = try? JSONEncoder().encode(files.map(\.absoluteString))
            return ClipboardDraft(
                kind: .files,
                plainText: files.map(\.path).joined(separator: "\n"),
                source: source,
                capturedAt: capturedAt,
                metadata: ClipboardMetadata(
                    fileCount: files.count,
                    fileNames: files.map(\.lastPathComponent)
                ),
                representations: encoded.map {
                    [
                        ClipboardRepresentationDraft(
                            uti: NSPasteboard.PasteboardType.fileURL.rawValue,
                            data: $0,
                            fileExtension: "json"
                        )
                    ]
                } ?? []
            )
        }

        if let image = imageRepresentation(from: pasteboard) {
            return ClipboardDraft(
                kind: .image,
                source: source,
                capturedAt: capturedAt,
                metadata: ClipboardMetadata(
                    imageWidth: image.width,
                    imageHeight: image.height,
                    byteCount: image.data.count
                ),
                representations: [
                    ClipboardRepresentationDraft(
                        uti: image.type.rawValue,
                        data: image.data,
                        fileExtension: image.fileExtension
                    )
                ]
            )
        }

        let plainText = pasteboard.string(forType: .string)
        let richRepresentations = richTextRepresentations(from: pasteboard)
        if !richRepresentations.isEmpty {
            return ClipboardDraft(
                kind: .richText,
                plainText: plainText ?? plainTextFallback(from: richRepresentations),
                source: source,
                capturedAt: capturedAt,
                representations: richRepresentations
            )
        }

        if let url = webURL(from: pasteboard, fallback: plainText) {
            return ClipboardDraft(
                kind: .link,
                plainText: url.absoluteString,
                title: url.host(),
                source: source,
                capturedAt: capturedAt,
                metadata: ClipboardMetadata(domain: url.host()),
                representations: [
                    ClipboardRepresentationDraft(
                        uti: NSPasteboard.PasteboardType.URL.rawValue,
                        data: Data(url.absoluteString.utf8)
                    )
                ]
            )
        }

        if let plainText, !plainText.isEmpty {
            return ClipboardDraft(
                kind: .text,
                plainText: plainText,
                source: source,
                capturedAt: capturedAt,
                metadata: ClipboardMetadata(byteCount: plainText.utf8.count),
                representations: [
                    ClipboardRepresentationDraft(
                        uti: NSPasteboard.PasteboardType.string.rawValue,
                        data: Data(plainText.utf8)
                    )
                ]
            )
        }

        return unknownRepresentation(from: pasteboard, source: source, capturedAt: capturedAt)
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )?.compactMap { value in
            (value as? NSURL).flatMap { $0 as URL }
        }
    }

    private func webURL(from pasteboard: NSPasteboard, fallback: String?) -> URL? {
        if let values = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: false]
        ) as? [NSURL],
           let url = values.compactMap({ $0 as URL }).first(where: { !$0.isFileURL }) {
            return url
        }
        guard let fallback,
              let url = URL(string: fallback),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }

    private func richTextRepresentations(from pasteboard: NSPasteboard) -> [ClipboardRepresentationDraft] {
        [NSPasteboard.PasteboardType.html, .rtf, .rtfd].compactMap { type in
            pasteboard.data(forType: type).map {
                ClipboardRepresentationDraft(uti: type.rawValue, data: $0)
            }
        }
    }

    private func plainTextFallback(from representations: [ClipboardRepresentationDraft]) -> String? {
        for representation in representations {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any]
            switch representation.uti {
            case NSPasteboard.PasteboardType.html.rawValue:
                options = [.documentType: NSAttributedString.DocumentType.html]
            case NSPasteboard.PasteboardType.rtf.rawValue:
                options = [.documentType: NSAttributedString.DocumentType.rtf]
            case NSPasteboard.PasteboardType.rtfd.rawValue:
                options = [.documentType: NSAttributedString.DocumentType.rtfd]
            default:
                continue
            }
            if let attributed = try? NSAttributedString(
                data: representation.data,
                options: options,
                documentAttributes: nil
            ) {
                return attributed.string
            }
        }
        return nil
    }

    private func imageRepresentation(
        from pasteboard: NSPasteboard
    ) -> (type: NSPasteboard.PasteboardType, data: Data, fileExtension: String, width: Int, height: Int)? {
        for (type, fileExtension) in [
            (NSPasteboard.PasteboardType.png, "png"),
            (.tiff, "tiff")
        ] {
            guard let data = pasteboard.data(forType: type),
                  let image = NSBitmapImageRep(data: data) else {
                continue
            }
            return (type, data, fileExtension, image.pixelsWide, image.pixelsHigh)
        }
        return nil
    }

    private func unknownRepresentation(
        from pasteboard: NSPasteboard,
        source: ClipboardSource,
        capturedAt: Date
    ) -> ClipboardDraft? {
        guard let type = pasteboard.types?.first,
              let data = pasteboard.data(forType: type),
              data.count <= 2 * 1_024 * 1_024 else {
            return nil
        }
        return ClipboardDraft(
            kind: .unknown,
            source: source,
            capturedAt: capturedAt,
            metadata: ClipboardMetadata(byteCount: data.count),
            representations: [
                ClipboardRepresentationDraft(uti: type.rawValue, data: data)
            ]
        )
    }
}
