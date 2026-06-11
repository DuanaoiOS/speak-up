import Foundation
import SwiftData

@Model
final class StoryProgressModel {
    @Attribute(.unique) var storyId: String
    var completedSteps: [Bool]
    var quizScore: Int?
    var retellRecordingPath: String?
    var retellFeedback: String?
    var completedAt: Date?

    // JSON: [{ word, userSentence, feedback }]
    @Attribute(.externalStorage) var vocabResultsJSON: Data?

    init(storyId: String, completedSteps: [Bool] = [false, false, false, false, false],
         quizScore: Int? = nil, retellRecordingPath: String? = nil,
         retellFeedback: String? = nil, completedAt: Date? = nil) {
        self.storyId = storyId
        self.completedSteps = completedSteps
        self.quizScore = quizScore
        self.retellRecordingPath = retellRecordingPath
        self.retellFeedback = retellFeedback
        self.completedAt = completedAt
    }
}
