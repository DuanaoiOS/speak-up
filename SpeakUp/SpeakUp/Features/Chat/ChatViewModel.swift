import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var isStreaming: Bool = false
    var inputText: String = ""
    var error: String?
    var activeRoleId: String?

    private let dataService = DataService.shared
    private let roles: [(id: String, name: String, icon: String, desc: String)] = [
        ("interviewer", "面试官", "💼", "练习面试英语"),
        ("friend", "派对朋友", "🎉", "轻松社交聊天"),
        ("waiter", "餐厅服务员", "🍽️", "餐厅点餐场景"),
        ("debate_partner", "辩论伙伴", "💭", "表达和捍卫观点"),
    ]

    func setActiveRole(_ roleId: String) {
        activeRoleId = roleId
        loadMessages()
    }

    func clearConversation() {
        guard let roleId = activeRoleId else { return }
        messages = []
        var descriptor = FetchDescriptor<ChatConversationModel>()
        descriptor.predicate = #Predicate { $0.roleId == roleId }
        if let existing = try? dataService.modelContext.fetch(descriptor).first {
            dataService.modelContext.delete(existing)
            try? dataService.modelContext.save()
        }
    }

    func sendMessage(settings: SettingsModel) {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isStreaming, let roleId = activeRoleId else { return }

        let provider: AIProvider = settings.provider == "openai" ? .openai : .claude
        let key = provider == .claude ? settings.anthropicApiKey : settings.openaiApiKey
        let model = provider == .claude ? settings.anthropicModel : settings.openaiModel
        let baseUrl = provider == .openai ? settings.openaiBaseUrl : nil

        guard !key.isEmpty else {
            error = "请先在设置中配置 API Key"
            return
        }

        inputText = ""
        error = nil
        isStreaming = true

        let userMsg = ChatMessage(role: "user", content: text)
        messages.append(userMsg)

        let assistantId = UUID().uuidString
        var assistantContent = ""
        let assistantMsg = ChatMessage(role: "assistant", content: "")
        messages.append(assistantMsg)

        let sysPrompt = AIPrompts.chatSystemPrompts[roleId] ?? ""

        Task {
            let config = AIConfig(provider: provider, apiKey: key, model: model, baseUrl: baseUrl)
            let service = AIServiceFactory.make(provider: provider)
            let stream = service.streamChat(
                messages: messages.dropLast().map { ChatMessage(role: $0.role, content: $0.content) },
                systemPrompt: sysPrompt,
                config: config
            )

            do {
                for try await chunk in stream {
                    assistantContent += chunk
                    await MainActor.run {
                        if let idx = self.messages.lastIndex(where: { $0.role == "assistant" }) {
                            self.messages[idx] = ChatMessage(role: "assistant", content: assistantContent)
                        }
                    }
                }
                // Save to persistent store
                await MainActor.run { self.saveConversation() }
            } catch let err {
                await MainActor.run {
                    self.error = "请求失败: \(err.localizedDescription)"
                }
            }
            await MainActor.run { self.isStreaming = false }
        }
    }

    private func loadMessages() {
        guard let roleId = activeRoleId else { return }
        if let conv = try? dataService.fetchConversation(roleId: roleId),
           let msgs = conv.messages {
            messages = msgs.map { ChatMessage(role: $0.role, content: $0.content) }
        } else {
            messages = []
        }
    }

    private func saveConversation() {
        guard let roleId = activeRoleId else { return }
        var descriptor = FetchDescriptor<ChatConversationModel>()
        descriptor.predicate = #Predicate { $0.roleId == roleId }
        let existing = try? dataService.modelContext.fetch(descriptor).first

        let msgModels = messages.map { msg in
            ChatMessageModel(id: UUID().uuidString, role: msg.role, content: msg.content)
        }

        if let existing {
            existing.messages = msgModels
            existing.lastActive = .now
        } else {
            let conv = ChatConversationModel(roleId: roleId, messages: msgModels)
            dataService.modelContext.insert(conv)
        }
        try? dataService.modelContext.save()
    }
}
