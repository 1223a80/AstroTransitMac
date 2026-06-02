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
            assign: { momentAIAnalysis = $0 }
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
            assign: { momentAIAnalysis = $0 }
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
            assign: { scanAIAnalysis = $0 }
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
            assign: { classicalAIAnalysis = $0 }
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
            assign: { horaryAIAnalysis = $0 }
        )
    }

    @MainActor
    func analyze(title: String, markdown: String, assign: @escaping (String) -> Void) async {
        isAnalyzingAI = true
        defer { isAnalyzingAI = false }
        do {
            let response = try await LLMAnalysisClient().analyze(
                title: title,
                structuredMarkdown: markdown,
                note: aiNote,
                promptStyle: aiPromptStyle,
                customSystemPrompt: selectedAIPromptText,
                configuration: .init(baseURL: llmBaseURL, model: llmModel, apiKey: llmAPIKey)
            )
            assign(response)
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
