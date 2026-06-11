import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Query(filter: #Predicate<SettingsModel> { $0.id == "singleton" })
    private var settings: [SettingsModel]

    @State private var showAnthropicKey: Bool = false
    @State private var showOpenaiKey: Bool = false
    @State private var selectedPreset: Int = -1
    @State private var showExportSheet: Bool = false
    @State private var showImportSheet: Bool = false
    @State private var exportData: String = ""
    @State private var showSavedToast: Bool = false

    private let presets: [(String, String, String)] = [
        ("OpenAI", "https://api.openai.com/v1", "gpt-4o"),
        ("DeepSeek", "https://api.deepseek.com/v1", "deepseek-chat"),
        ("Moonshot (Kimi)", "https://api.moonshot.cn/v1", "moonshot-v1-8k"),
        ("Groq", "https://api.groq.com/openai/v1", "llama-3.1-8b-instant"),
        ("Together AI", "https://api.together.xyz/v1", "meta-llama/Llama-3-8b-chat-hf"),
        ("Agnes AI", "https://apihub.agnes-ai.com/v1", "agnes-2.0-flash"),
        ("Ollama (本地)", "http://localhost:11434/v1", "llama3"),
    ]

    private var currentSettings: SettingsModel? { settings.first }

    var body: some View {
        if let s = currentSettings {
            Form {
                // Provider selection
                Section("AI 服务商") {
                    Picker("提供商", selection: Binding(
                        get: { s.provider },
                        set: { newValue in
                            s.provider = newValue
                            try? DataService.shared.modelContext.save()
                        }
                    )) {
                        Text("Anthropic Claude").tag("claude")
                        Text("OpenAI 兼容").tag("openai")
                    }
                    .pickerStyle(.segmented)
                }

                // Anthropic settings
                if s.provider == "claude" {
                    Section("Anthropic Claude 配置") {
                        HStack {
                            if showAnthropicKey {
                                TextField("API Key", text: Binding(
                                    get: { s.anthropicApiKey },
                                    set: { s.anthropicApiKey = $0; save() }
                                ))
                            } else {
                                SecureField("API Key", text: Binding(
                                    get: { s.anthropicApiKey },
                                    set: { s.anthropicApiKey = $0; save() }
                                ))
                            }
                            Button { showAnthropicKey.toggle() } label: {
                                Image(systemName: showAnthropicKey ? "eye.slash" : "eye")
                            }
                            .foregroundStyle(.secondary)
                        }

                        Picker("模型", selection: Binding(
                            get: { s.anthropicModel },
                            set: { s.anthropicModel = $0; save() }
                        )) {
                            Text("Claude Sonnet 4 (推荐)").tag("claude-sonnet-4-20250514")
                            Text("Claude Haiku 4 (更快)").tag("claude-haiku-4-20250514")
                            Text("Claude Opus 4 (最强)").tag("claude-opus-4-20250514")
                        }
                    }
                }

                // OpenAI settings
                if s.provider == "openai" {
                    Section("OpenAI 兼容接口配置") {
                        // Presets
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(presets.enumerated()), id: \.0) { index, preset in
                                    Button {
                                        selectedPreset = index
                                        s.openaiBaseUrl = preset.1
                                        s.openaiModel = preset.2
                                        save()
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

                        TextField("Base URL", text: Binding(
                            get: { s.openaiBaseUrl },
                            set: { s.openaiBaseUrl = $0; selectedPreset = -1; save() }
                        ))
                        .font(.caption.monospaced())

                        HStack {
                            if showOpenaiKey {
                                TextField("API Key", text: Binding(
                                    get: { s.openaiApiKey },
                                    set: { s.openaiApiKey = $0; save() }
                                ))
                            } else {
                                SecureField("API Key", text: Binding(
                                    get: { s.openaiApiKey },
                                    set: { s.openaiApiKey = $0; save() }
                                ))
                            }
                            Button { showOpenaiKey.toggle() } label: {
                                Image(systemName: showOpenaiKey ? "eye.slash" : "eye")
                            }
                            .foregroundStyle(.secondary)
                        }

                        TextField("模型名称", text: Binding(
                            get: { s.openaiModel },
                            set: { s.openaiModel = $0; selectedPreset = -1; save() }
                        ))
                    }
                }

                // Preferences
                Section("偏好设置") {
                    Toggle("语音合成 (TTS)", isOn: Binding(
                        get: { s.ttsEnabled },
                        set: { s.ttsEnabled = $0; save() }
                    ))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("语速: \(String(format: "%.1f", s.ttsRate))")
                            .font(.subheadline)
                        Slider(value: Binding(
                            get: { s.ttsRate },
                            set: { s.ttsRate = $0; save() }
                        ), in: 0.2...0.6, step: 0.05) {
                            Text("语速")
                        } minimumValueLabel: {
                            Text("慢").font(.caption2)
                        } maximumValueLabel: {
                            Text("快").font(.caption2)
                        }
                    }

                    Picker("主题", selection: Binding(
                        get: { s.theme },
                        set: { s.theme = $0; save() }
                    )) {
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
                    Text("所有训练数据和对话记录都存储在本地。你可以导出备份或导入恢复。")
                }

                // Save
                Section {
                    Button {
                        save()
                        showSavedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSavedToast = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showSavedToast ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .foregroundStyle(showSavedToast ? .green : .primary)
                            Text(showSavedToast ? "已保存" : "保存配置")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
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
                if case .success(let url) = result {
                    if let data = try? String(contentsOf: url) {
                        try? DataService.shared.importAllData(from: data)
                    }
                }
            }
        } else {
            ProgressView()
        }
    }

    private func save() {
        try? DataService.shared.modelContext.save()
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

    init(data: String) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        if let d = configuration.file.regularFileContents {
            self.data = String(data: d, encoding: .utf8) ?? "{}"
        } else {
            self.data = "{}"
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data.data(using: .utf8)!)
    }
}
