import SwiftUI

struct ClassicalVisibilityResultPane: View {
    let result: ClassicalVisibilityResult
    @Binding var selectedTab: String

    private var chrome: ExpansionChromeModel {
        ExpansionChromeFactory.chrome(for: .classicalVisibility, metaMethod: result.meta.method)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { MarkdownExportBuilder.classicalVisibility(result) },
                jsonProvider: { TextExportBuilder.classicalVisibilityJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "classical_visibility"
            )
            MethodChromeBanner(chrome: chrome)
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [("heliacal", "偕日升降"), ("rise_set", "升落"), ("hours", "行星时"), ("assumptions", "假设")]
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
        case "heliacal":
            if result.heliacalEvents.isEmpty {
                EmptyStateView(title: "无偕日升降事件", systemImage: "eye", description: "当前地点/时刻未产生 heliacal 行。")
            } else {
                Table(result.heliacalEvents) {
                    TableColumn("天体") { Text($0.bodyName ?? $0.bodyID) }
                    TableColumn("事件") { Text($0.eventType) }
                    TableColumn("状态") { Text($0.status ?? "—") }
                    TableColumn("本地") { Text($0.exactLocal ?? $0.exactUTC ?? "—").monospacedDigit() }
                }
            }
        case "rise_set":
            if result.riseSet.isEmpty {
                EmptyStateView(title: "无升落数据", systemImage: "eye", description: "当前结果没有升落行。")
            } else {
                Table(result.riseSet) {
                    TableColumn("天体") { Text($0.bodyName ?? $0.bodyID) }
                    TableColumn("升起") { Text($0.riseLocal ?? $0.riseUTC ?? "—").monospacedDigit() }
                    TableColumn("落下") { Text($0.setLocal ?? $0.setUTC ?? "—").monospacedDigit() }
                }
            }
        case "hours":
            if let hours = result.planetaryHours, hours.status == "ok", let rows = hours.hours {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    Text("日主：\(hours.dayRulerName ?? hours.dayRulerID ?? "") · 昼时 \(hours.dayHourMinutes.map { String(format: "%.1f" , $0) } ?? "—") 分 / 夜时 \(hours.nightHourMinutes.map { String(format: "%.1f", $0) } ?? "—") 分")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                    Table(rows) {
                        TableColumn("时段") { Text($0.period) }
                        TableColumn("序号") { Text("\($0.hourIndex)") }
                        TableColumn("主星") { Text($0.rulerName ?? $0.rulerID) }
                        TableColumn("起") { Text($0.startLocal ?? $0.startUTC).monospacedDigit() }
                        TableColumn("止") { Text($0.endLocal ?? $0.endUTC).monospacedDigit() }
                    }
                }
            } else {
                EmptyStateView(
                    title: "行星时不可用",
                    systemImage: "clock",
                    description: result.planetaryHours?.reason ?? "可能因极区无升落而未生成小时表。"
                )
            }
        case "assumptions":
            AssumptionsListView(assumptions: result.calculationAssumptions ?? [])
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            EmptyStateView(title: "古典可见性", systemImage: "eye", description: "选择标签页查看结果。")
        }
    }
}
