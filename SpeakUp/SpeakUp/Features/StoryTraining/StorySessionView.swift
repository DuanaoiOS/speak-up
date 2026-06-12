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

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator with icons
            StepIndicator(totalSteps: 5, currentStep: currentStep, completedSteps: completedSteps)

            // Swipeable content
            TabView(selection: Binding(
                get: { currentStep },
                set: { newStep in
                    if newStep > currentStep, !completedSteps[currentStep] {
                        completeStep(currentStep)
                    }
                    currentStep = newStep
                }
            )) {
                StoryReaderView(story: story, ttsService: ttsService).tag(0)
                VocabTrainerView(story: story).tag(1)
                PatternTrainerView(story: story).tag(2)
                RetellRecorderView(story: story, audioRecorder: audioRecorder).tag(3)
                QuizPlayerView(story: story, onQuizComplete: { completeStep(4) }).tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom bar
            bottomBar
        }
        .navigationTitle(story.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadProgress() }
        .onDisappear { ttsService.stop() }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Step pagination dots
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(i == currentStep ? .blue : completedSteps[i] ? .green : .secondary.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            // Action button
            if currentStep < 4 {
                Button {
                    if !completedSteps[currentStep] { completeStep(currentStep) }
                    withAnimation { currentStep += 1 }
                } label: {
                    HStack(spacing: 4) {
                        Text("下一步")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            } else if completedSteps[4] {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("完成训练")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
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
