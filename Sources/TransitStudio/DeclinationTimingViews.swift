import SwiftUI

struct DeclinationTimingResultPane: View {
    let result: DeclinationTimingResult
    @Binding var selectedTab: String

    private var chrome: ExpansionChromeModel {
        ExpansionChromeFactory.chrome(
            for: .declinationTiming,
            metaMethod: result.meta.method,
            extras: ExpansionChromeExtras(oobThresholdMethod: result.meta.oobThresholdMethod)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { MarkdownExportBuilder.declinationTiming(result) },
                jsonProvider: { TextExportBuilder.declinationTimingJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "declination_timing"
            )
            MethodChromeBanner(chrome: chrome)
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [("events", "赤纬事件"), ("stations", "赤纬停滞"), ("oob", "OOB"), ("assumptions", "假设")]
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
        case "events":
            eventTable(result.events)
        case "stations":
            eventTable(result.events.filter { $0.eventType == "declination_station" })
        case "oob":
            eventTable(result.events.filter { $0.eventType == "oob_entry" || $0.eventType == "oob_exit" })
        case "assumptions":
            assumptionsView
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            eventTable(result.events)
        }
    }

    @ViewBuilder
    private func eventTable(_ events: [DeclinationTimingEvent]) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            if selectedTab == "events" {
                ExpansionOverviewStrip(cards: [
                    ("事件数", "\(result.events.count)", "窗口内"),
                    ("OOB 方法", result.meta.oobThresholdMethod ?? "—", "阈值"),
                ])
            }
            if events.isEmpty {
                EmptyStateView(
                    title: "无事件",
                    systemImage: "arrow.up.and.down.circle",
                    description: "当前筛选下没有赤纬事件。"
                )
            } else {
                Table(events.sorted(by: { $0.exactUTC < $1.exactUTC })) {
                    TableColumn("本地") { Text($0.exactLocal).monospacedDigit() }
                    TableColumn("次序") { Text("\($0.passIndexInWindow)/\($0.passCountInWindow)").monospacedDigit() }
                    TableColumn("行运点") { Text($0.movingPointName) }
                    TableColumn("事件") { Text($0.aspectName ?? $0.eventType) }
                    TableColumn("目标") { Text($0.targetPointName ?? "—") }
                    TableColumn("赤纬°") {
                        Text(String(format: "%.4f", $0.movingDeclination)).monospacedDigit()
                    }
                    TableColumn("精确差") {
                        Text($0.exactOrb.map { String(format: "%.6f", $0) } ?? "—").monospacedDigit()
                    }
                }
            }
        }
    }

    private var assumptionsView: some View {
        AssumptionsListView(
            assumptions: result.calculationAssumptions ?? [],
            footer: [
                result.meta.oobThresholdMethod.map { "OOB 阈值方法：\($0)" },
                result.meta.oobThresholdSample.map { String(format: "样本阈值：%.6f°", $0) },
            ].compactMap { $0 }.joined(separator: " · ")
        )
    }
}
