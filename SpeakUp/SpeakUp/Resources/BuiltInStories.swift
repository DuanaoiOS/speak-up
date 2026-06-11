import Foundation

enum BuiltInStories {
    static let all: [StoryModel] = allStories

    private static let allStories: [StoryModel] = {
        let decoder = JSONDecoder()
        guard let url = Bundle.main.url(forResource: "builtin_stories", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let stories = try? decoder.decode([StoryJSON].self, from: data) else {
            print("Warning: Could not load builtin_stories.json, using empty array")
            return []
        }
        return stories.enumerated().map { index, s in
            let createdAt = Date.now.addingTimeInterval(TimeInterval(-index * 3600 * 24))
            return StoryModel(
                id: "builtin-\(index + 1)",
                title: s.title,
                content: s.content,
                source: s.source,
                createdAt: createdAt,
                vocabulary: s.vocabulary.map { VocabWord(word: $0.word, context: $0.context, definition: $0.definition, exampleSentence: $0.exampleSentence) },
                patterns: s.patterns.map { SentencePattern(pattern: $0.pattern, fromStory: $0.fromStory, explanation: $0.explanation, practicePrompts: $0.practicePrompts) },
                keywords: s.keywords,
                quiz: s.quiz.map { QuizQuestion(type: $0.type, question: $0.question, options: $0.options, correctIndex: $0.correctIndex, explanation: $0.explanation) }
            )
        }
    }()
}

// MARK: - JSON Decoding Types

private struct StoryJSON: Codable {
    let title: String
    let content: String
    let source: String
    let vocabulary: [VocabJSON]
    let patterns: [PatternJSON]
    let keywords: [String]
    let quiz: [QuizJSON]

    struct VocabJSON: Codable {
        let word: String
        let context: String
        let definition: String
        let exampleSentence: String
    }

    struct PatternJSON: Codable {
        let pattern: String
        let fromStory: String
        let explanation: String
        let practicePrompts: [String]
    }

    struct QuizJSON: Codable {
        let type: String
        let question: String
        let options: [String]
        let correctIndex: Int
        let explanation: String
    }
}
