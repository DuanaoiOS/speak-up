import SwiftUI
import SwiftData

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Query(filter: #Predicate<SettingsModel> { $0.id == "singleton" })
    private var settings: [SettingsModel]

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else {
                content
            }
        }
        .navigationTitle("SpeakUp")
        .task { viewModel.loadStories() }
    }

    private var currentSettings: SettingsModel? { settings.first }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Generate button
                generateButton
                    .padding(.horizontal)

                // Error
                if let error = viewModel.error {
                    ErrorMessage(message: error)
                        .padding(.horizontal)
                }

                // Empty state or story cards
                if viewModel.stories.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.stories) { story in
                        NavigationLink {
                            StorySessionView(story: story)
                        } label: {
                            StoryCardView(story: story, index: viewModel.stories.firstIndex(where: { $0.id == story.id }) ?? 0)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private var generateButton: some View {
        Button {
            guard let s = currentSettings else { return }
            let provider: AIProvider = s.provider == "openai" ? .openai : .claude
            let key = provider == .claude ? s.anthropicApiKey : s.openaiApiKey
            let model = provider == .claude ? s.anthropicModel : s.openaiModel
            let baseUrl = provider == .openai ? s.openaiBaseUrl : nil
            viewModel.generateStory(provider: provider, apiKey: key, model: model, baseUrl: baseUrl)
        } label: {
            HStack(spacing: 8) {
                if viewModel.isGenerating {
                    ProgressView().scaleEffect(0.8)
                    Text("AI 正在生成故事...")
                } else {
                    Image(systemName: "sparkles")
                    Text("获取新故事")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isGenerating)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 80)
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("还没有故事")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("点击上方按钮，AI 为你生成第一个故事")
                .font(.subheadline)
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }
}

// MARK: - Story Card

struct StoryCardView: View {
    let story: StoryModel
    let index: Int

    private let cardColors: [Color] = [
        Color(red: 0.23, green: 0.39, blue: 0.96),
        Color(red: 0.89, green: 0.40, blue: 0.25),
        Color(red: 0.20, green: 0.71, blue: 0.45),
        Color(red: 0.69, green: 0.32, blue: 0.87),
        Color(red: 0.96, green: 0.56, blue: 0.12),
        Color(red: 0.18, green: 0.62, blue: 0.78),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Color header strip
            cardColors[index % cardColors.count]
                .frame(height: 6)

            VStack(alignment: .leading, spacing: 10) {
                // Title
                Text(story.title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Content preview
                Text(String(story.content.prefix(150)).trimmingCharacters(in: .whitespaces) + "...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .lineSpacing(4)

                // Meta bar
                HStack(spacing: 16) {
                    Label("\(story.vocabulary.count)", systemImage: "character.book.closed")
                    Label("\(story.patterns.count)", systemImage: "rectangle.and.pencil.and.ellipsis")
                    Label("\(story.quiz.count)", systemImage: "questionmark.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}
