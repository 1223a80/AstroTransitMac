import SwiftUI

/// Tracks the current stage of a streaming AI analysis.
enum StreamingPhase: Equatable {
    /// Model is producing reasoning / chain-of-thought text.
    case thinking
    /// Model is generating the visible response text.
    case generating
    /// Streaming has finished.
    case done
}

struct AIAnalysisView: View {
    let analysis: String
    let reasoning: String
    let isAnalyzing: Bool
    let canAnalyze: Bool
    let analyze: () -> Void

    @AppStorage("llmModel") private var llmModel = "glm-4.7-flash"
    @AppStorage("savedLLMModels") private var savedLLMModels = "glm-4.7-flash"
    @AppStorage("aiPromptStyle") private var aiPromptStyle = "general"
    @AppStorage("aiNote") private var aiNote = ""
    @AppStorage("aiReasoningEffort") private var aiReasoningEffort = "max"

    @State private var reasoningExpanded = true

    private var streamingPhase: StreamingPhase {
        guard isAnalyzing else { return .done }
        if !analysis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .generating
        }
        if !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .thinking
        }
        return .thinking
    }

    private var actionButtonLabel: String {
        guard isAnalyzing else { return "生成分析" }
        switch streamingPhase {
        case .thinking: return "思考中"
        case .generating: return "生成中"
        case .done: return "生成分析"
        }
    }

    private var actionButtonIcon: String {
        guard isAnalyzing else { return "sparkles" }
        switch streamingPhase {
        case .thinking: return "brain.head.profile"
        case .generating: return "sparkles"
        case .done: return "sparkles"
        }
    }

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
                    Label(actionButtonLabel, systemImage: actionButtonIcon)
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

            // Reasoning (thinking) section — collapsible
            if !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            reasoningExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: reasoningExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                            Text("💭 思考过程")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            if streamingPhase == .thinking {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(height: 12)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if reasoningExpanded {
                        ScrollView {
                            Text(reasoning)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 200)
                        .padding(8)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            // Main analysis text
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
