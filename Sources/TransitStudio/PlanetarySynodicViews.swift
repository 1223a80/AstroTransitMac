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
            Table(result.events) {
                TableColumn("Local") { Text($0.exactLocal ?? $0.exactUTC).monospacedDigit() }
                TableColumn("Phase") { Text($0.phaseName ?? $0.phaseID ?? "") }
                TableColumn("Pass") {
                    Text("\($0.passIndexInWindow.map(String.init) ?? "")/\($0.passCountInWindow.map(String.init) ?? "")")
                }
                TableColumn("Rel v") {
                    Text($0.relativeSpeed.map { String(format: "%.5f", $0) } ?? "—").monospacedDigit()
                }
            }
        case "cycles":
            Table(result.cycles) {
                TableColumn("Start") { Text($0.startLocal ?? $0.startUTC ?? "—").monospacedDigit() }
                TableColumn("End") { Text($0.endLocal ?? $0.endUTC ?? "—").monospacedDigit() }
                TableColumn("Days") {
                    Text($0.durationDays.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
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
                    TableColumn("Phase") { Text($0.event.phaseName ?? "") }
                    TableColumn("Natal") { Text($0.contact.bodyID) }
                    TableColumn("Aspect") { Text($0.contact.aspectName ?? $0.contact.aspectID ?? "") }
                    TableColumn("Exact") { Text($0.contact.exactUTC).monospacedDigit() }
                }
            }
        case "assumptions":
            ScrollView {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(result.calculationAssumptions ?? [], id: \.self) {
                        Text("• \($0)").foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            EmptyStateView(title: "会合周期", systemImage: "arrow.triangle.2.circlepath", description: "选择标签页查看结果。")
        }
    }

    private struct ContactWrap: Identifiable {
        let contact: CycleContact
        let event: SynodicPhaseEvent
        var id: String { contact.id }
    }
}
