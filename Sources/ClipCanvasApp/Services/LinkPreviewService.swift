import Foundation

struct LinkPreview: Sendable, Equatable {
    let title: String
}

enum LinkPreviewError: Error {
    case invalidResponse
    case contentTooLarge
    case missingTitle
}

actor LinkPreviewService {
    typealias FetchData = @Sendable (URL) async throws -> Data

    private let fetchData: FetchData
    private var cache: [URL: LinkPreview] = [:]

    init(fetchData: @escaping FetchData = LinkPreviewService.networkFetch) {
        self.fetchData = fetchData
    }

    func preview(for url: URL) async throws -> LinkPreview {
        if let cached = cache[url] {
            return cached
        }
        let data = try await fetchData(url)
        guard data.count <= 1_000_000 else {
            throw LinkPreviewError.contentTooLarge
        }
        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1),
              let title = Self.extractTitle(from: html) else {
            throw LinkPreviewError.missingTitle
        }
        let preview = LinkPreview(title: title)
        cache[url] = preview
        return preview
    }

    private static func networkFetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue(
            "Mozilla/5.0 (Macintosh; ClipCanvas/0.1) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<400).contains(response.statusCode) else {
            throw LinkPreviewError.invalidResponse
        }
        return data
    }

    private static func extractTitle(from html: String) -> String? {
        let patterns = [
            #"<meta\b[^>]*\bproperty\s*=\s*["']og:title["'][^>]*\bcontent\s*=\s*["']([^"']+)["'][^>]*>"#,
            #"<meta\b[^>]*\bcontent\s*=\s*["']([^"']+)["'][^>]*\bproperty\s*=\s*["']og:title["'][^>]*>"#,
            #"<title\b[^>]*>(.*?)</title>"#
        ]
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) else {
                continue
            }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = expression.firstMatch(in: html, range: range),
                  let captureRange = Range(match.range(at: 1), in: html) else {
                continue
            }
            let value = decodeHTMLEntities(
                String(html[captureRange])
                    .replacingOccurrences(
                        of: #"<[^>]+>"#,
                        with: "",
                        options: .regularExpression
                    )
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
            if !value.isEmpty {
                return String(value.prefix(300))
            }
        }
        return nil
    }

    private static func decodeHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
