import SwiftUI

struct ClassicalVisibilityResultPane: View {
    let result: ClassicalVisibilityResult
    @Binding var selectedTab: String

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
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [("heliacal", "Heliacal"), ("rise_set", "升落"), ("hours", "行星时"), ("assumptions", "假设")]
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
            Table(result.heliacalEvents) {
                TableColumn("Body") { Text($0.bodyName ?? $0.bodyID) }
                TableColumn("Event") { Text($0.eventType) }
                TableColumn("Status") { Text($0.status ?? "") }
                TableColumn("Local") { Text($0.exactLocal ?? $0.exactUTC ?? "—").monospacedDigit() }
            }
        case "rise_set":
            Table(result.riseSet) {
                TableColumn("Body") { Text($0.bodyName ?? $0.bodyID) }
                TableColumn("Rise") { Text($0.riseLocal ?? $0.riseUTC ?? "—").monospacedDigit() }
                TableColumn("Set") { Text($0.setLocal ?? $0.setUTC ?? "—").monospacedDigit() }
            }
        case "hours":
            if let hours = result.planetaryHours, hours.status == "ok", let rows = hours.hours {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    Text("日主：\(hours.dayRulerName ?? hours.dayRulerID ?? "") · 昼时 \(hours.dayHourMinutes.map { String(format: "%.1f" , $0) } ?? "—") 分 / 夜时 \(hours.nightHourMinutes.map { String(format: "%.1f", $0) } ?? "—") 分")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                    Table(rows) {
                        TableColumn("Period") { Text($0.period) }
                        TableColumn("#") { Text("\($0.hourIndex)") }
                        TableColumn("Ruler") { Text($0.rulerName ?? $0.rulerID) }
                        TableColumn("Start") { Text($0.startLocal ?? $0.startUTC).monospacedDigit() }
                        TableColumn("End") { Text($0.endLocal ?? $0.endUTC).monospacedDigit() }
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
            ScrollView {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(result.calculationAssumptions ?? [], id: \.self) { Text("• \($0)").foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            EmptyStateView(title: "古典可见性", systemImage: "eye", description: "选择标签页查看结果。")
        }
    }
}
