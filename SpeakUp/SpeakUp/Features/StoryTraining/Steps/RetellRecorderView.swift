import SwiftUI
import SwiftData
import AVFoundation

struct RetellRecorderView: View {
    let story: StoryModel
    let audioRecorder: AudioRecorderService

    @State private var phase: Phase = .ready
    @State private var audioURL: URL?
    @State private var isPlaying: Bool = false
    @State private var feedback: String = ""
    @State private var isEvaluating: Bool = false
    @State private var error: String?
    @State private var audioPlayer: AVAudioPlayer?

    @Query(filter: #Predicate<SettingsModel> { $0.id == "singleton" })
    private var settings: [SettingsModel]

    enum Phase { case ready, recording, done }

    var body: some View {
        ScrollView { VStack(spacing: 16) {
            // Keywords
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("关键词提示")
                        .font(.subheadline.bold())
                }

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(Array(story.keywords.enumerated()), id: \.offset) { i, keyword in
                        HStack(spacing: 8) {
                            Text("\(i + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(cueColor(i))
                                .clipShape(Circle())

                            Text(keyword)
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(cueColor(i).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                Text("看着这些关键词，用英文复述故事内容")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.2)))

            // Recording UI
            switch phase {
            case .ready:
                Button {
                    startRecording()
                } label: {
                    Label("开始录音复述", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

            case .recording:
                VStack(spacing: 12) {
                    Circle()
                        .fill(.red.opacity(0.15))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .fill(.red)
                                .frame(width: 24, height: 24)
                                .scaleEffect(audioRecorder.isRecording ? 1 : 0.5)
                                .animation(.easeInOut(duration: 0.6).repeatForever(), value: audioRecorder.isRecording)
                        )

                    Text(formatDuration(audioRecorder.recordingDuration))
                        .font(.title.monospacedDigit())
                        .foregroundStyle(.red)

                    Button {
                        stopRecording()
                    } label: {
                        Label("停止录音", systemImage: "stop.fill")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }

            case .done:
                if let url = audioURL {
                    HStack(spacing: 16) {
                        Button {
                            togglePlayback(url: url)
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                        }

                        Text(isPlaying ? "播放中..." : "点击回听")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Button {
                            retry()
                        } label: {
                            Label("重录", systemImage: "arrow.counterclockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        evaluate()
                    } label: {
                        HStack {
                            if isEvaluating {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(isEvaluating ? "AI 评估中..." : "AI 评估复述")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(isEvaluating)
                }
            }

            // Feedback
            if !feedback.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 反馈：")
                        .font(.subheadline.bold())
                    Text(feedback)
                        .font(.callout)
                }
                .padding()
                .background(.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let error {
                ErrorMessage(message: error)
            }

            }
        }
        .padding()
        .onDisappear {
            audioPlayer?.stop()
        }
    }

    private let cueColors: [Color] = [.orange, .blue, .green, .purple, .pink, .teal, .indigo, .mint]

    private func cueColor(_ index: Int) -> Color {
        cueColors[index % cueColors.count]
    }

    private func startRecording() {
        do {
            try audioRecorder.startRecording()
            phase = .recording
        } catch {
            self.error = "无法访问麦克风"
        }
    }

    private func stopRecording() {
        audioURL = audioRecorder.stopRecording()
        phase = .done
    }

    private func togglePlayback(url: URL) {
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlaying = true
            audioPlayer?.delegate = PlaybackDelegate { self.isPlaying = false }
        } catch {
            self.error = "播放失败"
        }
    }

    private func retry() {
        audioURL = nil
        feedback = ""
        phase = .ready
    }

    private func evaluate() {
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
        let prompt = """
        Original story:
        "\(story.content)"

        Keywords used as prompts:
        \(story.keywords.joined(separator: ", "))

        The student recorded an oral retelling. Evaluate based on the available information.
        """

        Task { @MainActor in
            let config = AIConfig(provider: provider, apiKey: key, model: model, baseUrl: baseUrl)
            let service = AIServiceFactory.make(provider: provider)
            do {
                let result = try await service.getFeedback(systemPrompt: AIPrompts.retellEvalPrompt, userPrompt: prompt, config: config)
                // Try to parse JSON, fallback to raw text
                if let match = result.firstIndex(of: "{"),
                   let end = result.lastIndex(of: "}"),
                   let data = String(result[match...end]).data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fb = json["feedback"] as? String {
                    feedback = fb
                } else {
                    feedback = result
                }
            } catch _ {
                error = "评估失败，请重试"
            }
            isEvaluating = false
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

private class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { onFinish() }
}
