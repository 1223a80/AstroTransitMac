import SwiftUI

struct HellenisticConditionAuditResultPane: View {
    let result: HellenisticConditionAuditResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: [("conditions", "条件证据"), ("assumptions", "假设")],
                moreTabs: [("diagnostics", "诊断"), ("json", "JSON")],
                currentTabTitle: resultTabTitle(selectedTab, in: [("conditions", "条件证据"), ("assumptions", "假设")], [("diagnostics", "诊断"), ("json", "JSON")]),
                markdownProvider: { MarkdownExportBuilder.hellenisticConditionAudit(result) },
                jsonProvider: { TextExportBuilder.hellenisticConditionAuditJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "hellenistic_condition_audit"
            )
            selectedResultView.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "conditions":
            Table(result.conditions) {
                TableColumn("Subject") { Text($0.subject) }
                TableColumn("Condition") { Text($0.conditionID) }
                TableColumn("Geometry") { Text($0.geometry ?? "") }
                TableColumn("Orb") {
                    Text($0.orb.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit()
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
            EmptyStateView(title: "条件审计", systemImage: "list.bullet.rectangle", description: "选择标签页。")
        }
    }
}
