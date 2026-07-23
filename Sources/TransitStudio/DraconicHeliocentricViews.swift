import SwiftUI

struct DraconicHeliocentricResultPane: View {
    let result: DraconicHeliocentricResult
    @Binding var selectedTab: String

    private var tabs: [(String, String)] {
        [("draconic", "Draconic"), ("heliocentric", "日心"), ("compare", "对照"), ("assumptions", "假设")]
    }
    private var more: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: more,
                currentTabTitle: resultTabTitle(selectedTab, in: tabs, more),
                markdownProvider: { MarkdownExportBuilder.draconicHeliocentric(result) },
                jsonProvider: { TextExportBuilder.draconicHeliocentricJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "draconic_heliocentric"
            )
            MethodChromeBanner(chrome: ExpansionChromeFactory.chrome(for: .draconicHeliocentric, metaMethod: result.meta.method))
            Group {
                switch selectedTab {
                case "draconic":
                    let planets = result.draconic?.planets ?? []
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        ExpansionOverviewStrip(cards: [
                            ("Draconic 行星", "\(planets.count)", "北交平移"),
                            ("日心行星", "\(result.heliocentric?.planets?.count ?? 0)", "heliocentric"),
                        ])
                        if planets.isEmpty {
                            EmptyStateView(title: "无 Draconic 行星", systemImage: "arrow.triangle.swap", description: "结果未包含 draconic 行星表。")
                        } else {
                            Table(planets) {
                                TableColumn("天体") { Text($0.name ?? $0.bodyID) }
                                TableColumn("黄经°") { Text(String(format: "%.4f", $0.longitude)).monospacedDigit() }
                                TableColumn("坐标系") { Text($0.coordinateSystem ?? "—") }
                            }
                        }
                    }
                case "heliocentric":
                    let planets = result.heliocentric?.planets ?? []
                    if planets.isEmpty {
                        EmptyStateView(title: "无日心行星", systemImage: "arrow.triangle.swap", description: "结果未包含 heliocentric 行星表。")
                    } else {
                        Table(planets) {
                            TableColumn("天体") { Text($0.name ?? $0.bodyID) }
                            TableColumn("黄经°") { Text(String(format: "%.4f", $0.longitude)).monospacedDigit() }
                            TableColumn("中心") { Text($0.coordinateCenter ?? "—") }
                        }
                    }
                case "compare":
                    let rows = result.geoHelioComparison ?? []
                    if rows.isEmpty {
                        EmptyStateView(title: "无对照行", systemImage: "arrow.triangle.swap", description: "geo/helio 对照为空。")
                    } else {
                        Table(rows) {
                            TableColumn("天体") { Text($0.name ?? $0.bodyID) }
                            TableColumn("Δ°") { Text($0.deltaDeg.map { String(format: "%.4f", $0) } ?? "—").monospacedDigit() }
                        }
                    }
                case "assumptions":
                    AssumptionsListView(assumptions: result.calculationAssumptions ?? [])
                case "diagnostics":
                    ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
                case "json":
                    RawJSONView(value: result)
                default:
                    EmptyStateView(title: "Draconic/日心", systemImage: "arrow.triangle.swap", description: "运行计算后查看对照结果。")
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }
}
