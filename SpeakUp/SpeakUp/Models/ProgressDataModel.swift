import Foundation
import SwiftData

@Model
final class ProgressDataModel {
    @Attribute(.unique) var id: String = "singleton"
    var currentStreak: Int
    var longestStreak: Int
    var completedDates: [String]
    var totalSessions: Int
    var totalMinutes: Int
    var topicsCovered: [String]

    init(currentStreak: Int = 0, longestStreak: Int = 0,
         completedDates: [String] = [], totalSessions: Int = 0,
         totalMinutes: Int = 0, topicsCovered: [String] = []) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.completedDates = completedDates
        self.totalSessions = totalSessions
        self.totalMinutes = totalMinutes
        self.topicsCovered = topicsCovered
    }
}
