import SwiftUI

extension ContentView {
    @MainActor
    func analyzeMomentResult() async {
        guard let momentResult = calcVM.momentResult else {
            calcVM.errorMessage = "请先完成时间点计算。"
            return
        }
        await analyze(
            title: "时间点行运对本命相位",
            markdown: MarkdownExportBuilder.moment(momentResult),
            streamKey: "moment",
            assignText: { aiVM.momentAnalysis = $0 },
            assignReasoning: { aiVM.momentReasoning = $0 }
        )
    }

    @MainActor
    func analyzeNatalResult() async {
        guard let momentResult = calcVM.momentResult else {
            calcVM.errorMessage = "请先完成本命盘排盘。"
            return
        }
        await analyze(
            title: "本命盘分析",
            markdown: MarkdownExportBuilder.natal(momentResult),
            streamKey: "moment",
            assignText: { aiVM.momentAnalysis = $0 },
            assignReasoning: { aiVM.momentReasoning = $0 }
        )
    }

    @MainActor
    func analyzeScanResult() async {
        guard let scanResult = calcVM.scanResult else {
            calcVM.errorMessage = "请先完成窗口扫描。"
            return
        }
        await analyze(
            title: "窗口扫描命中分析",
            markdown: MarkdownExportBuilder.scan(scanResult),
            streamKey: "scan",
            assignText: { aiVM.scanAnalysis = $0 },
            assignReasoning: { aiVM.scanReasoning = $0 }
        )
    }

    @MainActor
    func analyzeClassicalResult() async {
        guard let classicalResult = calcVM.classicalResult else {
            calcVM.errorMessage = "请先完成本命盘排盘。"
            return
        }
        await analyze(
            title: "本命盘 / 古典分析",
            markdown: MarkdownExportBuilder.classical(classicalResult),
            streamKey: "classical",
            assignText: { aiVM.classicalAnalysis = $0 },
            assignReasoning: { aiVM.classicalReasoning = $0 }
        )
    }

    @MainActor
    func analyzeHoraryResult() async {
        guard let horaryResult = calcVM.horaryResult else {
            calcVM.errorMessage = "请先完成 Horary 起盘。"
            return
        }
        await analyze(
            title: "Horary 问题分析",
            markdown: MarkdownExportBuilder.horary(horaryResult),
            streamKey: "horary",
            assignText: { aiVM.horaryAnalysis = $0 },
            assignReasoning: { aiVM.horaryReasoning = $0 }
        )
    }

    @MainActor
    func analyzeModernResult(modeKey: String, title: String, markdown: String) async {
        await analyze(
            title: title,
            markdown: markdown,
            streamKey: modeKey,
            assignText: { aiVM.modernAnalysisByMode[modeKey] = $0 },
            assignReasoning: { aiVM.modernReasoningByMode[modeKey] = $0 }
        )
    }

    /// Streaming AI analysis. Both closures run on MainActor.
    ///
    /// While streaming, accumulated text is published into `aiVM.streamBuffer`
    /// (throttled to ~10 Hz) so only `AIAnalysisView` re-renders per tick.
    /// `assignText` / `assignReasoning` receive the final text once, at the end,
    /// for per-mode persistent storage.
    @MainActor
    func analyze(
        title: String,
        markdown: String,
        streamKey: String,
        assignText: @escaping (String) -> Void,
        assignReasoning: @escaping (String) -> Void
    ) async {
        let buffer = aiVM.streamBuffer
        aiVM.isAnalyzing = true
        // Reset both fields
        assignText("")
        assignReasoning("")
        buffer.text = ""
        buffer.reasoning = ""
        buffer.activeKey = streamKey
        defer {
            aiVM.isAnalyzing = false
            buffer.activeKey = nil
        }

        let config = LLMAnalysisClient.Configuration(
            baseURL: appState.llmBaseURL,
            model: appState.llmModel,
            apiKey: appState.llmAPIKey,
            reasoningEffort: appState.aiReasoningEffort
        )

        let stream = LLMAnalysisClient().analyzeStreaming(
            title: title,
            structuredMarkdown: markdown,
            note: appState.aiNote,
            promptStyle: appState.aiPromptStyle,
            customSystemPrompt: selectedAIPromptText,
            configuration: config
        )

        var accumulatedText = ""
        var accumulatedReasoning = ""
        var lastFlush = ContinuousClock.now

        do {
            for try await chunk in stream {
                accumulatedText += chunk.content
                accumulatedReasoning += chunk.reasoning
                let now = ContinuousClock.now
                if now - lastFlush >= .milliseconds(100) {
                    buffer.text = accumulatedText
                    buffer.reasoning = accumulatedReasoning
                    lastFlush = now
                }
            }
            // If no content arrived via stream (e.g. empty response), mark error
            if accumulatedText.isEmpty {
                calcVM.errorMessage = "AI 分析返回了空内容。"
            }
        } catch {
            calcVM.errorMessage = error.localizedDescription
        }

        // Persist whatever arrived (full text, or partial text on error).
        assignText(accumulatedText)
        assignReasoning(accumulatedReasoning)
    }

    var selectedAIPromptText: String {
        switch appState.aiPromptStyle {
        case "natal":
            return appState.aiPromptNatal
        case "transit":
            return appState.aiPromptTransit
        case "scan":
            return appState.aiPromptScan
        case "classical":
            return appState.aiPromptClassical
        case "horary":
            return appState.aiPromptHorary
        default:
            return appState.aiPromptGeneral
        }
    }
}
