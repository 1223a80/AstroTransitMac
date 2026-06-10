import SwiftUI

@MainActor
final class AIAnalysisViewModel: ObservableObject {
    @Published var isAnalyzing = false

    // MARK: - Analysis results by mode
    @Published var momentAnalysis = ""
    @Published var momentReasoning = ""
    @Published var scanAnalysis = ""
    @Published var scanReasoning = ""
    @Published var classicalAnalysis = ""
    @Published var classicalReasoning = ""
    @Published var horaryAnalysis = ""
    @Published var horaryReasoning = ""

    // MARK: - Modern sub-mode analysis
    @Published var modernAnalysisByMode: [String: String] = [:]
    @Published var modernReasoningByMode: [String: String] = [:]
}
