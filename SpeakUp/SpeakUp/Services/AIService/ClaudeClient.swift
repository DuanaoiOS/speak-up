import Foundation

struct ClaudeClient: AIService {
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"

    func streamChat(
        messages: [ChatMessage],
        systemPrompt: String,
        config: AIConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: URL(string: baseURL)!)
                    request.httpMethod = "POST"
                    request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
                    request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body: [String: Any] = [
                        "model": config.model,
                        "max_tokens": 1024,
                        "system": systemPrompt,
                        "messages": messages.map { ["role": $0.role == "assistant" ? "assistant" : "user", "content": $0.content] },
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: NSError(domain: "Claude", code: (response as? HTTPURLResponse)?.statusCode ?? 500))
                        return
                    }

                    var buffer = ""
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let dataStr = String(line.dropFirst(6))
                        if dataStr == "[DONE]" { continue }
                        guard let data = dataStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                        if let type = json["type"] as? String, type == "content_block_delta",
                           let delta = json["delta"] as? [String: Any],
                           let text = delta["text"] as? String {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func generateContent(
        systemPrompt: String,
        userPrompt: String,
        config: AIConfig
    ) async throws -> String {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userPrompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Claude", code: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw NSError(domain: "Claude", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }

        return content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
    }

    func getFeedback(
        systemPrompt: String,
        userPrompt: String,
        config: AIConfig
    ) async throws -> String {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userPrompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Claude", code: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw NSError(domain: "Claude", code: 2)
        }

        return content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
    }
}
