import Foundation

struct WordDefinition: Codable {
    let word: String
    let definition: String       // Chinese definition
    let partOfSpeech: String     // e.g. "noun", "verb"
    let exampleSentence: String  // example usage
}

actor DictionaryService {
    static let shared = DictionaryService()
    private var cache: [String: WordDefinition] = [:]

    private init() {}

    /// Look up a word via AI. Returns nil if no API key is configured.
    func lookup(word: String, context: String, config: AIConfig) async throws -> WordDefinition {
        let key = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = cache[key] { return cached }

        let service = AIServiceFactory.make(provider: config.provider)
        let prompt = """
        Explain the word or phrase "\(word)" as it appears in this context: "\(context)"

        Reply in JSON format with these fields:
        {
          "definition": "Chinese definition, concise, suitable for CET-6 learners",
          "partOfSpeech": "noun/verb/adjective/adverb/phrase etc.",
          "exampleSentence": "A simple English example sentence using this word"
        }
        Only return the JSON object, no other text.
        """

        let result = try await service.generateContent(
            systemPrompt: "You are an English-Chinese dictionary for Chinese CET-6 learners. Always reply with valid JSON only.",
            userPrompt: prompt,
            config: config
        )

        let def = try Self.parseResponse(word: word, json: result)
        cache[key] = def
        return def
    }

    private static func parseResponse(word: String, json: String) throws -> WordDefinition {
        // Strip markdown code fences if present
        let cleaned = json
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            return WordDefinition(word: word, definition: "解析失败", partOfSpeech: "", exampleSentence: "")
        }

        let decoded = try JSONDecoder().decode(RawResponse.self, from: data)
        return WordDefinition(
            word: word,
            definition: decoded.definition,
            partOfSpeech: decoded.partOfSpeech,
            exampleSentence: decoded.exampleSentence
        )
    }

    private struct RawResponse: Codable {
        let definition: String
        let partOfSpeech: String
        let exampleSentence: String
    }
}
