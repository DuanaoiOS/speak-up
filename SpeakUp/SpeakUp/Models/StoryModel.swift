import Foundation
import SwiftData

// Codable sub-types (stored as JSON in StoryModel)
struct VocabWord: Codable, Identifiable {
    var id: String { word }
    let word: String
    let context: String
    let definition: String
    let exampleSentence: String
}

struct SentencePattern: Codable, Identifiable {
    var id: String { pattern }
    let pattern: String
    let fromStory: String
    let explanation: String
    let practicePrompts: [String]
}

struct QuizQuestion: Codable, Identifiable {
    var id: String { question }
    let type: String  // "comprehension" | "vocabulary" | "fill-blank"
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

@Model
final class StoryModel {
    @Attribute(.unique) var id: String
    var title: String
    var content: String
    var source: String
    var imageUrl: String?
    var audioUrl: String?
    var createdAt: Date
    var week: Int
    var level: Int       // 1-5 within a week
    var theme: String    // weekly theme in Chinese

    // JSON-encoded arrays
    @Attribute(.externalStorage) var vocabularyJSON: Data?
    @Attribute(.externalStorage) var patternsJSON: Data?
    @Attribute(.externalStorage) var keywordsJSON: Data?
    @Attribute(.externalStorage) var quizJSON: Data?

    init(id: String, title: String, content: String, source: String,
         imageUrl: String? = nil, audioUrl: String? = nil, createdAt: Date = .now,
         week: Int = 1, level: Int = 1, theme: String = "",
         vocabulary: [VocabWord] = [], patterns: [SentencePattern] = [],
         keywords: [String] = [], quiz: [QuizQuestion] = []) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.imageUrl = imageUrl
        self.audioUrl = audioUrl
        self.createdAt = createdAt
        self.week = week
        self.level = level
        self.theme = theme
        self.vocabularyJSON = Self.encode(vocabulary)
        self.patternsJSON = Self.encode(patterns)
        self.keywordsJSON = Self.encode(keywords)
        self.quizJSON = Self.encode(quiz)
    }

    // MARK: Computed accessors
    var vocabulary: [VocabWord] {
        get { Self.decode(vocabularyJSON) ?? [] }
        set { vocabularyJSON = Self.encode(newValue) }
    }

    var patterns: [SentencePattern] {
        get { Self.decode(patternsJSON) ?? [] }
        set { patternsJSON = Self.encode(newValue) }
    }

    var keywords: [String] {
        get { Self.decode(keywordsJSON) ?? [] }
        set { keywordsJSON = Self.encode(newValue) }
    }

    var quiz: [QuizQuestion] {
        get { Self.decode(quizJSON) ?? [] }
        set { quizJSON = Self.encode(newValue) }
    }

    private static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private static func decode<T: Decodable>(_ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
