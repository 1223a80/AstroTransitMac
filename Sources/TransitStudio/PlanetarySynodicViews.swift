import SwiftUI

struct PlanetarySynodicResultPane: View {
    let result: PlanetarySynodicResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { MarkdownExportBuilder.planetarySynodic(result) },
                jsonProvider: { TextExportBuilder.planetarySynodicJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "planetary_synodic"
            )
            MethodChromeBanner(chrome: ExpansionChromeFactory.chrome(for: .planetarySynodic, metaMethod: result.meta.method))
            selectedResultView.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [("events", "相位事件"), ("cycles", "会合周期"), ("contacts", "本命接触"), ("assumptions", "假设")]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String { resultTabTitle(selectedTab, in: tabs, moreTabs) }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "events":
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                ExpansionOverviewStrip(cards: [
                    ("相位事件", "\(result.events.count)", "窗口内"),
                    ("会合周期", "\(result.cycles.count)", "完整周期"),
                ])
                if result.events.isEmpty {
                    EmptyStateView(title: "无相位事件", systemImage: "arrow.triangle.2.circlepath", description: "当前窗口没有会合相位命中。")
                } else {
                    Table(result.events) {
                        TableColumn("本地") { Text($0.exactLocal ?? $0.exactUTC).monospacedDigit() }
                        TableColumn("相位") { Text($0.phaseName ?? $0.phaseID ?? "—") }
                        TableColumn("次序") {
                            Text("\($0.passIndexInWindow.map(String.init) ?? "—")/\($0.passCountInWindow.map(String.init) ?? "—")")
                        }
                        TableColumn("相对速度") {
                            Text($0.relativeSpeed.map { String(format: "%.5f", $0) } ?? "—").monospacedDigit()
                        }
                    }
                }
            }
        case "cycles":
            if result.cycles.isEmpty {
                EmptyStateView(title: "无会合周期", systemImage: "arrow.triangle.2.circlepath", description: "窗口内没有完整会合周期。")
            } else {
                Table(result.cycles) {
                    TableColumn("起") { Text($0.startLocal ?? $0.startUTC ?? "—").monospacedDigit() }
                    TableColumn("止") { Text($0.endLocal ?? $0.endUTC ?? "—").monospacedDigit() }
                    TableColumn("天数") {
                        Text($0.durationDays.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                    }
                }
            }
        case "contacts":
            let contacts = result.events.flatMap { event in
                (event.natalContacts ?? []).map { ($0, event) }
            }
            if contacts.isEmpty {
                EmptyStateView(title: "无本命接触", systemImage: "link", description: "提供 birth + target_point_set 可计算接触。")
            } else {
                Table(contacts.map { ContactWrap(contact: $0.0, event: $0.1) }) {
                    TableColumn("相位") { Text($0.event.phaseName ?? "—") }
                    TableColumn("本命点") { Text($0.contact.bodyID) }
                    TableColumn("接触相位") { Text($0.contact.aspectName ?? $0.contact.aspectID ?? "—") }
                    TableColumn("精确 UTC") { Text($0.contact.exactUTC).monospacedDigit() }
                }
            }
        case "assumptions":
            AssumptionsListView(assumptions: result.calculationAssumptions ?? [])
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            EmptyStateView(title: "会合周期", systemImage: "arrow.triangle.2.circlepath", description: "运行计算后查看会合结果。")
        }
    }

    private struct ContactWrap: Identifiable {
        let contact: CycleContact
        let event: SynodicPhaseEvent
        var id: String { contact.id }
    }
}
