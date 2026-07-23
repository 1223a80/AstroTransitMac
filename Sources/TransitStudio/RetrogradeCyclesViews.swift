import SwiftUI

struct RetrogradeCyclesResultPane: View {
    let result: RetrogradeCyclesResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { MarkdownExportBuilder.retrogradeCycles(result) },
                jsonProvider: { TextExportBuilder.retrogradeCyclesJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "retrograde_cycles"
            )
            MethodChromeBanner(chrome: ExpansionChromeFactory.chrome(for: .retrogradeCycles, metaMethod: result.meta.method))
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [("cycles", "逆行周期"), ("stations", "站度"), ("assumptions", "假设")]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        resultTabTitle(selectedTab, in: tabs, moreTabs)
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "cycles":
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                ExpansionOverviewStrip(cards: [
                    ("周期数", "\(result.cycles.count)", "完整配对"),
                    ("站度数", "\(result.stations.count)", "站度事件"),
                ])
                if result.cycles.isEmpty {
                    EmptyStateView(title: "无逆行周期", systemImage: "arrow.uturn.backward.circle", description: "窗口内没有完整逆行站配对。")
                } else {
                    Table(result.cycles) {
                        TableColumn("天体") { Text($0.bodyName ?? $0.bodyID) }
                        TableColumn("前阴影起") { Text($0.preShadowStartLocal ?? $0.preShadowStartUTC ?? "—").monospacedDigit() }
                        TableColumn("逆行站") { Text($0.retrogradeStationLocal ?? $0.retrogradeStationUTC ?? "—").monospacedDigit() }
                        TableColumn("顺行站") { Text($0.directStationLocal ?? $0.directStationUTC ?? "—").monospacedDigit() }
                        TableColumn("后阴影止") { Text($0.postShadowEndLocal ?? $0.postShadowEndUTC ?? "—").monospacedDigit() }
                        TableColumn("天数") {
                            Text($0.retrogradeDurationDays.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                        }
                    }
                }
            }
        case "stations":
            if result.stations.isEmpty {
                EmptyStateView(title: "无站度", systemImage: "arrow.uturn.backward.circle", description: "窗口内没有站度事件。")
            } else {
                Table(result.stations) {
                    TableColumn("本地") { Text($0.exactLocal ?? $0.exactUTC).monospacedDigit() }
                    TableColumn("天体") { Text($0.bodyName ?? $0.bodyID) }
                    TableColumn("类型") { Text($0.stationKind) }
                    TableColumn("黄经°") {
                        Text($0.longitude.map { String(format: "%.4f", $0) } ?? "—").monospacedDigit()
                    }
                }
            }
        case "assumptions":
            AssumptionsListView(assumptions: result.calculationAssumptions ?? [])
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            EmptyStateView(title: "逆行周期", systemImage: "arrow.uturn.backward.circle", description: "运行计算后查看逆行阴影结果。")
        }
    }
}
