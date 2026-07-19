import SwiftUI

struct ClassicalDerivativesResultPane: View {
    let result: ClassicalDerivativesResult
    @Binding var selectedTab: String
    private var tabs: [(String, String)] { [("dodeka", "十二分盘"), ("monomoiria", "一度主"), ("topical", "主题Almuten")] }
    private var more: [(String, String)] { [("assumptions", "假设"), ("diagnostics", "诊断"), ("json", "JSON")] }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: more,
                currentTabTitle: resultTabTitle(selectedTab, in: tabs, more),
                markdownProvider: { MarkdownExportBuilder.classicalDerivatives(result) },
                jsonProvider: { TextExportBuilder.classicalDerivativesJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "classical_derivatives"
            )
            Group {
                switch selectedTab {
                case "monomoiria":
                    Table(result.monomoiria) {
                        TableColumn("Source") { Text($0.sourceName ?? $0.sourceId ?? "—") }
                        TableColumn("Degree") { Text($0.degreeIndex.map(String.init) ?? "—") }
                        TableColumn("Ruler") { Text($0.monomoiriaRuler ?? "—") }
                        TableColumn("Method") { Text($0.methodKey ?? "").font(.caption) }
                    }
                case "topical":
                    Table(result.topicalAlmutens) {
                        TableColumn("Topic") { Text($0.topicName ?? $0.topicId ?? "—") }
                        TableColumn("Winner") { Text($0.winnerId ?? "—") }
                        TableColumn("Score") { Text($0.winnerScore.map(String.init) ?? "—").monospacedDigit() }
                    }
                case "assumptions":
                    ScrollView {
                        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                            ForEach(result.calculationAssumptions ?? [], id: \.self) {
                                Text("• \($0)").foregroundStyle(.secondary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                case "diagnostics":
                    ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
                case "json":
                    RawJSONView(value: result)
                default:
                    Table(result.dodekatemoria) {
                        TableColumn("Source") { Text($0.sourceName ?? $0.sourceId ?? "—") }
                        TableColumn("Natal°") { Text($0.natalLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("Dodeka°") { Text($0.dodekatemorionLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("Sign") { Text($0.sign ?? "—") }
                        TableColumn("Ruler") { Text($0.dodekatemorionRuler ?? "—") }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }
}
