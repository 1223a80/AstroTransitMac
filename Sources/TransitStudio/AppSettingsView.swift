import SwiftUI

private struct SettingsPickerOption: Identifiable {
    let id: String
    let title: String
}

private let ephemerisRequirementOptions = [
    SettingsPickerOption(id: "warn", title: "缺小行星星历时警告并跳过"),
    SettingsPickerOption(id: "strict", title: "缺小行星星历时停止"),
    SettingsPickerOption(id: "skip", title: "缺小行星星历时静默跳过")
]

struct AppSettingsView: View {
    var usesFixedFrame = true

    @AppStorage("pythonPath") private var pythonPath = BackendClient.suggestedPythonPath()
    @AppStorage("ephemerisPath") private var ephemerisPath = ""
    @AppStorage("noAsteroids") private var noAsteroids = false
    @AppStorage("requireEphemeris") private var requireEphemeris = "warn"
    @AppStorage("autoDownloadAsteroids") private var autoDownloadAsteroids = true
    @AppStorage("llmBaseURL") private var llmBaseURL = "https://open.bigmodel.cn/api/paas/v4"
    @AppStorage("llmModel") private var llmModel = "glm-4.7-flash"
    @AppStorage("llmAPIKey") private var llmAPIKey = ""
    @AppStorage("savedLLMModels") private var savedLLMModels = "glm-4.7-flash"
    @AppStorage("aiPromptStyle") private var aiPromptStyle = "general"
    @AppStorage("aiReasoningEffort") private var aiReasoningEffort = "max"
    @AppStorage("aiPromptGeneral") private var aiPromptGeneral = AIPromptDefaults.text(for: "general")
    @AppStorage("aiPromptNatal") private var aiPromptNatal = AIPromptDefaults.text(for: "natal")
    @AppStorage("aiPromptTransit") private var aiPromptTransit = AIPromptDefaults.text(for: "transit")
    @AppStorage("aiPromptScan") private var aiPromptScan = AIPromptDefaults.text(for: "scan")
    @AppStorage("aiPromptClassical") private var aiPromptClassical = AIPromptDefaults.text(for: "classical")
    @AppStorage("aiPromptHorary") private var aiPromptHorary = AIPromptDefaults.text(for: "horary")
    @AppStorage("aiNote") private var aiNote = ""

    @State private var swissephStatus = "正在检测 pyswisseph..."
    @State private var apiTestStatus = ""
    @State private var isTestingAPI = false
    @State private var asteroidIDs = "2101 2102 4450 7066 10370 19308"
    @State private var isDownloadingAsteroids = false
    @State private var asteroidDownloadLog = ""

    var body: some View {
        TabView {
            settingsPage { pythonSettings }
                .tabItem { Label("后端", systemImage: "terminal") }
            settingsPage { aiSettings }
                .tabItem { Label("AI", systemImage: "sparkles") }
            settingsPage { asteroidCommandSettings }
                .tabItem { Label("小行星", systemImage: "arrow.down.circle") }
        }
        .padding(16)
        .frame(width: usesFixedFrame ? 620 : nil, height: usesFixedFrame ? 640 : nil)
        .task(id: pythonPath) {
            swissephStatus = await BackendClient.swissephStatus(pythonPath: pythonPath)
        }
        .tint(.accentColor)
    }

    private var pythonSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsTitle("Python / Swiss Ephemeris", subtitle: "后端解释器、星历路径和缺文件策略。")

            field("Python 可执行文件", text: $pythonPath, placeholder: "/opt/homebrew/bin/python3")
            Text(swissephStatus)
                .font(.caption)
                .foregroundStyle(swissephStatus.hasPrefix("已") ? .green : .orange)

