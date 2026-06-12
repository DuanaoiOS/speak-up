import SwiftUI

struct StepIndicator: View {
    let totalSteps: Int
    let currentStep: Int
    let completedSteps: [Bool]

    private let icons = ["text.book.closed", "character.textbox", "rectangle.and.pencil.and.ellipsis", "mic", "questionmark.circle"]
    private let labels = ["跟读", "词汇", "句型", "复述", "测试"]

    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Button {
                            // Allow tapping completed or current steps
                        } label: {
                            VStack(spacing: 6) {
                                // Step number circle
                                ZStack {
                                    Circle()
                                        .fill(circleColor(index))
                                        .frame(width: 32, height: 32)
                                    if completedSteps[index] {
                                        Image(systemName: "checkmark")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                    } else {
                                        Image(systemName: icons[index])
                                            .font(.caption2)
                                            .foregroundStyle(index == currentStep ? .white : .secondary)
                                    }
                                }

                                Text(labels[index])
                                    .font(.caption2)
                                    .foregroundStyle(index == currentStep ? .blue : .secondary)
                            }
                            .frame(width: 64)
                            .id(index)
                        }
                        .buttonStyle(.plain)

                        if index < totalSteps - 1 {
                            Rectangle()
                                .fill(completedSteps[index] ? .green : .secondary.opacity(0.2))
                                .frame(height: 2)
                                .frame(width: 24)
                                .padding(.bottom, 22)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: currentStep) { _, step in
                withAnimation { proxy.scrollTo(step, anchor: .center) }
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
    }

    private func circleColor(_ index: Int) -> Color {
        if completedSteps[index] { return .green }
        if index == currentStep { return .blue }
        return .secondary.opacity(0.15)
    }
}
