import SwiftUI
import SwiftData

struct StoryReaderView: View {
    let story: StoryModel
    let ttsService: TTSService

    @Query(filter: #Predicate<SettingsModel> { $0.id == "singleton" })
    private var settings: [SettingsModel]

    @Environment(\.modelContext) private var modelContext

    @State private var currentSentenceIndex: Int = 0
    @State private var isPlaying: Bool = false
    @State private var showTranslation: Bool = false
    @State private var translation: String?
    @State private var isTranslating: Bool = false
    @State private var addedWords: Set<String> = []
    @State private var selectedWord: (word: String, context: String, definition: String)?

    private var ttsRate: Float { Float(settings.first?.ttsRate ?? 0.35) }

    private var sentences: [String] {
        story.content
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var translatedSentences: [String] {
        translation?
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Controls
            HStack(spacing: 12) {
                Button { togglePlay() } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)
                }

                Button { replayCurrent() } label: {
                    Image(systemName: "gobackward")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    toggleTranslation()
                } label: {
                    HStack(spacing: 3) {
                        if isTranslating {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Image(systemName: showTranslation ? "translate" : "character.book.closed")
                        }
                        Text(showTranslation ? "隐藏翻译" : "翻译")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .disabled(isTranslating)
            }
            .padding(.vertical, 4)

            Text(isPlaying ? "正在朗读..." : "点击句子跟读 · 长按单词收藏生词")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            // Story text
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(sentences.enumerated()), id: \.0) { index, sentence in
                            VStack(alignment: .leading, spacing: 4) {
                                // English sentence with interactive words
                                wordFlowView(
                                    sentence.trimmingCharacters(in: .whitespaces) + ".",
                                    sentenceIndex: index
                                )

                                // Chinese translation below
                                if showTranslation, index < translatedSentences.count {
                                    Text(translatedSentences[index])
                                        .font(.system(.subheadline))
                                        .foregroundStyle(.purple.opacity(0.65))
                                        .padding(.leading, 4)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                index == currentSentenceIndex
                                    ? (isPlaying ? Color.blue.opacity(0.08) : Color.yellow.opacity(0.08))
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .id(index)
                        }
                    }
                    .padding(10)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
                .onChange(of: currentSentenceIndex) { _, newValue in
                    withAnimation { proxy.scrollTo(newValue, anchor: .center) }
                }
            }


            // Vocabulary chips
            if !story.vocabulary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("📝 生词收藏")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(story.vocabulary) { word in
                                Button { addWordToReview(word) } label: {
                                    HStack(spacing: 3) {
                                        Text(word.word).font(.caption)
                                        Image(systemName: addedWords.contains(word.word) ? "checkmark" : "plus")
                                            .font(.system(size: 10))
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(addedWords.contains(word.word) ? Color.green.opacity(0.15) : Color.blue.opacity(0.08))
                                    .foregroundStyle(addedWords.contains(word.word) ? .green : .blue)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal)
        .onDisappear { ttsService.stop() }
        .alert("添加生词", isPresented: Binding(
            get: { selectedWord != nil },
            set: { if !$0 { selectedWord = nil } }
        )) {
            Button("收藏") {
                if let w = selectedWord {
                    addWordDirectly(w.word, context: w.context, definition: w.definition)
                }
                selectedWord = nil
            }
            Button("取消", role: .cancel) { selectedWord = nil }
        } message: {
            if let w = selectedWord {
                Text("将 \"\(w.word)\" 加入生词本，方便后续复习。")
            }
        }
    }

    // MARK: - Word Flow with Long Press

    private func wordFlowView(_ text: String, sentenceIndex: Int) -> some View {
        let words = text.components(separatedBy: " ")
        return Text(
            words.enumerated().map { i, w -> String in
                i < words.count - 1 ? w + " " : w
            }.joined()
        )
        .font(.system(.body, design: .serif))
        .textSelection(.enabled)
        .contentShape(Rectangle())
        .onTapGesture {
            ttsService.stop()
            isPlaying = false
            currentSentenceIndex = sentenceIndex
            let sentenceText = sentences[sentenceIndex].trimmingCharacters(in: .whitespaces)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                ttsService.speak(sentenceText, rate: ttsRate)
            }
        }
        .contextMenu {
            ForEach(story.vocabulary.filter { v in
                text.lowercased().contains(v.word.lowercased())
            }) { word in
                Button {
                    addWordToReview(word)
                } label: {
                    Label("收藏「\(word.word)」", systemImage: "bookmark")
                }
            }
            if story.vocabulary.filter({ text.lowercased().contains($0.word.lowercased()) }).isEmpty {
                Button {
                    // Extract the tapped word (approximate from sentence)
                    selectedWord = (word: text, context: text, definition: "")
                } label: {
                    Label("收藏整句", systemImage: "text.quote")
                }
            }
        }
    }

    // MARK: - Playback

    private func togglePlay() {
        if isPlaying {
            ttsService.stop()
            isPlaying = false
        } else {
            isPlaying = true
            currentSentenceIndex = 0
            ttsService.speakSentences(sentences, rate: ttsRate) {
                isPlaying = false
            }
        }
    }

    private func replayCurrent() {
        guard currentSentenceIndex < sentences.count else { return }
        ttsService.stop()
        isPlaying = false
        ttsService.speak(sentences[currentSentenceIndex], rate: ttsRate)
    }

    // MARK: - Translation

    private func toggleTranslation() {
        if showTranslation { showTranslation = false; return }
        if translation != nil { showTranslation = true; return }

        isTranslating = true

        let s = settings.first
        let provider: AIProvider = s?.provider == "openai" ? .openai : .claude
        let key = provider == .claude ? (s?.anthropicApiKey ?? "") : (s?.openaiApiKey ?? "")

        if !key.isEmpty {
            translateWithAI(provider: provider, key: key,
                            model: provider == .claude ? (s?.anthropicModel ?? "") : (s?.openaiModel ?? ""),
                            baseUrl: provider == .openai ? (s?.openaiBaseUrl ?? "") : nil)
        } else {
            translateOffline()
        }
    }

    private func translateWithAI(provider: AIProvider, key: String, model: String, baseUrl: String?) {
        let config = AIConfig(provider: provider, apiKey: key, model: model, baseUrl: baseUrl)
        let service = AIServiceFactory.make(provider: provider)

        let prompt = """
        Translate each of the following English sentences into Chinese. \
        Keep the same number of lines as the input sentences. \
        Each line = one Chinese translation. No extra text.

        \(sentences.enumerated().map { "\($0.0 + 1). \($0.1)" }.joined(separator: "\n"))
        """

        Task { @MainActor in
            do {
                let result = try await service.getFeedback(
                    systemPrompt: "You are a translator. Return only Chinese translations, one per line.",
                    userPrompt: prompt, config: config
                )
                translation = result
                showTranslation = true
                isTranslating = false
            } catch {
                print("AI translation failed, fallback to offline: \(error)")
                translateOffline()
            }
        }
    }

    private func translateOffline() {
        translation = "请在设置中配置 AI 模型后使用翻译"
        showTranslation = true
        isTranslating = false
    }

    // MARK: - Review

    private func addWordToReview(_ word: VocabWord) {
        addedWords.insert(word.word)
        addWordDirectly(word.word, context: word.context, definition: word.definition)
    }

    private func addWordDirectly(_ word: String, context: String, definition: String) {
        try? DataService.shared.addReviewItem(
            type: "vocabulary", content: word, definition: definition,
            exampleSentence: context, storyTitle: story.title, storyId: story.id
        )
    }
}
