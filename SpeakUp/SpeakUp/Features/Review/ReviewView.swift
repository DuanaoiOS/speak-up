import SwiftUI

struct ReviewView: View {
    @State private var viewModel = ReviewViewModel()

    private let filters: [(String, String)] = [
        ("due", "待复习"),
        ("vocabulary", "词汇"),
        ("pattern", "句型"),
        ("all", "全部"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Stats bar
            statsBar
                .padding(.horizontal)
                .padding(.top, 8)

            // Filter tabs
            filterBar
                .padding(.horizontal)
                .padding(.top, 16)

            if viewModel.items.isEmpty {
                emptyState
            } else {
                cardContent
            }
        }
        .navigationTitle("复习")
        .onAppear { viewModel.loadItems() }
    }

    // MARK: - Stats

    private var statsBar: some View {
        HStack(spacing: 10) {
            StatBadge(label: "总计", value: "\(viewModel.stats.total)", color: .blue)
            StatBadge(label: "已掌握", value: "\(viewModel.stats.mastered)", color: .green)
            StatBadge(label: "今日复习", value: "\(viewModel.stats.reviewedToday)", color: .orange)
        }
    }

    // MARK: - Filter

    private var filterBar: some View {
        HStack(spacing: 4) {
            ForEach(filters, id: \.0) { filter in
                Button {
                    viewModel.applyFilter(filter.0)
                } label: {
                    Text(filter.1)
                        .font(.subheadline)
                        .fontWeight(viewModel.filter == filter.0 ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .foregroundStyle(viewModel.filter == filter.0 ? .white : .primary)
                .background(
                    viewModel.filter == filter.0
                        ? Color.blue
                        : Color.primary.opacity(0.06)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("暂无复习内容")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("完成故事学习后，练习过的词汇和句型会自动加入复习")
                .font(.subheadline)
                .foregroundStyle(.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(spacing: 12) {
            Text("\(viewModel.currentIndex + 1) / \(viewModel.items.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            if let item = viewModel.items[safe: viewModel.currentIndex] {
                // Flashcard with side navigation
                HStack(spacing: 4) {
                    // Left arrow
                    Button {
                        if viewModel.currentIndex > 0 {
                            viewModel.currentIndex -= 1
                            viewModel.showAnswer = false
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .frame(width: 28, height: 44)
                            .contentShape(Rectangle())
                    }
                    .opacity(viewModel.currentIndex == 0 ? 0.2 : 1)
                    .disabled(viewModel.currentIndex == 0)

                    // Card
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.showAnswer.toggle()
                        }
                    } label: {
                        cardFace(item: item)
                    }
                    .buttonStyle(.plain)

                    // Right arrow
                    Button {
                        if viewModel.currentIndex < viewModel.items.count - 1 {
                            viewModel.currentIndex += 1
                            viewModel.showAnswer = false
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .frame(width: 28, height: 44)
                            .contentShape(Rectangle())
                    }
                    .opacity(viewModel.currentIndex >= viewModel.items.count - 1 ? 0.2 : 1)
                    .disabled(viewModel.currentIndex >= viewModel.items.count - 1)
                }

                Text("点击卡片翻转查看释义")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        viewModel.markReviewed()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("复习过了")
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button {
                        viewModel.toggleMastered()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: item.mastered ? "arrow.uturn.backward" : "checkmark")
                            Text(item.mastered ? "退回复习" : "已掌握")
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(item.mastered ? .secondary : .green)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Card

    private func cardFace(item: ReviewItemModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.typeLabel(item.type))
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                if item.mastered {
                    Label("已掌握", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }

                Text(item.storyTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .center) {
                Text(item.content)
                    .font(.title3.bold())
                SpeakButton(text: item.content)
            }

            if viewModel.showAnswer {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("释义")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.definition)
                        .font(.callout)

                    if !item.exampleSentence.isEmpty {
                        Text("例句")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        HStack(alignment: .top) {
                            Text("\"\(item.exampleSentence)\"")
                                .font(.callout.italic())
                                .foregroundStyle(.secondary)
                            SpeakButton(text: item.exampleSentence)
                        }
                    }

                    HStack {
                        Label("复习 \(item.reviewCount) 次", systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if item.mastered {
                            Label("已掌握", systemImage: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 200)
        .background(.blue.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.blue.opacity(0.25), lineWidth: 2)
        )
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
