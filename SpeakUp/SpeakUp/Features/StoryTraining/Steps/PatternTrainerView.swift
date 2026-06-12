import SwiftUI
import SwiftData

struct PatternTrainerView: View {
    let story: StoryModel

    @State private var currentIndex: Int = 0
    @State private var userSentences: [Int: String] = [:]
    @State private var feedback: [Int: String] = [:]
    @State private var isEvaluating: Bool = false
    @State private var showExplanation: Bool = false
    @State private var error: String?

    @Query(filter: #Predicate<SettingsModel> { $0.id == "singleton" })
    private var settings: [SettingsModel]

    private var patterns: [SentencePattern] { story.patterns }

    var body: some View {
        if patterns.isEmpty {
            Text("AI 暂未提取句型，跳至下一步。")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            content
        }
    }

    private var content: some View {
        let pattern = patterns[currentIndex]

        return ScrollView { VStack(spacing: 16) {
            Text("\(currentIndex + 1) / \(patterns.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Pattern card
            VStack(alignment: .leading, spacing: 8) {
                Text(pattern.pattern)
                    .font(.title3.bold())
                    .foregroundStyle(.purple)

                HStack {
                    Text("\"\(pattern.fromStory)\"")
                        .font(.callout.italic())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SpeakButton(text: pattern.fromStory)
                }
                .padding(8)
                .background(.background.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if !showExplanation {
                    Button {
                        withAnimation { showExplanation = true }
                    } label: {
                        Label("查看详解", systemImage: "lightbulb")
                            .font(.caption)
                    }
                    .foregroundStyle(.purple)
                } else {
                    Text(pattern.explanation)
                        .font(.callout)
                        .foregroundStyle(.purple.opacity(0.8))
                        .padding(8)
                        .background(.background.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if !pattern.practicePrompts.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("造句提示：")
                            .font(.caption.bold())
                            .foregroundStyle(.purple.opacity(0.7))
                        ForEach(pattern.practicePrompts, id: \.self) { prompt in
                            Text("· \(prompt)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(.purple.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.purple.opacity(0.2), lineWidth: 2)
            )

            // Practice
            TextField("用 \"\(pattern.pattern)\" 造一个句子...", text: Binding(
                get: { userSentences[currentIndex] ?? "" },
                set: { userSentences[currentIndex] = $0 }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...4)

            Button {
                evaluate(index: currentIndex)
            } label: {
                HStack {
                    if isEvaluating {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isEvaluating ? "评估中..." : "AI 评估")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .disabled(userSentences[currentIndex]?.trimmingCharacters(in: .whitespaces).isEmpty ?? true || isEvaluating)
            .buttonStyle(.bordered)
            .tint(.orange)

            if let fb = feedback[currentIndex] {
                Text(fb)
                    .font(.callout)
                    .padding()
                    .background(.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let error {
                ErrorMessage(message: error)
            }

            // Navigation
            HStack {
                Button { currentIndex = max(0, currentIndex - 1) } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentIndex == 0)

                Spacer()

                Button { currentIndex = min(patterns.count - 1, currentIndex + 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentIndex >= patterns.count - 1)
            }
            .padding(.horizontal)

            }
        }
        .padding()
        .scrollDismissesKeyboard(.interactively)
        .onAppear { addToReview() }
        .onChange(of: currentIndex) { _, _ in addToReview() }
    }

    private func addToReview() {
        guard currentIndex < patterns.count else { return }
        let p = patterns[currentIndex]
        try? DataService.shared.addReviewItem(
            type: "pattern",
            content: p.pattern,
            definition: p.explanation,
            exampleSentence: p.fromStory,
            storyTitle: story.title,
            storyId: story.id
        )
    }

    private func evaluate(index: Int) {
        guard let sentence = userSentences[index]?.trimmingCharacters(in: .whitespaces), !sentence.isEmpty else { return }
        guard let s = settings.first else { return }
        let provider: AIProvider = s.provider == "openai" ? .openai : .claude
        let key = provider == .claude ? s.anthropicApiKey : s.openaiApiKey
        let model = provider == .claude ? s.anthropicModel : s.openaiModel
        let baseUrl = provider == .openai ? s.openaiBaseUrl : nil

        guard !key.isEmpty else {
            error = "请先在设置中配置 API Key"
            return
        }

        isEvaluating = true
        error = nil
        let pattern = patterns[index]
        let prompt = """
        Pattern: "\(pattern.pattern)". Original story sentence: "\(pattern.fromStory)". Student's sentence: "\(sentence)"
        """

        Task { @MainActor in
            let config = AIConfig(provider: provider, apiKey: key, model: model, baseUrl: baseUrl)
            let service = AIServiceFactory.make(provider: provider)
            do {
                let result = try await service.getFeedback(systemPrompt: AIPrompts.patternEvalPrompt, userPrompt: prompt, config: config)
                feedback[index] = result
            } catch _ {
                error = "评估失败，请重试"
            }
            isEvaluating = false
        }
    }
}
