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
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var streamBuffer: AIStreamBuffer

    let streamKey: String
    let analysis: String
    let reasoning: String
    let isAnalyzing: Bool
    let canAnalyze: Bool
    let analyze: () -> Void

    @State private var reasoningExpanded = true
    @State private var settingsExpanded = false

    /// Whether this pane is the one currently receiving streamed tokens.
    private var isStreamingHere: Bool {
        isAnalyzing && streamBuffer.activeKey == streamKey
    }

    private var hasAnalysisContent: Bool {
        isStreamingHere ? streamBuffer.hasText : !analysis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasReasoningContent: Bool {
        isStreamingHere ? streamBuffer.hasReasoning : !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var streamingPhase: StreamingPhase {
        guard isAnalyzing else { return .done }
        if isStreamingHere {
            if streamBuffer.hasText {
                return .generating
            }
            return .thinking
        }
        return hasAnalysisContent ? .generating : .thinking
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
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            // Title row: title + action buttons only
            HStack {
                Text("分析操作")
                    .font(TS.Font.sectionTitle)
                Spacer()
                CopyMarkdownButton(textProvider: {
                    isStreamingHere ? streamBuffer.currentText() : analysis
                })
                Button {
                    analyze()
                } label: {
                    Label(actionButtonLabel, systemImage: actionButtonIcon)
                }
                .disabled(isAnalyzing || !canAnalyze)
            }

            // Collapsible settings area
            DisclosureGroup("AI 设置", isExpanded: $settingsExpanded) {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    HStack(spacing: TS.Spacing.lg) {
                        LabeledContent("模型") {
                            Picker("", selection: $appState.llmModel) {
                                ForEach(savedModelList, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 170)
                        }

                        LabeledContent("提示词") {
                            Picker("", selection: $appState.aiPromptStyle) {
                                Text("通用").tag("general")
                                Text("本命盘").tag("natal")
                                Text("行运").tag("transit")
                                Text("窗口扫描").tag("scan")
                                Text("古典").tag("classical")
                                Text("Horary").tag("horary")
                            }
                            .labelsHidden()
                            .frame(width: 140)
                        }
                    }

                    TextField("备注会随排盘数据一起发送给 API", text: $appState.aiNote)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.top, TS.Spacing.sm)
            }
            .font(TS.Font.label)

            // Reasoning (thinking) section — collapsible
            if hasReasoningContent {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            reasoningExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: TS.Spacing.md) {
                            Image(systemName: reasoningExpanded ? "chevron.down" : "chevron.right")
                                .font(TS.Font.label)
                            Text("思考过程")
                                .font(TS.Font.sectionTitle)
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
                            if isStreamingHere {
                                StreamingTextSegmentsView(segments: streamBuffer.reasoningSegments, isSecondary: true)
                            } else {
                                Text(reasoning)
                                    .font(TS.Font.body)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxHeight: 200)
                        .padding(TS.Padding.cardInner)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.chip))
                    }
                }
            }

            // Main analysis text
            if !hasAnalysisContent {
                EmptyStateView(
                    title: canAnalyze ? "尚未生成 AI 分析" : "请先在设置页填写 API Key",
                    systemImage: "sparkles",
                    description: canAnalyze ? "排盘后可生成结构化解读。" : "API Key 会保存到本地设置。"
                )
            } else if isStreamingHere {
                // Streaming: plain text only. Full markdown parsing is deferred
                // until the stream finishes — re-parsing the whole document on
                // every tick is O(n²) and stalls the main thread.
                ScrollView {
                    StreamingTextSegmentsView(segments: streamBuffer.textSegments)
                        .padding(TS.Padding.resultContent)
                }
            } else {
                ScrollView {
                    MarkdownBlocksView(markdown: normalizedMarkdown)
                }
            }
        }
    }

    private var savedModelList: [String] {
        let models = appState.savedLLMModels
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return models.isEmpty ? [appState.llmModel] : models
    }

    private var normalizedMarkdown: String {
        analysis
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n### ", with: "\n\n### ")
            .replacingOccurrences(of: "\n## ", with: "\n\n## ")
            .replacingOccurrences(of: "\n# ", with: "\n\n# ")
    }
}

private struct StreamingTextSegmentsView: View {
    let segments: [AIStreamBuffer.Segment]
    var isSecondary = false

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(segments) { segment in
                segmentText(segment.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func segmentText(_ text: String) -> some View {
        if text.isEmpty {
            Spacer()
                .frame(height: TS.Spacing.md)
        } else {
            let view = Text(text)
                .font(TS.Font.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isSecondary {
                view.foregroundStyle(.secondary)
            } else {
                view
            }
        }
    }
}

private struct MarkdownBlocksView: View {
    let markdown: String

    private struct Block: Identifiable {
        enum Kind {
            case heading1(String)
            case heading2(String)
            case heading3(String)
            case gap
            case paragraph(AttributedString)
        }

        let id: Int
        let kind: Kind
    }

    // Parsed once per markdown change, not on every render — AttributedString
    // markdown parsing is too expensive to repeat inside `body`.
    @State private var blocks: [Block] = []

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            ForEach(blocks) { block in
                blockView(block)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TS.Padding.resultContent)
        .onAppear {
            blocks = Self.parse(markdown)
        }
        .onChange(of: markdown) { newValue in
            blocks = Self.parse(newValue)
        }
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block.kind {
        case .heading3(let text):
            Text(text)
                .font(TS.Font.sectionTitle)
                .padding(.top, TS.Spacing.lg)
        case .heading2(let text):
            Text(text)
                .font(TS.Font.pageTitle)
                .padding(.top, TS.Spacing.xl)
        case .heading1(let text):
            Text(text)
                .font(.title2.weight(.semibold))
                .padding(.top, TS.Spacing.xl)
        case .gap:
            Spacer()
                .frame(height: TS.Spacing.sm)
        case .paragraph(let attributed):
            Text(attributed)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static func parse(_ markdown: String) -> [Block] {
        markdown
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { offset, lineSub in
                let line = String(lineSub)
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let kind: Block.Kind
                if trimmed.hasPrefix("### ") {
                    kind = .heading3(String(trimmed.dropFirst(4)))
                } else if trimmed.hasPrefix("## ") {
                    kind = .heading2(String(trimmed.dropFirst(3)))
                } else if trimmed.hasPrefix("# ") {
                    kind = .heading1(String(trimmed.dropFirst(2)))
                } else if trimmed.isEmpty {
                    kind = .gap
                } else {
                    kind = .paragraph((try? AttributedString(markdown: line)) ?? AttributedString(line))
                }
                return Block(id: offset, kind: kind)
            }
    }
}
