import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    @Query(filter: #Predicate<ProgressDataModel> { $0.id == "singleton" })
    private var progress: [ProgressDataModel]

    @Query(sort: \StoryProgressModel.completedAt, order: .reverse)
    private var allSessions: [StoryProgressModel]

    @Query private var allStories: [StoryModel]

    private var storyTitleMap: [String: String] {
        Dictionary(uniqueKeysWithValues: allStories.map { ($0.id, $0.title) })
    }

    var body: some View {
        if let p = progress.first {
            content(progress: p)
                .navigationTitle("学习数据")
        } else {
            ProgressView()
                .navigationTitle("学习数据")
        }
    }

    private var recentSessions: [StoryProgressModel] {
        Array(allSessions.prefix(10))
    }

    private func content(progress p: ProgressDataModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(icon: "flame.fill", iconColor: .orange, value: "\(p.currentStreak) 天", label: "当前连续")
                    StatCard(icon: "target", iconColor: .red, value: "\(p.longestStreak) 天", label: "最长连续")
                    StatCard(icon: "chart.line.uptrend.xyaxis", iconColor: .blue, value: "\(p.totalSessions) 次", label: "总训练")
                    StatCard(icon: "clock.fill", iconColor: .purple, value: "\(p.totalMinutes / 60)h", label: "总时长")
                }

                // Heatmap
                VStack(alignment: .leading, spacing: 8) {
                    Text("训练热力图（近 12 周）")
                        .font(.subheadline.bold())

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                        ForEach(heatmapDays(completedDates: p.completedDates), id: \.date) { day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(day.count > 0 ? Color.green : Color.secondary.opacity(0.1))
                                .frame(height: 14)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15)))
                }

                // Topics
                if !p.topicsCovered.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("已覆盖话题")
                            .font(.subheadline.bold())
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 60), spacing: 6)],
                            alignment: .leading,
                            spacing: 6
                        ) {
                            ForEach(p.topicsCovered, id: \.self) { topic in
                                Text(topic)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Recent sessions
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近训练记录")
                        .font(.subheadline.bold())

                    if recentSessions.isEmpty {
                        Text("还没有训练记录。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(recentSessions) { session in
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(storyTitleMap[session.storyId] ?? session.storyId)
                                    .font(.callout)
                                if let date = session.completedAt {
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(session.completedSteps.filter(\.self).count)/5 步完成")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.1)))
                    }
                }
            }
            .padding()
        }
    }

    private func heatmapDays(completedDates: [String]) -> [(date: String, count: Int)] {
        let completedSet = Set(completedDates)
        var days: [(String, Int)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for i in (0..<84).reversed() {
            guard let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) else { continue }
            let dateStr = formatter.string(from: date)
            days.append((dateStr, completedSet.contains(dateStr) ? 1 : 0))
        }
        return days
    }
}

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.15)))
    }
}
