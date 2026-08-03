import SwiftUI

private struct AnalysisStreamResult {
    let text: String
    let reasoning: String
}

private struct AnalysisStreamFailure: LocalizedError {
    let underlying: Error
    let partialResult: AnalysisStreamResult

    var errorDescription: String? {
        if let localized = underlying as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return underlying.localizedDescription
    }
}

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
        guard let natalResult = calcVM.modernNatalResult else {
            calcVM.errorMessage = "请先完成本命盘排盘。"
            return
        }
        await analyze(
            title: "本命盘分析",
            markdown: MarkdownExportBuilder.natal(natalResult),
            streamKey: "natal",
            assignText: { aiVM.natalAnalysis = $0 },
            assignReasoning: { aiVM.natalReasoning = $0 }
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
            // Keep the report data-only here. The selected prompt is sent once,
            // as customSystemPrompt inside analyze().
            markdown: MarkdownExportBuilder.horary(horaryResult),
            streamKey: "horary",
            promptStyle: "horary",
            assignText: { aiVM.horaryAnalysis = $0 },
            assignReasoning: { aiVM.horaryReasoning = $0 }
        )
    }

    @MainActor
    func analyzeVedicResult() async {
        guard let vedicResult = calcVM.vedicResult else {
            calcVM.errorMessage = "请先完成吠陀排盘。"
            return
        }
        await analyze(
            title: "吠陀本命盘分析",
            markdown: MarkdownExportBuilder.vedic(vedicResult, sections: Set(MarkdownExportBuilder.ExportSection.vedicSectionIDs)),
            streamKey: "vedic",
            assignText: { aiVM.vedicAnalysis = $0 },
            assignReasoning: { aiVM.vedicReasoning = $0 }
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

    /// Streaming AI analysis. Both persistence closures run on MainActor.
    ///
    /// While streaming, only fresh deltas are published into `aiVM.streamBuffer`
    /// (throttled to ~10 Hz). The network consume loop stays off MainActor, so
    /// high-token-rate streams do not queue one UI actor hop per token.
    /// `assignText` / `assignReasoning` receive the final text once, at the end,
    /// for per-mode persistent storage.
    @MainActor
    func analyze(
        title: String,
        markdown: String,
        streamKey: String,
        promptStyle: String? = nil,
        assignText: @escaping (String) -> Void,
        assignReasoning: @escaping (String) -> Void
    ) async {
        let buffer = aiVM.streamBuffer
        aiVM.isAnalyzing = true
        assignText("")
        assignReasoning("")
        buffer.begin(key: streamKey)
        defer {
            aiVM.isAnalyzing = false
            buffer.finish()
        }

        let config = LLMAnalysisClient.Configuration(
            baseURL: appState.llmBaseURL,
            model: appState.llmModel,
            apiKey: appState.llmAPIKey,
            reasoningEffort: appState.aiReasoningEffort
        )

        // Mode-specific callers (e.g. Horary) pin their own prompt style so the
        // analysis always uses the matching prompt, regardless of the global
        // aiPromptStyle selection.
        let effectiveStyle = promptStyle ?? appState.aiPromptStyle

        let stream = LLMAnalysisClient().analyzeStreaming(
            title: title,
            structuredMarkdown: markdown,
            note: appState.aiNote,
            promptStyle: effectiveStyle,
            customSystemPrompt: selectedAIPromptText(for: effectiveStyle),
            configuration: config
        )

        var finalText = ""
        var finalReasoning = ""

        do {
            let result = try await Self.consumeAnalysisStream(stream) { textDelta, reasoningDelta in
                buffer.append(textDelta: textDelta, reasoningDelta: reasoningDelta)
            }
            finalText = result.text
            finalReasoning = result.reasoning

            if finalText.isEmpty {
                calcVM.errorMessage = "AI 分析返回了空内容。"
            }
        } catch let failure as AnalysisStreamFailure {
            finalText = failure.partialResult.text
            finalReasoning = failure.partialResult.reasoning
            calcVM.errorMessage = failure.localizedDescription
        } catch {
            calcVM.errorMessage = error.localizedDescription
        }

        // Persist whatever arrived (full text, or partial text on error).
        assignText(finalText)
        assignReasoning(finalReasoning)
    }

    nonisolated private static func consumeAnalysisStream(
        _ stream: AsyncThrowingStream<StreamChunk, Error>,
        publishDelta: @escaping @MainActor @Sendable (_ textDelta: String, _ reasoningDelta: String) -> Void
    ) async throws -> AnalysisStreamResult {
        var textParts: [String] = []
        var reasoningParts: [String] = []
        textParts.reserveCapacity(512)
        reasoningParts.reserveCapacity(512)

        var pendingText = ""
        var pendingReasoning = ""
        pendingText.reserveCapacity(4096)
        pendingReasoning.reserveCapacity(4096)

        var lastFlush = ContinuousClock.now

        func flushPending() async {
            guard !pendingText.isEmpty || !pendingReasoning.isEmpty else {
                return
            }
            let textDelta = pendingText
            let reasoningDelta = pendingReasoning
            pendingText.removeAll(keepingCapacity: true)
            pendingReasoning.removeAll(keepingCapacity: true)
            await publishDelta(textDelta, reasoningDelta)
        }

        do {
            for try await chunk in stream {
                if !chunk.content.isEmpty {
                    textParts.append(chunk.content)
                    pendingText += chunk.content
                }
                if !chunk.reasoning.isEmpty {
                    reasoningParts.append(chunk.reasoning)
                    pendingReasoning += chunk.reasoning
                }

                let now = ContinuousClock.now
                if now - lastFlush >= .milliseconds(100) {
                    await flushPending()
                    lastFlush = now
                }
            }
            await flushPending()
            return AnalysisStreamResult(text: textParts.joined(), reasoning: reasoningParts.joined())
        } catch {
            await flushPending()
            let partial = AnalysisStreamResult(text: textParts.joined(), reasoning: reasoningParts.joined())
            throw AnalysisStreamFailure(underlying: error, partialResult: partial)
        }
    }

    var selectedAIPromptText: String {
        selectedAIPromptText(for: appState.aiPromptStyle)
    }

    func selectedAIPromptText(for style: String) -> String {
        switch style {
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
