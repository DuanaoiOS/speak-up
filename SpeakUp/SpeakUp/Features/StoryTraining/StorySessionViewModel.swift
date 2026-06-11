import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class StorySessionViewModel {
    var currentStep: Int = 0
    var completedSteps: [Bool] = [false, false, false, false, false]
    var quizScore: Int?

    let story: StoryModel
    private let dataService = DataService.shared

    init(story: StoryModel) {
        self.story = story
        loadProgress()
    }

    private func loadProgress() {
        let storyId = story.id
        var descriptor = FetchDescriptor<StoryProgressModel>()
        descriptor.predicate = #Predicate { $0.storyId == storyId }
        if let progress = try? dataService.modelContext.fetch(descriptor).first {
            completedSteps = progress.completedSteps
            quizScore = progress.quizScore
            if let idx = completedSteps.firstIndex(of: false) {
                currentStep = idx
            }
        }
    }

    func completeStep(_ index: Int) {
        completedSteps[index] = true
        saveProgress()

        let storyId = story.id
        var descriptor = FetchDescriptor<StoryProgressModel>()
        descriptor.predicate = #Predicate { $0.storyId == storyId }
        let existing = try? dataService.modelContext.fetch(descriptor).first

        let progress = existing ?? StoryProgressModel(storyId: storyId)
        progress.completedSteps = completedSteps
        if dataService.modelContext.hasChanges {
            try? dataService.modelContext.save()
        }

        // Record session in ProgressData
        if completedSteps.allSatisfy({ $0 }) {
            let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
            let dateStr = String(today)
            try? dataService.updateProgress { p in
                if !p.completedDates.contains(dateStr) {
                    p.completedDates.append(dateStr)
                }
                p.totalSessions += 1
                p.totalMinutes += 20
                if !p.topicsCovered.contains("story") {
                    p.topicsCovered.append("story")
                }
                if !p.topicsCovered.contains(story.title) {
                    p.topicsCovered.append(story.title)
                }
                let (current, longest) = StreakCalculator.calculate(from: p.completedDates)
                p.currentStreak = current
                p.longestStreak = longest
            }
        }
    }

    private func saveProgress() {
        let storyId = story.id
        var descriptor = FetchDescriptor<StoryProgressModel>()
        descriptor.predicate = #Predicate { $0.storyId == storyId }
        let existing = try? dataService.modelContext.fetch(descriptor).first

        if let existing {
            existing.completedSteps = completedSteps
            existing.completedAt = completedSteps.allSatisfy({ $0 }) ? .now : nil
        } else {
            let progress = StoryProgressModel(storyId: storyId, completedSteps: completedSteps)
            dataService.modelContext.insert(progress)
        }
        try? dataService.modelContext.save()
    }
}
