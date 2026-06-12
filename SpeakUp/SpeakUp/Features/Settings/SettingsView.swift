import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Query(filter: #Predicate<SettingsModel> { $0.id == "singleton" })
    private var savedSettings: [SettingsModel]

    // Local editing state — only written to model on explicit save
    @State private var provider: String = "claude"
    @State private var anthropicApiKey: String = ""
    @State private var anthropicModel: String = ""
    @State private var openaiApiKey: String = ""
    @State private var openaiBaseUrl: String = ""
    @State private var openaiModel: String = ""
    @State private var ttsEnabled: Bool = true
    @State private var ttsRate: Double = 0.35
    @AppStorage("theme") private var theme: String = "light"
    @State private var initialized: Bool = false

    @State private var showAnthropicKey: Bool = false
    @State private var showOpenaiKey: Bool = false
    @State private var selectedPreset: Int = -1
    @State private var showExportSheet: Bool = false
    @State private var showImportSheet: Bool = false
    @State private var exportData: String = ""
    @State private var showSavedToast: Bool = false
    @State private var toastMessage: String = "配置已保存"
    @State private var toastSuccess: Bool = true
    @State private var isTesting: Bool = false

    private let presets: [(String, String, String)] = [
        ("OpenAI", "https://api.openai.com/v1", "gpt-4.1"),
        ("DeepSeek", "https://api.deepseek.com/v1", "deepseek-v4-pro"),
        ("Moonshot (Kimi)", "https://api.moonshot.cn/v1", "kimi2.6"),
        ("Groq", "https://api.groq.com/openai/v1", "llama-4-scout-17b-16e-instruct"),
        ("Together AI", "https://api.together.xyz/v1", "meta-llama/Llama-4-Maverick-17B-128E-Instruct"),
        ("Agnes AI", "https://apihub.agnes-ai.com/v1", "agnes-2.0-flash"),
        ("Ollama (本地)", "http://localhost:11434/v1", "llama3.2"),
    ]

    var body: some View {
        Form {
            // Provider selection
            Section("AI 服务商") {
                Picker("提供商", selection: $provider) {
                    Text("Anthropic Claude").tag("claude")
                    Text("OpenAI 兼容").tag("openai")
                }
                .pickerStyle(.segmented)
            }

            // Anthropic settings
            if provider == "claude" {
                Section("Anthropic Claude 配置") {
                    HStack {
                        if showAnthropicKey {
                            TextField("API Key", text: $anthropicApiKey)
                        } else {
                            SecureField("API Key", text: $anthropicApiKey)
                        }
                        Button { showAnthropicKey.toggle() } label: {
                            Image(systemName: showAnthropicKey ? "eye.slash" : "eye")
                        }
                        .foregroundStyle(.secondary)
                    }

                    Picker("模型", selection: $anthropicModel) {
                        Text("Claude Sonnet 4 (推荐)").tag("claude-sonnet-4-20250514")
                        Text("Claude Haiku 4 (更快)").tag("claude-haiku-4-20250514")
                        Text("Claude Opus 4 (最强)").tag("claude-opus-4-20250514")
                    }
                }
            }

            // OpenAI settings
            if provider == "openai" {
                Section("OpenAI 兼容接口配置") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(presets.enumerated()), id: \.0) { index, preset in
                                Button {
                                    selectedPreset = index
                                    openaiBaseUrl = preset.1
                                    openaiModel = preset.2
                                } label: {
                                    Text(preset.0)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(selectedPreset == index ? .blue : .secondary.opacity(0.1))
                                        .foregroundStyle(selectedPreset == index ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    TextField("Base URL", text: $openaiBaseUrl)
                        .font(.caption.monospaced())
                        .onChange(of: openaiBaseUrl) { _, _ in selectedPreset = -1 }

                    HStack {
                        if showOpenaiKey {
                            TextField("API Key", text: $openaiApiKey)
                        } else {
                            SecureField("API Key", text: $openaiApiKey)
                        }
                        Button { showOpenaiKey.toggle() } label: {
                            Image(systemName: showOpenaiKey ? "eye.slash" : "eye")
                        }
                        .foregroundStyle(.secondary)
                    }

                    TextField("模型名称", text: $openaiModel)
                        .onChange(of: openaiModel) { _, _ in selectedPreset = -1 }
                }
            }

            // Preferences
            Section("偏好设置") {
                Toggle("语音合成 (TTS)", isOn: $ttsEnabled)

                VStack(alignment: .leading, spacing: 4) {
                    Text("语速: \(String(format: "%.1f", ttsRate))")
                        .font(.subheadline)
                    Slider(value: $ttsRate, in: 0.2...0.6, step: 0.05) {
                        Text("语速")
                    } minimumValueLabel: {
                        Text("慢").font(.caption2)
                    } maximumValueLabel: {
                        Text("快").font(.caption2)
                    }
                }

                Picker("主题", selection: $theme) {
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
            }

            // Data management
            Section {
                Button {
                    exportData = (try? DataService.shared.exportAllData()) ?? "{}"
                    showExportSheet = true
                } label: {
                    Label("导出数据备份", systemImage: "square.and.arrow.up")
                }
                Button {
                    showImportSheet = true
                } label: {
                    Label("导入备份", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("数据管理")
            } footer: {
                Text("所有训练数据和对话记录都存储在本地。")
            }

            // Save & Test
            Section {
                Button {
                    commitToModelAndSave()
                } label: {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isTesting ? "验证中..." : "保存并验证配置")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTesting)
            }

            // About
            Section {} footer: {
                VStack(spacing: 4) {
                    Text("已测试兼容：OpenAI · DeepSeek · Moonshot (Kimi) · Groq · Together AI · Ollama (本地) · 以及所有兼容 /v1/chat/completions 的接口")
                    Text("Made by @duanaoios")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("设置")
        .onAppear { loadFromSaved() }
        .overlay(alignment: .top) {
            if showSavedToast {
                toastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
        }
        .animation(.spring(response: 0.4), value: showSavedToast)
        .fileExporter(
            isPresented: $showExportSheet,
            document: JSONDocument(data: exportData),
            contentType: .json,
            defaultFilename: "speakup-backup-\(todayString()).json"
        ) { _ in }
        .fileImporter(
            isPresented: $showImportSheet,
            allowedContentTypes: [.json]
        ) { result in
            if case .success(let url) = result,
                let data = try? String(contentsOf: url) {
                try? DataService.shared.importAllData(from: data)
                loadFromSaved()
            }
        }
    }

    // MARK: - Load / Save

    private func loadFromSaved() {
        guard !initialized, let s = savedSettings.first else {
            // Reload after import
            if let s = savedSettings.first {
                provider = s.provider
                anthropicApiKey = s.anthropicApiKey
                anthropicModel = s.anthropicModel
                openaiApiKey = s.openaiApiKey
                openaiBaseUrl = s.openaiBaseUrl
                openaiModel = s.openaiModel
                ttsEnabled = s.ttsEnabled
                ttsRate = s.ttsRate
                theme = s.theme
            }
            return
        }
        provider = s.provider
        anthropicApiKey = s.anthropicApiKey
        anthropicModel = s.anthropicModel
        openaiApiKey = s.openaiApiKey
        openaiBaseUrl = s.openaiBaseUrl
        openaiModel = s.openaiModel
        ttsEnabled = s.ttsEnabled
        ttsRate = s.ttsRate
        theme = s.theme

        if provider == "openai" {
            if let idx = presets.firstIndex(where: { $0.1 == openaiBaseUrl && $0.2 == openaiModel }) {
                selectedPreset = idx
            }
        }
        initialized = true
    }

    private func commitToModelAndSave() {
        guard let s = savedSettings.first else { return }

        // Write local state to model
        s.provider = provider
        s.anthropicApiKey = anthropicApiKey
        s.anthropicModel = anthropicModel
        s.openaiApiKey = openaiApiKey
        s.openaiBaseUrl = openaiBaseUrl
        s.openaiModel = openaiModel
        s.ttsEnabled = ttsEnabled
        s.ttsRate = ttsRate
        s.theme = theme

        // Save to disk
        let ctx = DataService.shared.modelContext
        ctx.processPendingChanges()
        do {
            try ctx.save()
        } catch {
            toastMessage = "保存失败: \(error.localizedDescription)"
            toastSuccess = false
            showSavedToast = true
            dismissToast()
            return
        }

        // Test connection
        isTesting = true
        let aiProvider: AIProvider = provider == "openai" ? .openai : .claude
        let key = aiProvider == .claude ? anthropicApiKey : openaiApiKey
        let model = aiProvider == .claude ? anthropicModel : openaiModel
        let baseUrl = aiProvider == .openai ? openaiBaseUrl : nil

        guard !key.isEmpty else {
            toastMessage = "请先填写 API Key"
            toastSuccess = false
            showSavedToast = true
            isTesting = false
            dismissToast()
            return
        }

        let config = AIConfig(provider: aiProvider, apiKey: key, model: model, baseUrl: baseUrl)
        let service = AIServiceFactory.make(provider: aiProvider)

        Task {
            do {
                _ = try await service.getFeedback(
                    systemPrompt: "Reply with just OK",
                    userPrompt: "test",
                    config: config
                )
                await MainActor.run {
                    toastMessage = "配置验证成功"
                    toastSuccess = true
                    showSavedToast = true
                    isTesting = false
                    dismissToast()
                }
            } catch {
                await MainActor.run {
                    toastMessage = "验证失败: \(error.localizedDescription.prefix(50))"
                    toastSuccess = false
                    showSavedToast = true
                    isTesting = false
                    dismissToast()
                }
            }
        }
    }

    private func dismissToast() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showSavedToast = false
        }
    }

    private var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: toastSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(toastSuccess ? .green : .red)
            Text(toastMessage)
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    private func todayString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return String(formatter.string(from: Date()).prefix(10))
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: String
    init(data: String) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? "{}"
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data.data(using: .utf8)!)
    }
}
