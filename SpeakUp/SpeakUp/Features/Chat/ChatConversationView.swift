import SwiftUI
import SwiftData

struct ChatConversationView: View {
    @Bindable var viewModel: ChatViewModel
    @Query(filter: #Predicate<SettingsModel> { $0.id == "singleton" })
    private var settings: [SettingsModel]
    @Environment(\.dismiss) private var dismiss

    @State private var scrollToId: String?

    private var roleName: String {
        let names = ["interviewer": "面试官", "friend": "派对朋友", "waiter": "餐厅服务员", "debate_partner": "辩论伙伴"]
        return names[viewModel.activeRoleId ?? ""] ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("← 返回") {
                    viewModel.activeRoleId = nil
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                Spacer()

                Text(roleName)
                    .font(.subheadline.bold())

                Spacer()

                Button {
                    viewModel.clearConversation()
                } label: {
                    Image(systemName: "trash")
                        .font(.callout)
                }
                .foregroundStyle(.red)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if viewModel.messages.isEmpty {
                            VStack(spacing: 4) {
                                Text("开始对话吧！AI 会以 \(roleName) 的身份跟你聊天。")
                                    .foregroundStyle(.secondary)
                                Text("你可以打字，也可以按住麦克风说话。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }

                        ForEach(Array(viewModel.messages.enumerated()), id: \.0) { index, msg in
                            HStack {
                                if msg.role == "assistant" {
                                    Image(systemName: "bubble.left.fill")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                Text(msg.content.isEmpty && msg.role == "assistant" ? "..." : msg.content)
                                    .font(.callout)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        msg.role == "user"
                                            ? .blue
                                            : .secondary.opacity(0.1)
                                    )
                                    .foregroundStyle(
                                        msg.role == "user" ? .white : .primary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                if msg.role == "user" {
                                    Spacer()
                                }
                            }
                            .id(index)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)

            // Error
            if let error = viewModel.error {
                ErrorMessage(message: error)
                    .padding(.horizontal)
            }

            // Input
            VStack(spacing: 4) {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("输入消息...", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)

                    VoiceInputButton { transcript in
                        viewModel.inputText = transcript
                    }
                    .disabled(viewModel.isStreaming)

                    Button {
                        if let s = settings.first {
                            viewModel.sendMessage(settings: s)
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.blue)
                    }
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isStreaming)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.bar)
        }
    }
}
