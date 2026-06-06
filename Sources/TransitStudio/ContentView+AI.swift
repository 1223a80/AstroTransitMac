import SwiftUI

extension ContentView {
    @MainActor
    func analyzeMomentResult() async {
        guard let momentResult else {
            errorMessage = "请先完成时间点计算。"
            return
        }
        await analyze(
            title: "时间点行运对本命相位",
            markdown: MarkdownExportBuilder.moment(momentResult),
            assignText: { momentAIAnalysis = $0 },
            assignReasoning: { momentAIReasoning = $0 }
        )
    }

    @MainActor
    func analyzeNatalResult() async {
        guard let momentResult else {
            errorMessage = "请先完成本命盘排盘。"
            return
        }
        await analyze(
            title: "本命盘分析",
            markdown: MarkdownExportBuilder.natal(momentResult),
            assignText: { momentAIAnalysis = $0 },
            assignReasoning: { momentAIReasoning = $0 }
        )
    }

    @MainActor
    func analyzeScanResult() async {
        guard let scanResult else {
            errorMessage = "请先完成窗口扫描。"
            return
        }
        await analyze(
            title: "窗口扫描命中分析",
            markdown: MarkdownExportBuilder.scan(scanResult),
            assignText: { scanAIAnalysis = $0 },
            assignReasoning: { scanAIReasoning = $0 }
        )
    }

    @MainActor
    func analyzeClassicalResult() async {
        guard let classicalResult else {
            errorMessage = "请先完成本命盘排盘。"
            return
        }
        await analyze(
            title: "本命盘 / 古典分析",
            markdown: MarkdownExportBuilder.classical(classicalResult),
            assignText: { classicalAIAnalysis = $0 },
            assignReasoning: { classicalAIReasoning = $0 }
        )
    }

    @MainActor
    func analyzeHoraryResult() async {
        guard let horaryResult else {
            errorMessage = "请先完成 Horary 起盘。"
            return
        }
        await analyze(
            title: "Horary 问题分析",
            markdown: MarkdownExportBuilder.horary(horaryResult),
            assignText: { horaryAIAnalysis = $0 },
            assignReasoning: { horaryAIReasoning = $0 }
        )
    }

    @MainActor
    func analyzeModernResult(modeKey: String, title: String, markdown: String) async {
        await analyze(
            title: title,
            markdown: markdown,
            assignText: { modernAIAnalysisByMode[modeKey] = $0 },
            assignReasoning: { modernAIReasoningByMode[modeKey] = $0 }
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
        isAnalyzingAI = true
        // Reset both fields
        assignText("")
        assignReasoning("")
        defer { isAnalyzingAI = false }

        let config = LLMAnalysisClient.Configuration(
            baseURL: llmBaseURL,
            model: llmModel,
            apiKey: llmAPIKey,
            reasoningEffort: aiReasoningEffort
        )

        let stream = LLMAnalysisClient().analyzeStreaming(
            title: title,
            structuredMarkdown: markdown,
            note: aiNote,
            promptStyle: aiPromptStyle,
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
                errorMessage = "AI 分析返回了空内容。"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var selectedAIPromptText: String {
        switch aiPromptStyle {
        case "natal":
            return aiPromptNatal
        case "transit":
            return aiPromptTransit
        case "scan":
            return aiPromptScan
        case "classical":
            return aiPromptClassical
        case "horary":
            return aiPromptHorary
        default:
            return aiPromptGeneral
        }
    }
}
