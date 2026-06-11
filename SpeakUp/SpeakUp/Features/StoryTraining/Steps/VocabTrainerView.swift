import SwiftUI
import SwiftData

struct VocabTrainerView: View {
    let story: StoryModel

    @State private var currentIndex: Int = 0
    @State private var userSentences: [Int: String] = [:]
    @State private var feedback: [Int: String] = [:]
    @State private var isEvaluating: Bool = false
    @State private var error: String?

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SettingsModel> { $0.id == "singleton" })
    private var settings: [SettingsModel]

    private var vocabulary: [VocabWord] { story.vocabulary }

    var body: some View {
        if vocabulary.isEmpty {
            emptyState
        } else {
            content
        }
    }

    private var emptyState: some View {
        Text("AI 暂未提取词汇，跳至下一步。")
            .foregroundStyle(.secondary)
            .padding()
    }

    private var content: some View {
        let word = vocabulary[currentIndex]

        return ScrollView { VStack(spacing: 16) {
            // Progress
            Text("\(currentIndex + 1) / \(vocabulary.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Word card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(word.word)
                        .font(.title2.bold())
                        .foregroundStyle(.blue)
                    SpeakButton(text: word.word)
                }

                Text(word.definition)
                    .font(.subheadline)
                    .foregroundStyle(.blue.opacity(0.8))

                Text("\"\(word.context)\"")
                    .font(.callout.italic())
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if !word.exampleSentence.isEmpty {
                    HStack {
                        Text("例句：\(word.exampleSentence)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SpeakButton(text: word.exampleSentence)
                    }
                }
            }
            .padding()
            .background(.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.blue.opacity(0.2), lineWidth: 2)
            )

            // Sentence input
            VStack(alignment: .leading, spacing: 8) {
                Text("用 **\(word.word)** 造一个句子")
                    .font(.subheadline)

                TextField("输入你的句子...", text: Binding(
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
            }

            // Feedback
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

                Button { currentIndex = min(vocabulary.count - 1, currentIndex + 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentIndex >= vocabulary.count - 1)
            }
            .padding(.horizontal)

            }
        }
        .padding()
        .onAppear {
            addToReview()
        }
        .onChange(of: currentIndex) { _, _ in
            addToReview()
        }
    }

    private func addToReview() {
        guard currentIndex < vocabulary.count else { return }
        let word = vocabulary[currentIndex]
        try? DataService.shared.addReviewItem(
            type: "vocabulary",
            content: word.word,
            definition: word.definition,
            exampleSentence: word.context,
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
        let word = vocabulary[index]
        let prompt = """
        The student is practicing: "\(word.word)" (meaning: \(word.definition)). Original context: "\(word.context)". Student's sentence: "\(sentence)"
        """

        Task { @MainActor in
            let config = AIConfig(provider: provider, apiKey: key, model: model, baseUrl: baseUrl)
            let service = AIServiceFactory.make(provider: provider)
            do {
                let result = try await service.getFeedback(systemPrompt: AIPrompts.vocabEvalPrompt, userPrompt: prompt, config: config)
                feedback[index] = result
            } catch _ {
                error = "评估失败，请重试"
            }
            isEvaluating = false
        }
    }
}