            field("Ephemeris 文件夹 可选", text: $ephemerisPath, placeholder: "~/Library/Application Support/TransitStudio/ephe")
            Text("留空时普通行星使用 app 内置星历；输入自定义小行星时会自动使用推荐目录（~/Library/Application Support/TransitStudio/ephe）。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("自动下载缺失的小行星星历", isOn: $autoDownloadAsteroids)
                .toggleStyle(.checkbox)

            Toggle("不计算小行星", isOn: $noAsteroids)
                .toggleStyle(.checkbox)

            pickerRow("小行星星历", selection: $requireEphemeris, options: ephemerisRequirementOptions)

            Spacer()
        }
    }

    private var aiSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsTitle("AI 分析", subtitle: "API、模型、默认提示词和发送给 AI 的备注。")

            field("API Base URL", text: $llmBaseURL, placeholder: "https://open.bigmodel.cn/api/paas/v4")

            VStack(alignment: .leading, spacing: 6) {
                Text("模型名")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Picker("模型名", selection: $llmModel) {
                        ForEach(savedModelList, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 210)

                    TextField("glm-4.7-flash", text: $llmModel)
                        .textFieldStyle(.roundedBorder)

                    Button("保存模型") {
                        saveCurrentModel()
                    }
                    Button("删除") {
                        deleteCurrentModel()
                    }
                    .disabled(savedModelList.count <= 1)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("输入后自动保存到本地设置", text: $llmAPIKey)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button {
                    Task { await testAPIKey() }
                } label: {
                    Label(isTestingAPI ? "测试中" : "测试 API Key", systemImage: isTestingAPI ? "hourglass" : "checkmark.seal")
                }
                .disabled(isTestingAPI || llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Text(apiTestStatus)
                    .font(.caption)
                    .foregroundStyle(apiTestStatus.hasPrefix("成功") ? .green : .secondary)
            }

            pickerRow("思考深度", selection: $aiReasoningEffort, options: [
                .init(id: "", title: "关"),
                .init(id: "low", title: "低"),
                .init(id: "medium", title: "中"),
                .init(id: "high", title: "高"),
                .init(id: "max", title: "最大"),
            ])

            pickerRow("默认提示词", selection: $aiPromptStyle, options: promptStyleOptions)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("默认提示词内容")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("恢复默认") {
                        selectedPromptText.wrappedValue = AIPromptDefaults.text(for: aiPromptStyle)
                    }
                }
                TextEditor(text: selectedPromptText)
                    .font(.body)
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("备注")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $aiNote)
                    .font(.body)
                    .frame(height: 130)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    )
            }

            Spacer()
        }
    }

    private var asteroidCommandSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsTitle("小行星数据", subtitle: "计算会自动检查并下载缺失文件；这里用于提前补齐或复制脚本。")

            field("小行星编号", text: $asteroidIDs, placeholder: "2101 2102 4450")
            Toggle("计算前自动下载缺失文件", isOn: $autoDownloadAsteroids)
                .toggleStyle(.checkbox)

            HStack {
                Button {
                    Task { await downloadAsteroids() }
                } label: {
                    Label(isDownloadingAsteroids ? "下载中" : "开始下载", systemImage: isDownloadingAsteroids ? "hourglass" : "arrow.down.circle")
                }
                .disabled(isDownloadingAsteroids || parsedAsteroidIDs.isEmpty)
                CopyMarkdownButton(markdown: asteroidDownloadCommand, title: "复制命令")
                SaveTextButton(text: asteroidDownloadCommand, title: "保存脚本", defaultFilename: "download_asteroids.sh")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(asteroidDownloadLog.isEmpty ? "终端命令预览" : "下载日志")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView {
                    Text(asteroidDownloadLog.isEmpty ? asteroidDownloadCommand : asteroidDownloadLog)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 260)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                )
            }

            Spacer()
        }
    }

    private var savedModelList: [String] {
        let models = savedLLMModels
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return models.isEmpty ? ["glm-4.7-flash"] : models
    }

    private var promptStyleOptions: [SettingsPickerOption] {
        [
            SettingsPickerOption(id: "general", title: "通用"),
            SettingsPickerOption(id: "natal", title: "本命盘"),
            SettingsPickerOption(id: "transit", title: "行运"),
            SettingsPickerOption(id: "scan", title: "窗口扫描"),
            SettingsPickerOption(id: "classical", title: "古典"),
            SettingsPickerOption(id: "horary", title: "Horary")
        ]
    }

    private var selectedPromptText: Binding<String> {
        switch aiPromptStyle {
        case "natal":
            return $aiPromptNatal
        case "transit":
            return $aiPromptTransit
        case "scan":
            return $aiPromptScan
        case "classical":
            return $aiPromptClassical
        case "horary":
            return $aiPromptHorary
        default:
            return $aiPromptGeneral
        }
    }

    private var parsedAsteroidIDs: [Int] {
        asteroidIDs
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" || $0 == ";" }
            .compactMap { Int($0) }
            .filter { $0 > 0 }
    }

    private var asteroidDownloadCommand: String {
        AsteroidEphemerisManager.command(for: parsedAsteroidIDs, ephemerisPath: ephemerisPath)
    }

    @MainActor
    private func downloadAsteroids() async {
        isDownloadingAsteroids = true
        asteroidDownloadLog = ""
        defer { isDownloadingAsteroids = false }

        do {
            let result = try await AsteroidEphemerisManager.ensureAsteroids(
                ids: parsedAsteroidIDs,
                configuredEphemerisPath: ephemerisPath,
                bundledEphemerisPath: bundledEphemerisPath,
                requireEphemeris: requireEphemeris
            ) { message in
                await MainActor.run {
                    asteroidDownloadLog = message
                }
            }
            asteroidDownloadLog = result.log.isEmpty ? "小行星星历已就绪。" : result.log
            if ephemerisPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ephemerisPath = result.effectiveEphemerisPath ?? AsteroidEphemerisManager.recommendedEphemerisPath
            }
        } catch {
            asteroidDownloadLog = "下载失败：\(error.localizedDescription)"
        }
    }

    private var bundledEphemerisPath: String? {
        if let url = AppResources.url(forResource: "seas_18", withExtension: "se1", subdirectory: "ephemeris") {
            return url.deletingLastPathComponent().path
        }
        if let url = AppResources.url(forResource: "seas_18", withExtension: "se1") {
            return url.deletingLastPathComponent().path
        }
        return nil
    }

    private func saveCurrentModel() {
        let model = llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { return }
        var models = savedModelList
        if !models.contains(model) {
            models.append(model)
        }
        savedLLMModels = models.joined(separator: "\n")
        llmModel = model
    }

    private func deleteCurrentModel() {
        let model = llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let models = savedModelList.filter { $0 != model }
        guard !models.isEmpty else { return }
        savedLLMModels = models.joined(separator: "\n")
        llmModel = models[0]
    }

    @MainActor
    private func testAPIKey() async {
        isTestingAPI = true
        apiTestStatus = ""
        defer { isTestingAPI = false }
        do {
            _ = try await LLMAnalysisClient().analyze(
                title: "API Key 测试",
                structuredMarkdown: "请只回复 OK。",
                note: "",
                promptStyle: "general",
                customSystemPrompt: aiPromptGeneral,
                configuration: .init(baseURL: llmBaseURL, model: llmModel, apiKey: llmAPIKey)
            )
            apiTestStatus = "成功：API Key 可用"
            saveCurrentModel()
        } catch {
            apiTestStatus = "失败：\(error.localizedDescription)"
        }
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func pickerRow(_ title: String, selection: Binding<String>, options: [SettingsPickerOption]) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .labelsHidden()
            .frame(width: 260)
        }
    }

    private func settingsPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
    }

    private func settingsTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }
}
