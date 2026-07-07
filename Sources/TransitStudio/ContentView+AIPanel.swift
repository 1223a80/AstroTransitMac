import SwiftUI

// MARK: - Global AI slide-out panel
//
// AI analysis is no longer a tab inside each result pane; it lives in a
// right-edge panel that can be opened from any view. The panel binds to the
// analysis context of whatever mode is currently active.
extension ContentView {

    struct AIPanelContext {
        let streamKey: String
        let title: String
        let analysis: String
        let reasoning: String
        let hasResult: Bool
        let analyze: () -> Void
    }

    var aiPanelContext: AIPanelContext? {
        guard !isShowingAppSettingsPage else { return nil }
        switch mode {
        case .settings:
            if practiceMode == .classical {
                return AIPanelContext(
                    streamKey: "classical",
                    title: "古典排盘",
                    analysis: aiVM.classicalAnalysis,
                    reasoning: aiVM.classicalReasoning,
                    hasResult: calcVM.classicalResult != nil
                ) { Task { await analyzeClassicalResult() } }
            }
            if practiceMode == .vedic {
                return AIPanelContext(
                    streamKey: "vedic",
                    title: "吠陀排盘",
                    analysis: aiVM.vedicAnalysis,
                    reasoning: aiVM.vedicReasoning,
                    hasResult: calcVM.vedicResult != nil
                ) { Task { await analyzeVedicResult() } }
            }
            if modernSubMode == .natal {
                return AIPanelContext(
                    streamKey: "moment",
                    title: "现代本命盘",
                    analysis: aiVM.momentAnalysis,
                    reasoning: aiVM.momentReasoning,
                    hasResult: calcVM.momentResult != nil
                ) { Task { await analyzeNatalResult() } }
            }
            return nil
        case .horary:
            return AIPanelContext(
                streamKey: "horary",
                title: "Horary",
                analysis: aiVM.horaryAnalysis,
                reasoning: aiVM.horaryReasoning,
                hasResult: calcVM.horaryResult != nil
            ) { Task { await analyzeHoraryResult() } }
        case .moment:
            return AIPanelContext(
                streamKey: "moment",
                title: "时间点",
                analysis: aiVM.momentAnalysis,
                reasoning: aiVM.momentReasoning,
                hasResult: calcVM.momentResult != nil
            ) { Task { await analyzeMomentResult() } }
        case .scan:
            return AIPanelContext(
                streamKey: "scan",
                title: "窗口扫描",
                analysis: aiVM.scanAnalysis,
                reasoning: aiVM.scanReasoning,
                hasResult: calcVM.scanResult != nil
            ) { Task { await analyzeScanResult() } }
        case .rectify:
            return nil
        }
    }

    var aiPanelColumn: some View {
        HStack(spacing: 0) {
            aiPanelHandle
            if isAIPanelOpen {
                Rectangle()
                    .fill(TS.SemanticColor.line)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                aiPanelContent
                    .frame(width: Self.aiPanelWidth)
            }
        }
    }

    static let aiPanelWidth: CGFloat = 380

    private var aiPanelHandle: some View {
        VStack(spacing: TS.Spacing.md) {
            Spacer(minLength: 0)
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TS.SemanticColor.gold)
            VStack(spacing: 0) {
                Text("A")
                Text("I")
            }
            .font(TS.Font.label.weight(.semibold))
            .foregroundStyle(TS.SemanticColor.inkSoft)
            VStack(spacing: 0) {
                Text("分")
                Text("析")
            }
            .font(TS.Font.label)
            .foregroundStyle(TS.SemanticColor.inkSoft)
            Image(systemName: isAIPanelOpen ? "chevron.right" : "chevron.left")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(TS.SemanticColor.inkFaint)
            Spacer(minLength: 0)
        }
        .frame(width: 26)
        .frame(maxHeight: .infinity)
        .background(TS.SemanticColor.paperRaised)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) {
                isAIPanelOpen.toggle()
            }
        }
        .help(isAIPanelOpen ? "收起 AI 分析" : "展开 AI 分析")
    }

    @ViewBuilder
    private var aiPanelContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: TS.Spacing.md) {
                Image(systemName: "sparkles")
                    .foregroundStyle(TS.SemanticColor.gold)
                Text(aiPanelContext.map { "AI 分析 · \($0.title)" } ?? "AI 分析")
                    .font(TS.Font.sectionTitle)
                    .foregroundStyle(TS.SemanticColor.ink)
                Spacer(minLength: 0)
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isAIPanelOpen = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TS.SemanticColor.inkFaint)
                }
                .buttonStyle(.plain)
            }
            .padding(TS.Padding.cardInner)

            Divider()

            if let context = aiPanelContext {
                if context.hasResult {
                    AIAnalysisView(
                        streamKey: context.streamKey,
                        analysis: context.analysis,
                        reasoning: context.reasoning,
                        isAnalyzing: aiVM.isAnalyzing,
                        canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        analyze: context.analyze
                    )
                    .padding(TS.Padding.cardInner)
                } else {
                    EmptyStateView(
                        title: "先完成计算",
                        systemImage: "sparkles",
                        description: "本页计算出结果后即可生成 AI 分析。"
                    )
                }
            } else {
                EmptyStateView(
                    title: "此页面暂不支持 AI 分析",
                    systemImage: "sparkles",
                    description: "切换到本命、古典、吠陀、Horary、时间点或扫描页试试。"
                )
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(TS.SemanticColor.card)
    }
}
