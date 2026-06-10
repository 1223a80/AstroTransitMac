import SwiftUI

extension ContentView {
    // MARK: - Modern Sub-Mode Result Panes

    var synastryResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .synastry(let r) = result {
                SynastryResultPane(
                    result: r,
                    selectedTab: $calcVM.modernSelectedTab,
                    streamKey: "synastry",
                    analysis: aiVM.modernAnalysisByMode["synastry", default: ""],
                    reasoning: aiVM.modernReasoningByMode["synastry", default: ""],
                    isAnalyzing: aiVM.isAnalyzing,
                    canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await analyzeModernResult(modeKey: "synastry", title: "Synastry 关系分析", markdown: MarkdownModernExportBuilder.synastry(r)) }
                }
            } else {
                EmptyStateView(title: "等待 Synastry 计算", systemImage: "person.2", description: "填写两人出生信息后开始计算。")
            }
        }
    }

    var compositeResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .composite(let r) = result {
                CompositeDavisonResultPane(
                    title: "Composite",
                    result: r,
                    selectedTab: $calcVM.modernSelectedTab,
                    streamKey: "composite",
                    analysis: aiVM.modernAnalysisByMode["composite", default: ""],
                    reasoning: aiVM.modernReasoningByMode["composite", default: ""],
                    isAnalyzing: aiVM.isAnalyzing,
                    canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await analyzeModernResult(modeKey: "composite", title: "Composite 关系盘分析", markdown: MarkdownModernExportBuilder.compositeOrDavison(title: "Composite", result: r)) }
                }
            } else {
                EmptyStateView(title: "等待 Composite 计算", systemImage: "circle.hexagongrid", description: "填写两人出生信息后开始计算。")
            }
        }
    }

    var davisonResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .davison(let r) = result {
                CompositeDavisonResultPane(
                    title: "Davison",
                    result: r,
                    selectedTab: $calcVM.modernSelectedTab,
                    streamKey: "davison",
                    analysis: aiVM.modernAnalysisByMode["davison", default: ""],
                    reasoning: aiVM.modernReasoningByMode["davison", default: ""],
                    isAnalyzing: aiVM.isAnalyzing,
                    canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await analyzeModernResult(modeKey: "davison", title: "Davison 关系盘分析", markdown: MarkdownModernExportBuilder.compositeOrDavison(title: "Davison", result: r)) }
                }
            } else {
                EmptyStateView(title: "等待 Davison 计算", systemImage: "arrow.triangle.merge", description: "填写两人出生信息后开始计算。")
            }
        }
    }

    var progressionResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .progression(let r) = result {
                ProgressionResultPane(
                    result: r,
                    selectedTab: $calcVM.modernSelectedTab,
                    streamKey: "progression",
                    analysis: aiVM.modernAnalysisByMode["progression", default: ""],
                    reasoning: aiVM.modernReasoningByMode["progression", default: ""],
                    isAnalyzing: aiVM.isAnalyzing,
                    canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await analyzeModernResult(modeKey: "progression", title: "次限推进盘分析", markdown: MarkdownModernExportBuilder.progression(r)) }
                }
            } else {
                EmptyStateView(title: "等待次限推进计算", systemImage: "forward.fill", description: "填写出生和参考时间后开始计算。")
            }
        }
    }

    var solarArcResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .solarArc(let r) = result {
                SolarArcResultPane(
                    result: r,
                    selectedTab: $calcVM.modernSelectedTab,
                    streamKey: "solar_arc",
                    analysis: aiVM.modernAnalysisByMode["solar_arc", default: ""],
                    reasoning: aiVM.modernReasoningByMode["solar_arc", default: ""],
                    isAnalyzing: aiVM.isAnalyzing,
                    canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await analyzeModernResult(modeKey: "solar_arc", title: "Solar Arc 盘分析", markdown: MarkdownModernExportBuilder.solarArc(r)) }
                }
            } else {
                EmptyStateView(title: "等待 Solar Arc 计算", systemImage: "sun.max", description: "填写出生和参考时间后开始计算。")
            }
        }
    }

    var harmonicResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .harmonic(let r) = result {
                HarmonicResultPane(result: r, selectedTab: $calcVM.modernSelectedTab)
            } else {
                EmptyStateView(title: "等待 Harmonic 计算", systemImage: "music.note.list", description: "选择调和阶数后开始计算。")
            }
        }
    }
}
