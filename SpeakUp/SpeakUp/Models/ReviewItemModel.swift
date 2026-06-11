import Foundation
import SwiftData

@Model
final class ReviewItemModel {
    @Attribute(.unique) var id: String
    var type: String  // "vocabulary" | "pattern"
    var content: String
    var definition: String
    var exampleSentence: String
    var storyTitle: String
    var storyId: String
    var addedAt: Date
    var reviewCount: Int
    var lastReviewed: Date?
    var mastered: Bool

    init(id: String = UUID().uuidString, type: String, content: String,
         definition: String, exampleSentence: String, storyTitle: String,
         storyId: String, addedAt: Date = .now, reviewCount: Int = 0,
         lastReviewed: Date? = nil, mastered: Bool = false) {
        self.id = id
        self.type = type
        self.content = content
        self.definition = definition
        self.exampleSentence = exampleSentence
        self.storyTitle = storyTitle
        self.storyId = storyId
        self.addedAt = addedAt
        self.reviewCount = reviewCount
        self.lastReviewed = lastReviewed
        self.mastered = mastered
    }
}
