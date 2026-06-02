import SwiftUI

struct AIAnalysisView: View {
    let analysis: String
    let isAnalyzing: Bool
    let canAnalyze: Bool
    let analyze: () -> Void

    @AppStorage("llmModel") private var llmModel = "glm-4.7-flash"
    @AppStorage("savedLLMModels") private var savedLLMModels = "glm-4.7-flash"
    @AppStorage("aiPromptStyle") private var aiPromptStyle = "general"
    @AppStorage("aiNote") private var aiNote = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI 分析")
                    .font(.headline)
                Spacer()
                Picker("模型", selection: $llmModel) {
                    ForEach(savedModelList, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
                CopyMarkdownButton(markdown: analysis)
                Button {
                    analyze()
                } label: {
                    Label(isAnalyzing ? "分析中" : "生成分析", systemImage: isAnalyzing ? "hourglass" : "sparkles")
                }
                .disabled(isAnalyzing || !canAnalyze)
            }

            HStack(alignment: .top, spacing: 12) {
                Picker("提示词", selection: $aiPromptStyle) {
                    Text("通用").tag("general")
                    Text("本命盘").tag("natal")
                    Text("行运").tag("transit")
                    Text("窗口扫描").tag("scan")
                    Text("古典").tag("classical")
                    Text("Horary").tag("horary")
                }
                .frame(width: 180)

                TextField("备注会随排盘数据一起发送给 API", text: $aiNote)
                    .textFieldStyle(.roundedBorder)
            }

            if analysis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyStateView(
                    title: canAnalyze ? "尚未生成 AI 分析" : "请先在设置页填写 API Key",
                    systemImage: "sparkles",
                    description: canAnalyze ? "排盘后可生成结构化解读。" : "API Key 会保存到本地设置。"
                )
            } else {
                ScrollView {
                    MarkdownBlocksView(markdown: normalizedMarkdown)
                }
            }
        }
    }

    private var savedModelList: [String] {
        let models = savedLLMModels
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return models.isEmpty ? [llmModel] : models
    }

    private var normalizedMarkdown: String {
        analysis
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n### ", with: "\n\n### ")
            .replacingOccurrences(of: "\n## ", with: "\n\n## ")
            .replacingOccurrences(of: "\n# ", with: "\n\n# ")
    }
}

private struct MarkdownBlocksView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(4)
    }

    private var blocks: [String] {
        markdown
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    @ViewBuilder
    private func blockView(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("### ") {
            Text(String(trimmed.dropFirst(4)))
                .font(.headline)
                .padding(.top, 10)
        } else if trimmed.hasPrefix("## ") {
            Text(String(trimmed.dropFirst(3)))
                .font(.title3.weight(.semibold))
                .padding(.top, 12)
        } else if trimmed.hasPrefix("# ") {
            Text(String(trimmed.dropFirst(2)))
                .font(.title2.weight(.semibold))
                .padding(.top, 12)
        } else if trimmed.isEmpty {
            Spacer()
                .frame(height: 4)
        } else {
            Text((try? AttributedString(markdown: line)) ?? AttributedString(line))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
