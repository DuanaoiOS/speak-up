import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class HomeViewModel {
    var currentWeek: Int = 1
    var weekStories: [StoryModel] = []
    var allProgress: [StoryProgressModel] = []
    var isGenerating: Bool = false
    var error: String?
    var isLoading: Bool = true

    private let dataService = DataService.shared
    private var modelContext: ModelContext { dataService.modelContext }

    // MARK: - Computed

    var maxCompletedWeek: Int {
        guard !allWeeks().isEmpty else { return 0 }
        for week in allWeeks().sorted(by: >) {
            let weekStories = dataService.storiesForWeek(week)
            guard weekStories.count == 5 else { continue }
            let allDone = weekStories.allSatisfy { story in
                allProgress.first(where: { $0.storyId == story.id })?.completedSteps.allSatisfy({ $0 }) ?? false
            }
            if allDone { return week }
        }
        return 0
    }

    var maxUnlockedWeek: Int {
        let completed = maxCompletedWeek
        if completed < allWeeks().max() ?? 0 {
            return completed + 1
        }
        return max(1, completed)
    }

    var weekTheme: String {
        weekStories.first?.theme ?? ""
    }

    var weekProgress: (completed: Int, total: Int) {
        guard weekStories.count == 5 else { return (0, 5) }
        let done = weekStories.filter { story in
            allProgress.first(where: { $0.storyId == story.id })?.completedSteps.allSatisfy({ $0 }) ?? false
        }.count
        return (done, 5)
    }

    var canAdvanceWeek: Bool {
        currentWeek < maxUnlockedWeek
    }

    var canGoBackWeek: Bool {
        currentWeek > 1
    }

    /// The next uncompleted level index (0-based), or nil if all done
    var nextLevelIndex: Int? {
        for (i, story) in weekStories.enumerated() {
            let done = allProgress.first(where: { $0.storyId == story.id })?.completedSteps.allSatisfy({ $0 }) ?? false
            if !done { return i }
        }
        return nil
    }

    func isLevelUnlocked(_ index: Int) -> Bool {
        guard currentWeek <= maxUnlockedWeek else { return false }
        if index == 0 { return true }
        let prev = weekStories[index - 1]
        return allProgress.first(where: { $0.storyId == prev.id })?.completedSteps.allSatisfy({ $0 }) ?? false
    }

    func isLevelCompleted(_ index: Int) -> Bool {
        guard index < weekStories.count else { return false }
        let story = weekStories[index]
        return allProgress.first(where: { $0.storyId == story.id })?.completedSteps.allSatisfy({ $0 }) ?? false
    }

    // MARK: - Actions

    func load() {
        isLoading = true
        do {
            try StoryImporter.importIfNeeded(context: modelContext)
            loadWeek(1)
            refreshProgress()
        } catch _ {
            self.error = "加载失败"
        }
        isLoading = false
    }

    func loadWeek(_ week: Int) {
        currentWeek = week
        weekStories = dataService.storiesForWeek(week)
        refreshProgress()
    }

    func advanceWeek() {
        guard canAdvanceWeek else { return }
        loadWeek(currentWeek + 1)
    }

    func goBackWeek() {
        guard canGoBackWeek else { return }
        loadWeek(currentWeek - 1)
    }

    func refreshProgress() {
        var descriptor = FetchDescriptor<StoryProgressModel>()
        descriptor.fetchLimit = 500
        allProgress = (try? modelContext.fetch(descriptor)) ?? []
    }

    /// AI-generate 5 stories for a new week
    func generateWeek(provider: AIProvider, apiKey: String, model: String, baseUrl: String?, theme: String) {
        guard !apiKey.isEmpty else { error = "请先配置 API Key"; return }
        isGenerating = true; error = nil

        let config = AIConfig(provider: provider, apiKey: apiKey, model: model, baseUrl: baseUrl)
        let service = AIServiceFactory.make(provider: provider)
        let nextWeek = allWeeks().isEmpty ? 1 : (allWeeks().max() ?? 0) + 1

        let prompt = """
        Generate 5 short personal stories in the HONY style, all centered around the weekly theme: "\(theme)".
        Return a JSON array of exactly 5 story objects. Each story object has:
        { "title": ..., "content": ..., "source": "AI-generated", "vocabulary": [...], "patterns": [...], "keywords": [...], "quiz": [...] }
        Follow the exact same format as before. Each story 180-300 words.
        """

        Task {
            do {
                let raw = try await service.generateContent(
                    systemPrompt: AIPrompts.honyStoryPrompt,
                    userPrompt: prompt, config: config
                )
                // Extract JSON array
                guard let jsonStart = raw.firstIndex(of: "["),
                      let jsonEnd = raw.lastIndex(of: "]") else {
                    throw NSError(domain: "Parse", code: 1)
                }
                let jsonStr = String(raw[jsonStart...jsonEnd])
                guard let jsonData = jsonStr.data(using: .utf8),
                      let arr = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
                    throw NSError(domain: "Parse", code: 2)
                }

                await MainActor.run {
                    for (i, dict) in arr.prefix(5).enumerated() {
                        createStory(from: dict, week: nextWeek, level: i + 1, theme: theme)
                    }
                    try? modelContext.save()
                    loadWeek(nextWeek)
                    isGenerating = false
                }
            } catch _ {
                await MainActor.run {
                    self.error = "生成失败，请重试"
                    isGenerating = false
                }
            }
        }
    }

    private func allWeeks() -> [Int] {
        let descriptor = FetchDescriptor<StoryModel>(sortBy: [SortDescriptor(\.week)])
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return Array(Set(all.map(\.week))).sorted()
    }

    private func createStory(from dict: [String: Any], week: Int, level: Int, theme: String) {
        let vocabData = (dict["vocabulary"] as? [[String: Any]])?.map { v in
            VocabWord(word: v["word"] as? String ?? "", context: v["context"] as? String ?? "", definition: v["definition"] as? String ?? "", exampleSentence: v["exampleSentence"] as? String ?? "")
        } ?? []

        let patternData = (dict["patterns"] as? [[String: Any]])?.map { p in
            SentencePattern(pattern: p["pattern"] as? String ?? "", fromStory: p["fromStory"] as? String ?? "", explanation: p["explanation"] as? String ?? "", practicePrompts: p["practicePrompts"] as? [String] ?? [])
        } ?? []

        let keywords = dict["keywords"] as? [String] ?? []

        let quizData = (dict["quiz"] as? [[String: Any]])?.map { q in
            QuizQuestion(type: q["type"] as? String ?? "comprehension", question: q["question"] as? String ?? "", options: q["options"] as? [String] ?? [], correctIndex: q["correctIndex"] as? Int ?? 0, explanation: q["explanation"] as? String ?? "")
        } ?? []

        let story = StoryModel(
            id: UUID().uuidString,
            title: dict["title"] as? String ?? "Untitled",
            content: dict["content"] as? String ?? "",
            source: "AI-generated",
            week: week, level: level, theme: theme,
            vocabulary: vocabData, patterns: patternData,
            keywords: keywords, quiz: quizData
        )
        modelContext.insert(story)
    }
}
