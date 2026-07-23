import SwiftUI

struct ClassicalDerivativesResultPane: View {
    let result: ClassicalDerivativesResult
    @Binding var selectedTab: String
    private var tabs: [(String, String)] { [("dodeka", "十二分盘"), ("monomoiria", "一度主"), ("topical", "主题Almuten")] }
    private var more: [(String, String)] { [("assumptions", "假设"), ("diagnostics", "诊断"), ("json", "JSON")] }

    private var chrome: ExpansionChromeModel {
        let monoKeys = result.monomoiria.compactMap(\.methodKey)
        let hasProxy = monoKeys.contains { $0.localizedCaseInsensitiveContains("proxy") }
        return ExpansionChromeFactory.chrome(
            for: .classicalDerivatives,
            metaMethod: result.meta.method,
            extras: ExpansionChromeExtras(rowMethodKeys: Array(Set(monoKeys)).sorted(), hasProxyMethodKey: hasProxy)
        )
    }

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
            MethodChromeBanner(chrome: chrome)
            Group {
                switch selectedTab {
                case "monomoiria":
                    if result.monomoiria.isEmpty {
                        EmptyStateView(title: "无一度主", systemImage: "square.split.2x1", description: "monomoiria 为空。")
                    } else {
                        Table(result.monomoiria) {
                            TableColumn("源点") { Text($0.sourceName ?? $0.sourceId ?? "—") }
                            TableColumn("度数") { Text($0.degreeIndex.map(String.init) ?? "—") }
                            TableColumn("主星") { Text($0.monomoiriaRuler ?? "—") }
                            TableColumn("method_key") { Text($0.methodKey ?? "—").font(.caption) }
                        }
                    }
                case "topical":
                    if result.topicalAlmutens.isEmpty {
                        EmptyStateView(title: "无主题 Almuten", systemImage: "square.split.2x1", description: "topical_almutens 为空。")
                    } else {
                        Table(result.topicalAlmutens) {
                            TableColumn("主题") { Text($0.topicName ?? $0.topicId ?? "—") }
                            TableColumn("胜出") { Text($0.winnerId ?? "—") }
                            TableColumn("分值") { Text($0.winnerScore.map(String.init) ?? "—").monospacedDigit() }
                        }
                    }
                case "assumptions":
                    AssumptionsListView(assumptions: result.calculationAssumptions ?? [])
                case "diagnostics":
                    ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
                case "json":
                    RawJSONView(value: result)
                default:
                    if result.dodekatemoria.isEmpty {
                        EmptyStateView(title: "无十二分盘", systemImage: "square.split.2x1", description: "dodekatemoria 为空。")
                    } else {
                        Table(result.dodekatemoria) {
                            TableColumn("源点") { Text($0.sourceName ?? $0.sourceId ?? "—") }
                            TableColumn("本命°") { Text($0.natalLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                            TableColumn("十二分°") { Text($0.dodekatemorionLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                            TableColumn("星座") { Text($0.sign ?? "—") }
                            TableColumn("主星") { Text($0.dodekatemorionRuler ?? "—") }
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }
}
