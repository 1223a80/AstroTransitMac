import SwiftUI

/// Hot streaming text, observed only by `AIAnalysisView`. Kept outside the
/// per-mode @Published storage so per-token updates don't invalidate the
/// whole ContentView tree.
@MainActor
final class AIStreamBuffer: ObservableObject {
    /// Stream key of the analysis currently receiving tokens; nil when idle.
    @Published var activeKey: String?
    @Published var text = ""
    @Published var reasoning = ""
}

@MainActor
final class AIAnalysisViewModel: ObservableObject {
    @Published var isAnalyzing = false
    let streamBuffer = AIStreamBuffer()

    // MARK: - Analysis results by mode
    @Published var momentAnalysis = ""
    @Published var momentReasoning = ""
    @Published var scanAnalysis = ""
    @Published var scanReasoning = ""
    @Published var classicalAnalysis = ""
    @Published var classicalReasoning = ""
    @Published var horaryAnalysis = ""
    @Published var horaryReasoning = ""
    @Published var vedicAnalysis = ""
    @Published var vedicReasoning = ""

    // MARK: - Modern sub-mode analysis
    @Published var modernAnalysisByMode: [String: String] = [:]
    @Published var modernReasoningByMode: [String: String] = [:]
}
