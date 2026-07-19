import SwiftUI

struct DeclinationTimingResultPane: View {
    let result: DeclinationTimingResult
    @Binding var selectedTab: String

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
        if events.isEmpty {
            EmptyStateView(
                title: "无事件",
                systemImage: "arrow.up.and.down.circle",
                description: "当前筛选下没有赤纬事件。"
            )
        } else {
            Table(events.sorted(by: { $0.exactUTC < $1.exactUTC })) {
                TableColumn("Local") { Text($0.exactLocal).monospacedDigit() }
                TableColumn("Pass") { Text("\($0.passIndexInWindow)/\($0.passCountInWindow)").monospacedDigit() }
                TableColumn("Mover") { Text($0.movingPointName) }
                TableColumn("Event") { Text($0.aspectName ?? $0.eventType) }
                TableColumn("Target") { Text($0.targetPointName ?? "—") }
                TableColumn("δ°") {
                    Text(String(format: "%.4f", $0.movingDeclination)).monospacedDigit()
                }
                TableColumn("Exact") {
                    Text($0.exactOrb.map { String(format: "%.6f", $0) } ?? "—").monospacedDigit()
                }
            }
        }
    }

    private var assumptionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text("计算假设")
                    .font(TS.Font.sectionTitle)
                ForEach(result.calculationAssumptions ?? [], id: \.self) { item in
                    Text("• \(item)")
                        .font(TS.Font.body)
                        .foregroundStyle(.secondary)
                }
                if let method = result.meta.oobThresholdMethod {
                    Text("OOB 阈值方法：\(method)")
                        .font(TS.Font.label)
                }
                if let sample = result.meta.oobThresholdSample {
                    Text(String(format: "样本阈值：%.6f°", sample))
                        .font(TS.Font.label)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
