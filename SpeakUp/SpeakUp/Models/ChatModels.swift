import Foundation
import SwiftData

@Model
final class ChatMessageModel {
    var id: String
    var role: String  // "user" | "assistant"
    var content: String
    var timestamp: Date
    var isVoice: Bool

    init(id: String = UUID().uuidString, role: String, content: String,
         timestamp: Date = .now, isVoice: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isVoice = isVoice
    }
}

@Model
final class ChatConversationModel {
    @Attribute(.unique) var roleId: String
    var lastActive: Date
    @Relationship(deleteRule: .cascade) var messages: [ChatMessageModel]?

    init(roleId: String, lastActive: Date = .now, messages: [ChatMessageModel] = []) {
        self.roleId = roleId
        self.lastActive = lastActive
        self.messages = messages
    }
}
