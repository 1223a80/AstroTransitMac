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
            assignText: { aiVM.horaryAnalysis = $0 },
            assignReasoning: { aiVM.horaryReasoning = $0 }
        )
    }

    @MainActor
    func analyzeModernResult(modeKey: String, title: String, markdown: String) async {
        await analyze(
            title: title,
            markdown: markdown,
            assignText: { aiVM.modernAnalysisByMode[modeKey] = $0 },
            assignReasoning: { aiVM.modernReasoningByMode[modeKey] = $0 }
        )
    }

    /// Streaming AI analysis. Both closures run on MainActor.
    /// `assignText` receives the full accumulated visible text on each chunk;
    /// `assignReasoning` receives the full accumulated reasoning text.
    @MainActor
    func analyze(
        title: String,
        markdown: String,
        assignText: @escaping (String) -> Void,
        assignReasoning: @escaping (String) -> Void
    ) async {
        aiVM.isAnalyzing = true
        // Reset both fields
        assignText("")
        assignReasoning("")
        defer { aiVM.isAnalyzing = false }

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

        do {
            for try await chunk in stream {
                if !chunk.content.isEmpty {
                    accumulatedText += chunk.content
                    assignText(accumulatedText)
                }
                if !chunk.reasoning.isEmpty {
                    accumulatedReasoning += chunk.reasoning
                    assignReasoning(accumulatedReasoning)
                }
            }
            // If no content arrived via stream (e.g. empty response), mark error
            if accumulatedText.isEmpty {
                calcVM.errorMessage = "AI 分析返回了空内容。"
            }
        } catch {
            calcVM.errorMessage = error.localizedDescription
        }
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
