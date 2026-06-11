import SwiftUI
import SwiftData

struct StoryReaderView: View {
    let story: StoryModel
    let ttsService: TTSService

    @Query(filter: #Predicate<SettingsModel> { $0.id == "singleton" })
    private var settings: [SettingsModel]

    @State private var currentSentenceIndex: Int = 0
    @State private var isPlaying: Bool = false

    private var ttsRate: Float { Float(settings.first?.ttsRate ?? 0.35) }

    private var sentences: [String] {
        story.content
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Playback controls
            HStack(spacing: 20) {
                Button {
                    togglePlay()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                }

                Button {
                    replayCurrent()
                } label: {
                    Image(systemName: "gobackward")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)

            Text(isPlaying ? "正在朗读..." : "点击播放逐句跟读，点击句子可跳转")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            // Story text
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(sentences.enumerated()), id: \.0) { index, sentence in
                            Text(sentence.trimmingCharacters(in: .whitespaces) + ".")
                                .font(.system(.body, design: .serif))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    index == currentSentenceIndex
                                        ? (isPlaying ? Color.blue.opacity(0.12) : Color.yellow.opacity(0.12))
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    ttsService.stop()
                                    isPlaying = false
                                    currentSentenceIndex = index
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        ttsService.speak(sentence, rate: ttsRate)
                                    }
                                }
                        }
                    }
                    .padding(12)
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
        }
        .padding(.horizontal)
        .onDisappear {
            ttsService.stop()
        }
    }

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
        ttsService.speak(sentences[currentSentenceIndex])
    }
}
