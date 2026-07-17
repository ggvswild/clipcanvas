import Foundation

@main
struct ClipCanvasMCPBridge {
    static func main() async {
        guard let token = ProcessInfo.processInfo.environment["CLIPCANVAS_TOKEN"],
              !token.isEmpty else {
            diagnostic("CLIPCANVAS_TOKEN is required")
            Foundation.exit(64)
        }
        guard let endpoint = URL(string: "http://127.0.0.1:49219/mcp") else {
            diagnostic("Unable to create local MCP endpoint")
            Foundation.exit(70)
        }

        while let line = readLine(strippingNewline: true) {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            guard let body = line.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: body)) != nil else {
                print(errorResponse(id: nil, code: -32700, message: "Parse error"))
                continue
            }
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("http://localhost", forHTTPHeaderField: "Origin")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 200,
                      (try? JSONSerialization.jsonObject(with: data)) != nil else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    print(errorResponse(
                        id: requestIdentifier(body),
                        code: -32000,
                        message: "ClipCanvas MCP HTTP error \(status)"
                    ))
                    continue
                }
                print(String(decoding: data, as: UTF8.self))
            } catch {
                diagnostic(error.localizedDescription)
                print(errorResponse(
                    id: requestIdentifier(body),
                    code: -32000,
                    message: "ClipCanvas MCP is unavailable"
                ))
            }
        }
    }

    private static func requestIdentifier(_ data: Data) -> Any? {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["id"]
    }

    private static func errorResponse(id: Any?, code: Int, message: String) -> String {
        let object: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "error": ["code": code, "message": message]
        ]
        let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return data.map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    private static func diagnostic(_ text: String) {
        FileHandle.standardError.write(Data("[clipcanvas-mcp] \(text)\n".utf8))
    }
}
