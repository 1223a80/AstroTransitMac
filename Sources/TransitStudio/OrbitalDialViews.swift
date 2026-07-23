import SwiftUI

struct OrbitalDialResultPane: View {
    let result: OrbitalDialResult
    @Binding var selectedTab: String
    private var tabs: [(String, String)] { [("dial", "轨道点"), ("pictures", "行星图")] }
    private var more: [(String, String)] { [("assumptions", "假设"), ("diagnostics", "诊断"), ("json", "JSON")] }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: more,
                currentTabTitle: resultTabTitle(selectedTab, in: tabs, more),
                markdownProvider: { MarkdownExportBuilder.orbitalDial(result) },
                jsonProvider: { TextExportBuilder.orbitalDialJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "orbital_dial"
            )
            MethodChromeBanner(chrome: ExpansionChromeFactory.chrome(for: .orbitalDial, metaMethod: result.meta.method))
            Group {
                switch selectedTab {
                case "pictures":
                    if result.dialPictures.isEmpty {
                        EmptyStateView(title: "无行星图", systemImage: "circle.dotted", description: "dial_pictures 为空。")
                    } else {
                        Table(result.dialPictures) {
                            TableColumn("行星图") { Text($0.picture ?? "—") }
                            TableColumn("中点°") { Text($0.midpointLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                            TableColumn("模数") { Text($0.modulus.map(String.init) ?? "—") }
                            TableColumn("method_key") { Text($0.methodKey ?? "—").font(.caption) }
                        }
                    }
                case "assumptions":
                    AssumptionsListView(assumptions: result.calculationAssumptions ?? [])
                case "diagnostics":
                    ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
                case "json":
                    RawJSONView(value: result)
                default:
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        ExpansionOverviewStrip(cards: [
                            ("轨道点", "\(result.orbitalPoints.count)", "nodes/apsides"),
                            ("行星图", "\(result.dialPictures.count)", "pictures"),
                        ])
                        if result.orbitalPoints.isEmpty {
                            EmptyStateView(title: "无轨道点", systemImage: "circle.dotted", description: "orbital_points 为空。")
                        } else {
                            Table(result.orbitalPoints) {
                                TableColumn("天体") { Text($0.bodyId ?? "—") }
                                TableColumn("种类") { Text($0.pointKind ?? "—") }
                                TableColumn("黄经°") { Text($0.longitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                                TableColumn("中心") { Text($0.coordinateCenter ?? "—") }
                                TableColumn("坐标系") { Text($0.coordinateSystem ?? "—") }
                            }
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }
}
