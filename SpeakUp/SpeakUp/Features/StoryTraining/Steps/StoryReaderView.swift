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
    @State private var sentenceTranslations: [Int: String] = [:]       // index → translation text
    @State private var hiddenSentences: Set<Int> = []                   // individually hidden by user
    @State private var hasFullTranslation: Bool = false                 // true after full AI translate
    @State private var showAllTranslations: Bool = false                // global toggle
    @State private var isTranslatingAll: Bool = false
    @State private var translatingSentences: Set<Int> = []
    @State private var addedWords: Set<String> = []
    @State private var selectedWord: (word: String, context: String, definition: String)?

    private var ttsRate: Float { Float(settings.first?.ttsRate ?? 0.35) }

    private var sentences: [String] {
        story.content
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
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
                    Image(systemName: "gobackward").font(.title3).foregroundStyle(.secondary)
                }
                Spacer()
                Button { toggleFullTranslation() } label: {
                    HStack(spacing: 3) {
                        if isTranslatingAll { ProgressView().scaleEffect(0.6) }
                        else { Image(systemName: hasFullTranslation && showAllTranslations ? "eye.slash" : "character.book.closed") }
                        Text(buttonLabel)
                    }.font(.caption)
                }
                .buttonStyle(.bordered).tint(.purple).disabled(isTranslatingAll)
            }
            .padding(.vertical, 4)

            Text(isPlaying ? "正在朗读..." : "点击句子跟读 · 长按翻译/收藏")
                .font(.caption).foregroundStyle(.secondary).padding(.bottom, 4)

            // Story text
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(sentences.enumerated()), id: \.0) { index, sentence in
                            VStack(alignment: .leading, spacing: 4) {
                                // English sentence
                                wordFlowView(sentence.trimmingCharacters(in: .whitespaces) + ".", sentenceIndex: index)

                                // Translation below
                                if shouldShowTranslation(index) {
                                    if translatingSentences.contains(index) {
                                        HStack { ProgressView().scaleEffect(0.5); Text("翻译中...").font(.caption2).foregroundStyle(.secondary) }
                                            .padding(.leading, 4).padding(.top, 2)
                                    } else if let t = sentenceTranslations[index] {
                                        Text(t)
                                            .font(.system(.subheadline)).foregroundStyle(.purple.opacity(0.65))
                                            .padding(.leading, 4).padding(.top, 2)
                                    }
                                }
                            }
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(
                                index == currentSentenceIndex
                                    ? (isPlaying ? Color.blue.opacity(0.08) : Color.yellow.opacity(0.08))
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6)).id(index)
                        }
                    }.padding(10)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                .onChange(of: currentSentenceIndex) { _, newValue in
                    withAnimation { proxy.scrollTo(newValue, anchor: .center) }
                }
            }

            // Vocab chips
            if !story.vocabulary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("📝 生词收藏").font(.caption2).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(story.vocabulary) { word in
                                Button { addWordToReview(word) } label: {
                                    HStack(spacing: 3) {
                                        Text(word.word).font(.caption)
                                        Image(systemName: addedWords.contains(word.word) ? "checkmark" : "plus").font(.system(size: 10))
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(addedWords.contains(word.word) ? Color.green.opacity(0.15) : Color.blue.opacity(0.08))
                                    .foregroundStyle(addedWords.contains(word.word) ? .green : .blue)
                                    .clipShape(Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.padding(.top, 8)
            }
        }
        .padding(.horizontal)
        .onDisappear { ttsService.stop() }
        .alert("添加生词", isPresented: Binding(
            get: { selectedWord != nil }, set: { if !$0 { selectedWord = nil } }
        )) {
            Button("收藏") {
                if let w = selectedWord { addWordDirectly(w.word, context: w.context, definition: w.definition) }
                selectedWord = nil
            }
            Button("取消", role: .cancel) { selectedWord = nil }
        } message: {
            if let w = selectedWord { Text("将 \"\(w.word)\" 加入生词本，方便后续复习。") }
        }
    }

    // MARK: - Sentence View
    @ViewBuilder
    private func wordFlowView(_ text: String, sentenceIndex: Int) -> some View {
        Text(text.trimmingCharacters(in: .whitespaces))
            .font(.system(.body, design: .serif))
            .textSelection(.enabled)
            .contentShape(Rectangle())
            .onTapGesture { handleSentenceTap(sentenceIndex) }
            .contextMenu { sentenceContextMenu(text, index: sentenceIndex) }
    }

    @ViewBuilder
    private func sentenceContextMenu(_ text: String, index: Int) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let hasTranslation = sentenceTranslations[index] != nil
        let isHidden = hiddenSentences.contains(index)

        if hasTranslation {
            if isHidden {
                Button {
                    hiddenSentences.remove(index)
                } label: {
                    Label("显示翻译", systemImage: "eye")
                }
            } else {
                Button {
                    hiddenSentences.insert(index)
                } label: {
                    Label("隐藏翻译", systemImage: "eye.slash")
                }
            }
        } else {
            Button {
                translateSentence(at: index, text: trimmed)
            } label: {
                Label("翻译此句", systemImage: "translate")
            }
        }

        Divider()

        let matching = story.vocabulary.filter { text.lowercased().contains($0.word.lowercased()) }
        if matching.isEmpty {
            Button { selectedWord = (word: trimmed, context: trimmed, definition: "") } label: {
                Label("收藏整句", systemImage: "text.quote")
            }
        } else {
            ForEach(matching) { word in
                Button { addWordToReview(word) } label: {
                    Label("收藏「\(word.word)」", systemImage: "bookmark")
                }
            }
        }
    }

    // MARK: - Translation
    private func translateSentence(at index: Int, text: String) {
        guard let s = settings.first else { return }
        let provider: AIProvider = s.provider == "openai" ? .openai : .claude
        let key = provider == .claude ? s.anthropicApiKey : s.openaiApiKey
        guard !key.isEmpty else {
            sentenceTranslations[index] = "请先配置 AI 模型"
            return
        }

        translatingSentences.insert(index)

        let model = provider == .claude ? s.anthropicModel : s.openaiModel
        let baseUrl = provider == .openai ? s.openaiBaseUrl : nil
        let config = AIConfig(provider: provider, apiKey: key, model: model, baseUrl: baseUrl)
        let service = AIServiceFactory.make(provider: provider)

        Task { @MainActor in
            do {
                let result = try await service.getFeedback(
                    systemPrompt: "Translate to Chinese. Reply with only the translation.",
                    userPrompt: text, config: config
                )
                sentenceTranslations[index] = result
            } catch {
                sentenceTranslations[index] = "翻译失败"
            }
            translatingSentences.remove(index)
        }
    }

    private var buttonLabel: String {
        if !hasFullTranslation { return "全文翻译" }
        return showAllTranslations ? "隐藏翻译" : "显示翻译"
    }

    private func shouldShowTranslation(_ index: Int) -> Bool {
        guard sentenceTranslations[index] != nil else { return false }
        if hiddenSentences.contains(index) { return false }
        return showAllTranslations || !hasFullTranslation
    }

    private func toggleFullTranslation() {
        // If full translation exists, just toggle visibility
        if hasFullTranslation {
            showAllTranslations.toggle()
            return
        }
        // Do full AI translation
        guard let s = settings.first else { return }
        let provider: AIProvider = s.provider == "openai" ? .openai : .claude
        let key = provider == .claude ? s.anthropicApiKey : s.openaiApiKey
        guard !key.isEmpty else {
            sentenceTranslations[0] = "请先配置 AI 模型后使用全文翻译"
            hasFullTranslation = true
            showAllTranslations = true
            return
        }

        isTranslatingAll = true
        let model = provider == .claude ? s.anthropicModel : s.openaiModel
        let baseUrl = provider == .openai ? s.openaiBaseUrl : nil
        let config = AIConfig(provider: provider, apiKey: key, model: model, baseUrl: baseUrl)
        let service = AIServiceFactory.make(provider: provider)

        let prompt = sentences.enumerated().map { "\($0.0 + 1). \($0.1.trimmingCharacters(in: .whitespaces))" }.joined(separator: "\n")

        Task { @MainActor in
            do {
                let result = try await service.getFeedback(
                    systemPrompt: "Translate each line to Chinese. Keep the same number of lines. Only return translations.",
                    userPrompt: prompt, config: config
                )
                // Replace ALL existing translations with full translation
                sentenceTranslations.removeAll()
                hiddenSentences.removeAll()
                let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
                for (i, line) in lines.enumerated() {
                    sentenceTranslations[i] = line.trimmingCharacters(in: .whitespaces)
                }
                hasFullTranslation = true
                showAllTranslations = true
            } catch {
                sentenceTranslations[0] = "全文翻译失败，请检查网络"
                hasFullTranslation = true
                showAllTranslations = true
            }
            isTranslatingAll = false
        }
    }

    // MARK: - Sentence Tap
    private func handleSentenceTap(_ index: Int) {
        ttsService.stop()
        isPlaying = false
        currentSentenceIndex = index
        let text = sentences[index].trimmingCharacters(in: .whitespaces)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            ttsService.speak(text, rate: ttsRate)
        }
    }

    // MARK: - Playback
    private func togglePlay() {
        if isPlaying { ttsService.stop(); isPlaying = false }
        else {
            isPlaying = true; currentSentenceIndex = 0
            ttsService.speakSentences(sentences, rate: ttsRate) { isPlaying = false }
        }
    }

    private func replayCurrent() {
        guard currentSentenceIndex < sentences.count else { return }
        ttsService.stop(); isPlaying = false
        ttsService.speak(sentences[currentSentenceIndex], rate: ttsRate)
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
