import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class HomeViewModel {
    var stories: [StoryModel] = []
    var isGenerating: Bool = false
    var error: String?
    var isLoading: Bool = true

    private let dataService = DataService.shared
    private var modelContext: ModelContext { dataService.modelContext }

    func loadStories() {
        isLoading = true
        do {
            // Import built-in stories on first launch
            try StoryImporter.importIfNeeded(context: modelContext)
            stories = try dataService.fetchAllStories()
        } catch {
            self.error = "加载失败"
        }
        isLoading = false
    }

    func generateStory(provider: AIProvider, apiKey: String, model: String, baseUrl: String?) {
        guard !apiKey.isEmpty else {
            error = "请先在设置中配置 API Key"
            return
        }

        isGenerating = true
        error = nil

        let config = AIConfig(provider: provider, apiKey: apiKey, model: model, baseUrl: baseUrl)
        let service = AIServiceFactory.make(provider: provider)

        Task {
            do {
                let raw = try await service.generateContent(
                    systemPrompt: AIPrompts.honyStoryPrompt,
                    userPrompt: "Generate a new HONY-style story.",
                    config: config
                )

                // Extract JSON from response
                guard let jsonStart = raw.firstIndex(of: "{"),
                      let jsonEnd = raw.lastIndex(of: "}") else {
                    throw NSError(domain: "Parse", code: 1, userInfo: [NSLocalizedDescriptionKey: "No JSON found in response"])
                }

                let jsonStr = String(raw[jsonStart...jsonEnd])
                guard let jsonData = jsonStr.data(using: .utf8),
                      let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    throw NSError(domain: "Parse", code: 2)
                }

                await MainActor.run {
                    createStory(from: dict)
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.error = "生成失败，请重试"
                    self.isGenerating = false
                }
            }
        }
    }

    private func createStory(from dict: [String: Any]) {
        let vocabData = (dict["vocabulary"] as? [[String: Any]])?.map { v in
            VocabWord(
                word: v["word"] as? String ?? "",
                context: v["context"] as? String ?? "",
                definition: v["definition"] as? String ?? "",
                exampleSentence: v["exampleSentence"] as? String ?? ""
            )
        } ?? []

        let patternData = (dict["patterns"] as? [[String: Any]])?.map { p in
            SentencePattern(
                pattern: p["pattern"] as? String ?? "",
                fromStory: p["fromStory"] as? String ?? "",
                explanation: p["explanation"] as? String ?? "",
                practicePrompts: p["practicePrompts"] as? [String] ?? []
            )
        } ?? []

        let keywords = dict["keywords"] as? [String] ?? []

        let quizData = (dict["quiz"] as? [[String: Any]])?.map { q in
            QuizQuestion(
                type: q["type"] as? String ?? "comprehension",
                question: q["question"] as? String ?? "",
                options: q["options"] as? [String] ?? [],
                correctIndex: q["correctIndex"] as? Int ?? 0,
                explanation: q["explanation"] as? String ?? ""
            )
        } ?? []

        let story = StoryModel(
            id: UUID().uuidString,
            title: dict["title"] as? String ?? "Untitled Story",
            content: dict["content"] as? String ?? "",
            source: dict["source"] as? String ?? "AI-generated",
            vocabulary: vocabData,
            patterns: patternData,
            keywords: keywords,
            quiz: quizData
        )

        dataService.modelContext.insert(story)
        try? dataService.modelContext.save()
        stories.insert(story, at: 0)
    }
}
