import Foundation
import SwiftData

@MainActor
final class DataService {
    static let shared = DataService()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            StoryModel.self,
            StoryProgressModel.self,
            ChatConversationModel.self,
            ChatMessageModel.self,
            ReviewItemModel.self,
            ProgressDataModel.self,
            SettingsModel.self,
        ])

        do {
            container = try ModelContainer(for: schema)
        } catch {
            // Schema migration failed — delete old store and recreate
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
            do {
                container = try ModelContainer(for: schema)
            } catch {
                fatalError("Failed to create ModelContainer after cleanup: \(error)")
            }
        }
    }

    var modelContext: ModelContext { container.mainContext }

    // MARK: Settings

    func getSettings() throws -> SettingsModel {
        let descriptor = FetchDescriptor<SettingsModel>()
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let settings = SettingsModel()
        modelContext.insert(settings)
        try modelContext.save()
        return settings
    }

    func updateSettings(_ update: (SettingsModel) -> Void) throws {
        let settings = try getSettings()
        update(settings)
        try modelContext.save()
    }

    // MARK: Stories

    func storiesForWeek(_ week: Int) -> [StoryModel] {
        var descriptor = FetchDescriptor<StoryModel>(
            sortBy: [SortDescriptor(\.level)]
        )
        descriptor.predicate = #Predicate { $0.week == week }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchAllStories() throws -> [StoryModel] {
        var descriptor = FetchDescriptor<StoryModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func storyCount() throws -> Int {
        var descriptor = FetchDescriptor<StoryModel>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).isEmpty ? 0 : 1
    }

    // MARK: Progress

    func getProgress() throws -> ProgressDataModel {
        var descriptor = FetchDescriptor<ProgressDataModel>()
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let progress = ProgressDataModel()
        modelContext.insert(progress)
        try modelContext.save()
        return progress
    }

    func updateProgress(_ update: (ProgressDataModel) -> Void) throws {
        let progress = try getProgress()
        update(progress)
        try modelContext.save()
    }

    // MARK: Review Items

    func fetchReviewItems(filter: String? = nil) throws -> [ReviewItemModel] {
        var descriptor = FetchDescriptor<ReviewItemModel>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        if let filter, filter != "all" {
            descriptor.predicate = #Predicate { $0.type == filter }
        }
        return try modelContext.fetch(descriptor)
    }

    func addReviewItem(type: String, content: String, definition: String,
                       exampleSentence: String, storyTitle: String, storyId: String) throws {
        // Avoid duplicates
        var descriptor = FetchDescriptor<ReviewItemModel>()
        descriptor.predicate = #Predicate { $0.content == content && $0.storyId == storyId }
        if try !modelContext.fetch(descriptor).isEmpty { return }

        let item = ReviewItemModel(
            type: type, content: content, definition: definition,
            exampleSentence: exampleSentence, storyTitle: storyTitle, storyId: storyId
        )
        modelContext.insert(item)
        try modelContext.save()
    }

    // MARK: Chat

    func fetchConversation(roleId: String) throws -> ChatConversationModel? {
        var descriptor = FetchDescriptor<ChatConversationModel>()
        descriptor.predicate = #Predicate { $0.roleId == roleId }
        return try modelContext.fetch(descriptor).first
    }

    func fetchAllConversations() throws -> [ChatConversationModel] {
        return try modelContext.fetch(FetchDescriptor<ChatConversationModel>())
    }

    // MARK: Export

    func exportAllData() throws -> String {
        var data: [String: Any] = [:]

        // Stories
        let stories = try fetchAllStories()
        let storyDicts = stories.map { story -> [String: Any] in
            [
                "id": story.id, "title": story.title, "content": story.content,
                "source": story.source, "vocabulary": story.vocabulary.map { v in
                    ["word": v.word, "context": v.context, "definition": v.definition, "exampleSentence": v.exampleSentence]
                },
                "patterns": story.patterns.map { p in
                    ["pattern": p.pattern, "fromStory": p.fromStory, "explanation": p.explanation, "practicePrompts": p.practicePrompts]
                },
                "keywords": story.keywords,
                "quiz": story.quiz.map { q in
                    ["type": q.type, "question": q.question, "options": q.options, "correctIndex": q.correctIndex, "explanation": q.explanation]
                },
                "createdAt": story.createdAt.timeIntervalSince1970
            ]
        }
        data["stories"] = storyDicts

        // Review items
        let items = try fetchReviewItems()
        data["reviewItems"] = items.map { item in
            [
                "id": item.id, "type": item.type, "content": item.content,
                "definition": item.definition, "exampleSentence": item.exampleSentence,
                "storyTitle": item.storyTitle, "storyId": item.storyId,
                "reviewCount": item.reviewCount, "mastered": item.mastered
            ]
        }

        // Chat conversations
        let convs = try fetchAllConversations()
        data["conversations"] = convs.map { conv in
            [
                "roleId": conv.roleId,
                "messages": (conv.messages ?? []).map { msg in
                    ["id": msg.id, "role": msg.role, "content": msg.content, "timestamp": msg.timestamp.timeIntervalSince1970, "isVoice": msg.isVoice]
                }
            ]
        }

        // Progress
        let progress = try getProgress()
        data["progress"] = [
            "currentStreak": progress.currentStreak,
            "longestStreak": progress.longestStreak,
            "completedDates": progress.completedDates,
            "totalSessions": progress.totalSessions,
            "totalMinutes": progress.totalMinutes,
            "topicsCovered": progress.topicsCovered
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    func importAllData(from jsonString: String) throws {
        guard let jsonData = jsonString.data(using: .utf8),
              let data = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw NSError(domain: "DataService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }
        // Stories
        if let storyDicts = data["stories"] as? [[String: Any]] {
            for dict in storyDicts {
                let story = StoryModel(
                    id: dict["id"] as? String ?? UUID().uuidString,
                    title: dict["title"] as? String ?? "",
                    content: dict["content"] as? String ?? "",
                    source: dict["source"] as? String ?? "",
                    createdAt: Date(timeIntervalSince1970: dict["createdAt"] as? TimeInterval ?? 0)
                )
                // Decode sub-arrays
                if let vocab = dict["vocabulary"] as? [[String: String]] {
                    story.vocabularyJSON = try? JSONEncoder().encode(vocab.map { v in
                        VocabWord(word: v["word"] ?? "", context: v["context"] ?? "",
                                  definition: v["definition"] ?? "", exampleSentence: v["exampleSentence"] ?? "")
                    })
                }
                if let patterns = dict["patterns"] as? [[String: Any]] {
                    story.patternsJSON = try? JSONEncoder().encode(patterns.map { p in
                        SentencePattern(
                            pattern: p["pattern"] as? String ?? "",
                            fromStory: p["fromStory"] as? String ?? "",
                            explanation: p["explanation"] as? String ?? "",
                            practicePrompts: p["practicePrompts"] as? [String] ?? []
                        )
                    })
                }
                if let keywords = dict["keywords"] as? [String] {
                    story.keywordsJSON = try? JSONEncoder().encode(keywords)
                }
                if let quiz = dict["quiz"] as? [[String: Any]] {
                    story.quizJSON = try? JSONEncoder().encode(quiz.map { q in
                        QuizQuestion(
                            type: q["type"] as? String ?? "comprehension",
                            question: q["question"] as? String ?? "",
                            options: q["options"] as? [String] ?? [],
                            correctIndex: q["correctIndex"] as? Int ?? 0,
                            explanation: q["explanation"] as? String ?? ""
                        )
                    })
                }
                modelContext.insert(story)
            }
        }
        try modelContext.save()
    }
}
