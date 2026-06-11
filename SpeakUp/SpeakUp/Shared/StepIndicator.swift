import SwiftUI

struct StepIndicator: View {
    let totalSteps: Int
    let currentStep: Int
    let completedSteps: [Bool]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(stepColor(index))
                    .frame(height: 8)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    private func stepColor(_ index: Int) -> Color {
        if completedSteps[index] { return .green }
        if index == currentStep { return .blue }
        return .secondary.opacity(0.2)
    }
}
