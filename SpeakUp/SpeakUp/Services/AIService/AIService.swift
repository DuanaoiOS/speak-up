import Foundation

enum AIProvider: String {
    case claude
    case openai
}

struct AIConfig {
    let provider: AIProvider
    let apiKey: String
    let model: String
    let baseUrl: String?
}

struct ChatMessage {
    let role: String
    let content: String
}

protocol AIService {
    func streamChat(
        messages: [ChatMessage],
        systemPrompt: String,
        config: AIConfig
    ) -> AsyncThrowingStream<String, Error>

    func generateContent(
        systemPrompt: String,
        userPrompt: String,
        config: AIConfig
    ) async throws -> String

    func getFeedback(
        systemPrompt: String,
        userPrompt: String,
        config: AIConfig
    ) async throws -> String
}

enum AIServiceFactory {
    static func make(provider: AIProvider) -> AIService {
        switch provider {
        case .claude: return ClaudeClient()
        case .openai: return OpenAIClient()
        }
    }
}
