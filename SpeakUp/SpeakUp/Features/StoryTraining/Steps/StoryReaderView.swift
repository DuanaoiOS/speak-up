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
    @State private var sentenceTranslations: [Int: String] = [:]
    @State private var hiddenSentences: Set<Int> = []
    @State private var hasFullTranslation: Bool = false
    @State private var showAllTranslations: Bool = false
    @State private var isTranslatingAll: Bool = false
    @State private var translatingSentences: Set<Int> = []
    @State private var addedWords: Set<String> = []

    // Word-level interaction
    @State private var selectedWord: String?
    @State private var selectedWordContext: String = ""
    @State private var wordDefinition: WordDefinition?
    @State private var isLookingUp: Bool = false
    @State private var definitionError: String?
    @State private var wordSheetItem: WordSheetItem?
    @State private var showSystemDict: Bool = false
    @State private var systemDictWord: String = ""

    private var ttsRate: Float { Float(settings.first?.ttsRate ?? 0.35) }

    private var hasAIKey: Bool {
        guard let s = settings.first else { return false }
        let key = s.provider == "claude" ? s.anthropicApiKey : s.openaiApiKey
        return !key.isEmpty
    }

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

            Text(isPlaying ? "正在朗读..." : "点击单词查释义 · 点击句子跟读 · 长按翻译/收藏")
                .font(.caption).foregroundStyle(.secondary).padding(.bottom, 4)

            // Story text
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(sentences.enumerated()), id: \.0) { index, sentence in
                            sentenceCell(index: index, sentence: sentence)
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
        // Word definition sheet
        .sheet(item: $wordSheetItem) { sheet in
            wordDefinitionSheet(word: sheet.word, context: sheet.context)
        }
        .sheet(isPresented: $showSystemDict) {
            SystemDictionaryView(word: systemDictWord)
        }
        .onChange(of: selectedWord) { _, newWord in
            if let w = newWord {
                wordSheetItem = WordSheetItem(word: w, context: selectedWordContext)
            }
        }
        .onChange(of: wordSheetItem) { _, newItem in
            if newItem == nil {
                selectedWord = nil
                wordDefinition = nil
                definitionError = nil
            }
        }
    }

    // MARK: - Sentence Cell

    @ViewBuilder
    private func sentenceCell(index: Int, sentence: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            wordFlowView(sentence: sentence.trimmingCharacters(in: .whitespaces) + ".",
                         sentenceIndex: index)
            if shouldShowTranslation(index) {
                if translatingSentences.contains(index) {
                    HStack {
                        ProgressView().scaleEffect(0.5)
                        Text("翻译中...").font(.caption2).foregroundStyle(.secondary)
                    }
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

    // MARK: - Word-level Flow View

    @ViewBuilder
    private func wordFlowView(sentence: String, sentenceIndex: Int) -> some View {
        let tokens = tokenize(sentence)
        FlowLayout(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(Array(tokens.enumerated()), id: \.0) { i, token in
                if token.isWord {
                    Button {
                        handleWordTap(word: token.text, sentence: sentence, sentenceIndex: sentenceIndex)
                    } label: {
                        Text(token.text)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 1)
                            .padding(.vertical, 2)
                            .background(
                                selectedWord == token.text.lowercased()
                                    ? Color.blue.opacity(0.15)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .contextMenu { wordContextMenu(word: token.text, context: sentence) }
                } else {
                    Text(token.text)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.primary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { handleSentenceTap(sentenceIndex) }
        .contextMenu { sentenceContextMenu(sentence, index: sentenceIndex) }
    }

    // MARK: - Tokenization

    private struct Token: Identifiable {
        let id = UUID()
        let text: String
        let isWord: Bool
    }

    private func tokenize(_ text: String) -> [Token] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let components = trimmed.components(separatedBy: .whitespaces)
        return components.map { comp in
            // Separate trailing punctuation from word
            let letters = Array(comp)
            var wordPart = ""
            var punctPart = ""
            var foundPunct = false
            for ch in letters.reversed() {
                if !foundPunct && (ch == "." || ch == "," || ch == "!" || ch == "?" || ch == ";" || ch == ":") {
                    punctPart = String(ch) + punctPart
                } else {
                    foundPunct = true
                    wordPart = String(ch) + wordPart
                }
            }
            var tokens: [Token] = []
            if !wordPart.isEmpty {
                tokens.append(Token(text: wordPart, isWord: isActualWord(wordPart)))
            }
            if !punctPart.isEmpty {
                tokens.append(Token(text: punctPart, isWord: false))
            }
            return tokens.isEmpty ? [Token(text: comp, isWord: false)] : tokens
        }.flatMap { $0 }
    }

    private func isActualWord(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .punctuationCharacters)
        guard !cleaned.isEmpty else { return false }
        return cleaned.range(of: #"^[a-zA-Z']+$"#, options: .regularExpression) != nil
    }

    // MARK: - Word Tap

    private func handleWordTap(word: String, sentence: String, sentenceIndex: Int) {
        let cleaned = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
        selectedWord = cleaned
        selectedWordContext = sentence.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Word Context Menu

    @ViewBuilder
    private func wordContextMenu(word: String, context: String) -> some View {
        let cleaned = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
        Button {
            handleWordTap(word: word, sentence: context, sentenceIndex: 0)
        } label: {
            Label("查看释义", systemImage: "character.magnify")
        }
        Button {
            ttsService.speak(word, rate: ttsRate)
        } label: {
            Label("跟读发音", systemImage: "waveform")
        }
        Divider()
        Button {
            addWordDirectly(cleaned, context: context, definition: "")
        } label: {
            Label("收藏该单词", systemImage: "bookmark")
        }
    }

    // MARK: - Word Definition Sheet

    @ViewBuilder
    private func wordDefinitionSheet(word: String, context: String) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Word header
                HStack {
                    Text(word)
                        .font(.largeTitle.bold())
                        .fontDesign(.serif)
                    Spacer()
                    Button {
                        ttsService.speak(word, rate: ttsRate)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .padding(10)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                    }
                }

                // System dictionary — always available, instant
                let hasSysDef = UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word)
                Button {
                    let w = word
                    wordSheetItem = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        systemDictWord = w
                        showSystemDict = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "character.book.closed.fill")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("系统辞典").font(.subheadline.bold())
                            Text(hasSysDef ? "点击查看内置英汉释义" : "点击搜索更多资源")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // AI-enhanced definition (if configured)
                if hasAIKey {
                    Divider()
                    Text("AI 增强释义").font(.caption).foregroundStyle(.secondary)
                    if isLookingUp {
                        HStack { ProgressView(); Text("AI 查询中...").font(.subheadline).foregroundStyle(.secondary) }
                    } else if let error = definitionError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.subheadline).foregroundStyle(.orange)
                    } else if let def = wordDefinition {
                        definitionContent(def)
                    }
                }

                Spacer()

                // Bookmark button
                Button {
                    addWordDirectly(word, context: context,
                                    definition: wordDefinition.map { "\($0.partOfSpeech). \($0.definition)" } ?? "")
                } label: {
                    HStack {
                        Image(systemName: addedWords.contains(word) ? "checkmark" : "bookmark")
                        Text(addedWords.contains(word) ? "已收藏" : "加入生词本")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(addedWords.contains(word) ? .green : .blue)
                .disabled(addedWords.contains(word))
            }
            .padding()
            .navigationTitle("单词释义")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { wordSheetItem = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .task { await lookupWord(word, context: context) }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func definitionContent(_ def: WordDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !def.partOfSpeech.isEmpty {
                Text(def.partOfSpeech.capitalized)
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("释义").font(.caption).foregroundStyle(.secondary)
                Text(def.definition).font(.body)
            }
            if !def.exampleSentence.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("例句").font(.caption).foregroundStyle(.secondary)
                    Text(def.exampleSentence)
                        .font(.body.italic())
                        .fontDesign(.serif)
                }
            }
        }
    }

    private func lookupWord(_ word: String, context: String) async {
        guard let s = settings.first else { return }
        let provider: AIProvider = s.provider == "openai" ? .openai : .claude
        let key = provider == .claude ? s.anthropicApiKey : s.openaiApiKey
        guard !key.isEmpty else {
            definitionError = "AI 未配置"
            return
        }
        isLookingUp = true
        defer { isLookingUp = false }
        do {
            let config = AIConfig(provider: provider, apiKey: key,
                                  model: provider == .claude ? s.anthropicModel : s.openaiModel,
                                  baseUrl: provider == .openai ? s.openaiBaseUrl : nil)
            wordDefinition = try await DictionaryService.shared.lookup(word: word, context: context, config: config)
            definitionError = nil
        } catch {
            definitionError = "查询失败，请重试"
        }
    }

    // MARK: - Sentence Context Menu

    @ViewBuilder
    private func sentenceContextMenu(_ text: String, index: Int) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let hasTranslation = sentenceTranslations[index] != nil
        let isHidden = hiddenSentences.contains(index)

        if hasTranslation {
            if isHidden {
                Button { hiddenSentences.remove(index) } label: {
                    Label("显示翻译", systemImage: "eye")
                }
            } else {
                Button { hiddenSentences.insert(index) } label: {
                    Label("隐藏翻译", systemImage: "eye.slash")
                }
            }
        } else {
            Button { translateSentence(at: index, text: trimmed) } label: {
                Label("翻译此句", systemImage: "translate")
            }
        }

        Divider()

        let matching = story.vocabulary.filter { text.lowercased().contains($0.word.lowercased()) }
        if matching.isEmpty {
            Button { addWordDirectly(trimmed, context: trimmed, definition: "") } label: {
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
        if hasFullTranslation {
            showAllTranslations.toggle()
            return
        }
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

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 4
    var verticalSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.last.flatMap { $0.maxY } ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(proposal: proposal, subviews: subviews)
        for (rowIndex, row) in rows.enumerated() {
            let y = bounds.minY + CGFloat(rowIndex) * (row.maxHeight + verticalSpacing)
            for item in row.items {
                let x = bounds.minX + item.x
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            }
        }
    }

    private struct RowItem { let index: Int; let x: CGFloat; let width: CGFloat; let height: CGFloat }
    private struct Row { var items: [RowItem] = []; var maxHeight: CGFloat = 0; var maxY: CGFloat = 0 }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        let maxWidth = proposal.width ?? .infinity
        var currentRow = Row()
        var currentX: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let itemWidth = size.width + horizontalSpacing
            if currentX + itemWidth > maxWidth && !currentRow.items.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
                currentX = 0
            }
            currentRow.items.append(RowItem(index: index, x: currentX, width: size.width, height: size.height))
            currentRow.maxHeight = max(currentRow.maxHeight, size.height)
            currentX += itemWidth
        }
        if !currentRow.items.isEmpty { rows.append(currentRow) }
        // Compute maxY offsets
        var cumulativeY: CGFloat = 0
        for i in 0..<rows.count {
            rows[i].maxY = cumulativeY + rows[i].maxHeight
            cumulativeY += rows[i].maxHeight + verticalSpacing
        }
        return rows
    }
}

// MARK: - WordSheetItem

private struct WordSheetItem: Identifiable, Equatable {
    let id = UUID()
    let word: String
    let context: String
}

// MARK: - System Dictionary View

private struct SystemDictionaryView: UIViewControllerRepresentable {
    let word: String

    func makeUIViewController(context: Context) -> UINavigationController {
        let dictVC = UIReferenceLibraryViewController(term: word)
        let nav = UINavigationController(rootViewController: dictVC)
        dictVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: context.coordinator,
            action: #selector(Coordinator.dismiss)
        )
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        @objc func dismiss() {
            // Find the presenting VC and dismiss
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else { return }
            root.presentedViewController?.dismiss(animated: true)
        }
    }
}
