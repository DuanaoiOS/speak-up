import Foundation
import SwiftData

@MainActor
enum StoryImporter {
    static func importIfNeeded(context: ModelContext) throws {
        var descriptor = FetchDescriptor<StoryModel>()
        descriptor.fetchLimit = 1
        if try !context.fetch(descriptor).isEmpty { return }

        for story in BuiltInStories.all {
            context.insert(story)
        }
        try context.save()
    }
}
