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
            if result.cycles.isEmpty {
                EmptyStateView(title: "无逆行周期", systemImage: "arrow.uturn.backward.circle", description: "窗口内没有完整逆行站配对。")
            } else {
                Table(result.cycles) {
                    TableColumn("Body") { Text($0.bodyName ?? $0.bodyID) }
                    TableColumn("Pre") { Text($0.preShadowStartLocal ?? $0.preShadowStartUTC ?? "—").monospacedDigit() }
                    TableColumn("Retro") { Text($0.retrogradeStationLocal ?? $0.retrogradeStationUTC ?? "—").monospacedDigit() }
                    TableColumn("Direct") { Text($0.directStationLocal ?? $0.directStationUTC ?? "—").monospacedDigit() }
                    TableColumn("Post") { Text($0.postShadowEndLocal ?? $0.postShadowEndUTC ?? "—").monospacedDigit() }
                    TableColumn("Days") {
                        Text($0.retrogradeDurationDays.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                    }
                }
            }
        case "stations":
            Table(result.stations) {
                TableColumn("Local") { Text($0.exactLocal ?? $0.exactUTC).monospacedDigit() }
                TableColumn("Body") { Text($0.bodyName ?? $0.bodyID) }
                TableColumn("Kind") { Text($0.stationKind) }
                TableColumn("Lon") {
                    Text($0.longitude.map { String(format: "%.4f", $0) } ?? "—").monospacedDigit()
                }
            }
        case "assumptions":
            ScrollView {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(result.calculationAssumptions ?? [], id: \.self) { item in
                        Text("• \(item)").foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            EmptyStateView(title: "逆行周期", systemImage: "arrow.uturn.backward.circle", description: "选择标签页查看结果。")
        }
    }
}
