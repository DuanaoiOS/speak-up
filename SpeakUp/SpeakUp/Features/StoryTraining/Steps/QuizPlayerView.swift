import SwiftUI

struct QuizPlayerView: View {
    let story: StoryModel
    var onQuizComplete: (() -> Void)? = nil

    @State private var currentQuestion: Int = 0
    @State private var answers: [Int: Int] = [:]
    @State private var submitted: Bool = false
    @State private var score: Int = 0

    private var quiz: [QuizQuestion] { story.quiz }

    var body: some View {
        if quiz.isEmpty {
            Text("暂无测试题。")
                .foregroundStyle(.secondary)
                .padding()
        } else if submitted {
            resultsView
        } else {
            questionView
        }
    }

    private var questionView: some View {
        let q = quiz[currentQuestion]

        return ScrollView { VStack(spacing: 16) {
            Text("\(currentQuestion + 1) / \(quiz.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(typeLabel(q.type))
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                Text(q.question)
                    .font(.body)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.2)))

            ForEach(Array(q.options.enumerated()), id: \.0) { index, option in
                Button {
                    answers[currentQuestion] = index
                } label: {
                    HStack {
                        Text("\(["A", "B", "C", "D"][index]).")
                            .fontWeight(.medium)
                        Text(option)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(
                        answers[currentQuestion] == index
                            ? Color.blue.opacity(0.1)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                answers[currentQuestion] == index ? .blue : .secondary.opacity(0.2),
                                lineWidth: answers[currentQuestion] == index ? 2 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button {
                    if currentQuestion > 0 { currentQuestion -= 1 }
                } label: {
                    Text("上一题")
                }
                .disabled(currentQuestion == 0)
                .opacity(currentQuestion == 0 ? 0.3 : 1)

                Spacer()

                if currentQuestion < quiz.count - 1 {
                    Button("下一题") {
                        currentQuestion += 1
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("提交") {
                        submitQuiz()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(answers.count < quiz.count)
                }
            }
            .padding(.horizontal)

            }
        }
        .padding()
    }

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Score
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("\(score) / \(quiz.count)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.green)
                    Text(scoreMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Review
                ForEach(Array(quiz.enumerated()), id: \.0) { index, q in
                    let isCorrect = answers[index] == q.correctIndex

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isCorrect ? .green : .red)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(typeLabel(q.type))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(q.question)
                                .font(.callout.bold())

                            if !isCorrect {
                                Text("正确答案：\(q.options[q.correctIndex])")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            if !q.explanation.isEmpty {
                                Text(q.explanation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(isCorrect ? .green.opacity(0.05) : .red.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
    }

    private func submitQuiz() {
        score = 0
        for (index, q) in quiz.enumerated() {
            if answers[index] == q.correctIndex {
                score += 1
            }
        }
        submitted = true
        onQuizComplete?()
    }

    private var scoreMessage: String {
        if score == quiz.count { return "全部正确！" }
        if Double(score) / Double(quiz.count) >= 0.6 { return "不错！继续加油" }
        return "多读几遍故事再来试试"
    }

    private func typeLabel(_ type: String) -> String {
        switch type {
        case "comprehension": return "阅读理解"
        case "vocabulary": return "词汇"
        case "fill-blank": return "填空"
        default: return type
        }
    }
}
