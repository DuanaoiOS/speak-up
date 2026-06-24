import SwiftUI
import SwiftData

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Query(filter: #Predicate<SettingsModel> { $0.id == "singleton" })
    private var settings: [SettingsModel]

    @State private var showGenerateSheet: Bool = false
    @State private var generateTheme: String = ""

    private let weekThemes = [
        "职场沟通", "科技生活", "人际关系", "自我突破",
        "文化碰撞", "人生转折", "梦想与现实", "城市故事",
        "亲情时刻", "成长烦恼"
    ]

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else {
                content
            }
        }
        .navigationTitle("SpeakUp")
        .task { viewModel.load() }
        .onAppear { viewModel.refreshProgress() }
        .sheet(isPresented: $showGenerateSheet) {
            generateSheet
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            // Week header
            weekHeader
                .padding(.horizontal)
                .padding(.top, 8)

            Divider().padding(.vertical, 12)

            // Level grid
            levelGrid
                .padding(.horizontal)

            Spacer()

            // Generate button for next week
            if viewModel.weekProgress.completed == 5 && viewModel.currentWeek == viewModel.maxUnlockedWeek {
                Button {
                    generateTheme = weekThemes[(viewModel.currentWeek - 1) % weekThemes.count]
                    showGenerateSheet = true
                } label: {
                    Label("解锁下一周", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding()
            }
        }
    }

    // MARK: - Week Header

    private var weekHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    withAnimation { viewModel.goBackWeek() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                .opacity(viewModel.canGoBackWeek ? 1 : 0.2)
                .disabled(!viewModel.canGoBackWeek)

                Spacer()

                VStack(spacing: 2) {
                    Text("Week \(viewModel.currentWeek)")
                        .font(.title2.bold())
                    Text(viewModel.weekTheme)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation { viewModel.advanceWeek() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
                .opacity(viewModel.canAdvanceWeek ? 1 : 0.2)
                .disabled(!viewModel.canAdvanceWeek)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.secondary.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            viewModel.weekProgress.completed == 5
                                ? Color.green : Color.blue
                        )
                        .frame(
                            width: geo.size.width * CGFloat(viewModel.weekProgress.completed) / CGFloat(viewModel.weekProgress.total),
                            height: 8
                        )
                }
            }
            .frame(height: 8)

            Text("\(viewModel.weekProgress.completed) / \(viewModel.weekProgress.total) 关卡完成")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Level Grid

    private var levelGrid: some View {
        VStack(spacing: 14) {
            ForEach(0..<5, id: \.self) { index in
                LevelCard(
                    index: index,
                    story: index < viewModel.weekStories.count ? viewModel.weekStories[index] : nil,
                    isUnlocked: viewModel.isLevelUnlocked(index),
                    isCompleted: viewModel.isLevelCompleted(index),
                    isCurrent: viewModel.nextLevelIndex == index
                )
            }
        }
    }

    // MARK: - Generate Sheet

    private var generateSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.purple)

                Text("解锁 Week \(viewModel.currentWeek + 1)")
                    .font(.title2.bold())

                Text("本周主题：\(generateTheme)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("AI 将生成 5 篇同主题故事")
                    Text("每篇包含词汇、句型、测试题")
                    Text("完成后自动进入下一周")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding()
                .background(.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if let error = viewModel.error {
                    ErrorMessage(message: error)
                }

                Button {
                    guard let s = settings.first else { return }
                    let p: AIProvider = s.provider == "openai" ? .openai : .claude
                    let key = p == .claude ? s.anthropicApiKey : s.openaiApiKey
                    let model = p == .claude ? s.anthropicModel : s.openaiModel
                    let baseUrl = p == .openai ? s.openaiBaseUrl : nil
                    viewModel.generateWeek(provider: p, apiKey: key, model: model, baseUrl: baseUrl, theme: generateTheme)
                } label: {
                    HStack {
                        if viewModel.isGenerating {
                            ProgressView().scaleEffect(0.8)
                            Text("AI 生成中...")
                        } else {
                            Label("开始生成", systemImage: "sparkles")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(viewModel.isGenerating)

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showGenerateSheet = false }
                }
            }
        }
    }
}

// MARK: - Level Card

struct LevelCard: View {
    let index: Int
    let story: StoryModel?
    let isUnlocked: Bool
    let isCompleted: Bool
    let isCurrent: Bool

    var body: some View {
        Group {
            if let story, isUnlocked {
                NavigationLink {
                    StorySessionView(story: story)
                } label: {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        HStack(spacing: 14) {
            // Level number badge
            ZStack {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 44, height: 44)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                } else if isUnlocked {
                    Text("\(index + 1)")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let story {
                    Text("Day \(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(story.title)
                        .font(.headline)
                        .foregroundStyle(isUnlocked ? .primary : .secondary)
                } else {
                    Text("Day \(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("-----")
                        .font(.headline)
                        .foregroundStyle(.secondary.opacity(0.4))
                }
            }

            Spacer()

            if isCurrent {
                Text("进行中")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(isUnlocked ? 0.04 : 0.01), radius: 4, y: 2)
        .opacity(isUnlocked ? 1 : 0.55)
    }

    private var badgeColor: Color {
        if isCompleted { return .green }
        if isUnlocked { return .blue }
        return .secondary.opacity(0.4)
    }
}
