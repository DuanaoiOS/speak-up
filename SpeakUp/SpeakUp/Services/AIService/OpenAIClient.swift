import Foundation

struct OpenAIClient: AIService {
    func streamChat(
        messages: [ChatMessage],
        systemPrompt: String,
        config: AIConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let base = (config.baseUrl ?? "https://api.openai.com/v1").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    guard let url = URL(string: "\(base)/chat/completions") else {
                        continuation.finish(throwing: NSError(domain: "OpenAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

                    let allMessages: [[String: String]] = [
                        ["role": "system", "content": systemPrompt]
                    ] + messages.map { ["role": $0.role == "assistant" ? "assistant" : "user", "content": $0.content] }

                    let body: [String: Any] = [
                        "model": config.model,
                        "messages": allMessages,
                        "max_tokens": 1024,
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: NSError(domain: "OpenAI", code: (response as? HTTPURLResponse)?.statusCode ?? 500))
                        return
                    }

                    var buffer = ""
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let dataStr = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        if dataStr == "[DONE]" { continue }
                        guard let data = dataStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String else { continue }
                        continuation.yield(content)
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
        let base = (config.baseUrl ?? "https://api.openai.com/v1").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/chat/completions") else {
            throw NSError(domain: "OpenAI", code: 1)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 4096,
            "temperature": 0.7
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenAI", code: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "OpenAI", code: 2)
        }
        return content
    }

    func getFeedback(
        systemPrompt: String,
        userPrompt: String,
        config: AIConfig
    ) async throws -> String {
        return try await generateContent(systemPrompt: systemPrompt, userPrompt: userPrompt, config: config)
    }
}
