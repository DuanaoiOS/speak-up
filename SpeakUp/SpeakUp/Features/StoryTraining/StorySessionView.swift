import SwiftUI
import SwiftData

struct StorySessionView: View {
    let story: StoryModel

    @State private var currentStep = 0
    @State private var completedSteps: [Bool] = [false, false, false, false, false]
    @State private var ttsService = TTSService()
    @State private var audioRecorder = AudioRecorderService()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let stepLabels = ["文章跟读", "单词造句", "句型语法", "关键词复述", "测试"]

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            StepIndicator(totalSteps: 5, currentStep: currentStep, completedSteps: completedSteps)
                .padding(.horizontal)
                .padding(.vertical, 6)

            Text(stepLabels[currentStep])
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            // Step content — direct view switch instead of TabView
            currentStepView
                .frame(maxHeight: .infinity)

            // Navigation
            navButtons
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
        }
        .navigationTitle(story.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadProgress() }
        .onDisappear { ttsService.stop() }
    }

    // MARK: - Step Views

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 0:
            StoryReaderView(story: story, ttsService: ttsService)
        case 1:
            VocabTrainerView(story: story)
        case 2:
            PatternTrainerView(story: story)
        case 3:
            RetellRecorderView(story: story, audioRecorder: audioRecorder)
        case 4:
            QuizPlayerView(story: story, onQuizComplete: { completeStep(4) })
        default:
            EmptyView()
        }
    }

    // MARK: - Navigation

    private var navButtons: some View {
        HStack {
            Button {
                if currentStep > 0 { currentStep -= 1 }
            } label: {
                Label("上一步", systemImage: "chevron.left")
                    .font(.callout)
            }
            .disabled(currentStep == 0)
            .opacity(currentStep == 0 ? 0.3 : 1)

            Spacer()

            if currentStep < 4 {
                Button {
                    if !completedSteps[currentStep] { completeStep(currentStep) }
                    currentStep += 1
                } label: {
                    Label("下一步", systemImage: "chevron.right")
                        .font(.callout)
                }
                .buttonStyle(.borderedProminent)
            } else if completedSteps[4] {
                Button {
                    dismiss()
                } label: {
                    Label("完成", systemImage: "checkmark")
                        .font(.callout)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }

    // MARK: - Progress

    private func loadProgress() {
        let storyId = story.id
        var descriptor = FetchDescriptor<StoryProgressModel>()
        descriptor.predicate = #Predicate { $0.storyId == storyId }
        if let existing = try? modelContext.fetch(descriptor).first {
            completedSteps = existing.completedSteps
            if let idx = completedSteps.firstIndex(of: false) {
                currentStep = idx
            }
        }
    }

    private func completeStep(_ index: Int) {
        completedSteps[index] = true
        let storyId = story.id
        var descriptor = FetchDescriptor<StoryProgressModel>()
        descriptor.predicate = #Predicate { $0.storyId == storyId }
        let existing = try? modelContext.fetch(descriptor).first

        if let existing {
            existing.completedSteps = completedSteps
            existing.completedAt = completedSteps.allSatisfy({ $0 }) ? .now : nil
        } else {
            let p = StoryProgressModel(storyId: storyId, completedSteps: completedSteps)
            modelContext.insert(p)
        }
        try? modelContext.save()

        guard completedSteps.allSatisfy({ $0 }) else { return }
        let today = ISO8601DateFormatter().string(from: Date())
        let dateStr = String(today.prefix(10))
        try? DataService.shared.updateProgress { p in
            if !p.completedDates.contains(dateStr) { p.completedDates.append(dateStr) }
            p.totalSessions += 1
            p.totalMinutes += 20
            if !p.topicsCovered.contains(story.title) { p.topicsCovered.append(story.title) }
            let (current, longest) = StreakCalculator.calculate(from: p.completedDates)
            p.currentStreak = current
            p.longestStreak = longest
        }
    }
}
