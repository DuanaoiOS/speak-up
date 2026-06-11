import Foundation
import SwiftData

@Model
final class SettingsModel {
    @Attribute(.unique) var id: String = "singleton"
    var provider: String       // "claude" | "openai"
    var anthropicApiKey: String
    var anthropicModel: String
    var openaiApiKey: String
    var openaiBaseUrl: String
    var openaiModel: String
    var ttsEnabled: Bool
    var ttsRate: Double        // 0.2 (slow) ... 0.6 (fast)
    var theme: String          // "light" | "dark"

    init(provider: String = "claude",
         anthropicApiKey: String = "",
         anthropicModel: String = "claude-sonnet-4-20250514",
         openaiApiKey: String = "",
         openaiBaseUrl: String = "https://api.openai.com/v1",
         openaiModel: String = "gpt-4o",
         ttsEnabled: Bool = true,
         ttsRate: Double = 0.35,
         theme: String = "light") {
        self.provider = provider
        self.anthropicApiKey = anthropicApiKey
        self.anthropicModel = anthropicModel
        self.openaiApiKey = openaiApiKey
        self.openaiBaseUrl = openaiBaseUrl
        self.openaiModel = openaiModel
        self.ttsEnabled = ttsEnabled
        self.ttsRate = ttsRate
        self.theme = theme
    }
}
