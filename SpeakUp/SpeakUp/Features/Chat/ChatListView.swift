import SwiftUI

struct ChatListView: View {
    @State private var viewModel = ChatViewModel()

    private let roles: [(id: String, name: String, icon: String, desc: String)] = [
        ("interviewer", "面试官", "💼", "练习面试英语"),
        ("friend", "派对朋友", "🎉", "轻松社交聊天"),
        ("waiter", "餐厅服务员", "🍽️", "餐厅点餐场景"),
        ("debate_partner", "辩论伙伴", "💭", "表达和捍卫观点"),
    ]

    var body: some View {
        Group {
            if viewModel.activeRoleId == nil {
                rolePicker
            } else {
                ChatConversationView(viewModel: viewModel)
            }
        }
        .navigationTitle("AI 对话陪练")
    }

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择一个场景，开始练习口语对话。")
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(roles, id: \.id) { role in
                    Button {
                        viewModel.setActiveRole(role.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(role.icon)
                                .font(.system(size: 36))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(role.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(role.desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
}
