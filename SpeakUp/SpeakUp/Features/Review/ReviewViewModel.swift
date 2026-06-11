import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class ReviewViewModel {
    var items: [ReviewItemModel] = []
    var currentIndex: Int = 0
    var showAnswer: Bool = false
    var filter: String = "due"  // "all" | "vocabulary" | "pattern" | "due"
    var stats: (total: Int, mastered: Int, reviewedToday: Int) = (0, 0, 0)

    private let dataService = DataService.shared

    func loadItems() {
        do {
            let all = try dataService.fetchReviewItems()
            items = applyFilter(all)
            stats = calculateStats(all)
            currentIndex = 0
            showAnswer = false
        } catch {}
    }

    func markReviewed() {
        guard currentIndex < items.count else { return }
        let item = items[currentIndex]
        item.reviewCount += 1
        item.lastReviewed = .now
        try? dataService.modelContext.save()
        showAnswer = false
        if currentIndex < items.count - 1 { currentIndex += 1 }
    }

    func toggleMastered() {
        guard currentIndex < items.count else { return }
        let item = items[currentIndex]
        item.mastered.toggle()
        item.reviewCount += 1
        item.lastReviewed = .now
        try? dataService.modelContext.save()
        showAnswer = false
        if currentIndex < items.count - 1 { currentIndex += 1 }
    }

    func applyFilter(_ filter: String) {
        self.filter = filter
        currentIndex = 0
        showAnswer = false
        do {
            let all = try dataService.fetchReviewItems()
            items = applyFilter(all)
        } catch {}
    }

    private func applyFilter(_ all: [ReviewItemModel]) -> [ReviewItemModel] {
        switch filter {
        case "vocabulary": return all.filter { $0.type == "vocabulary" }
        case "pattern": return all.filter { $0.type == "pattern" }
        case "due":
            let now = Date()
            return all.filter { item in
                if item.mastered { return false }
                guard let lastReviewed = item.lastReviewed else { return true }
                return now.timeIntervalSince(lastReviewed) > 86400 || item.reviewCount < 3
            }
        default: return all
        }
    }

    private func calculateStats(_ all: [ReviewItemModel]) -> (Int, Int, Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let reviewedToday = all.filter {
            guard let lr = $0.lastReviewed else { return false }
            return Calendar.current.startOfDay(for: lr) == today
        }.count
        return (all.count, all.filter(\.mastered).count, reviewedToday)
    }

    func typeLabel(_ type: String) -> String {
        type == "vocabulary" ? "词汇" : "句型"
    }
}
