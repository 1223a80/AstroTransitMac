import SwiftUI

struct PrimaryDirectionsAuditResultPane: View {
    let result: PrimaryDirectionsAuditResult
    @Binding var selectedTab: String
    private var tabs: [(String, String)] { [("audit", "主限审计"), ("assumptions", "假设")] }
    private var more: [(String, String)] { [("diagnostics", "诊断"), ("json", "JSON")] }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: more,
                currentTabTitle: resultTabTitle(selectedTab, in: tabs, more),
                markdownProvider: { MarkdownExportBuilder.primaryDirectionsAudit(result) },
                jsonProvider: { TextExportBuilder.primaryDirectionsAuditJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "primary_directions_audit"
            )
            Group {
                switch selectedTab {
                case "assumptions":
                    ScrollView {
                        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                            Text("Algorithm: \(result.meta.algorithmName ?? result.meta.method)")
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
                    Table(result.directions) {
                        TableColumn("Promissor") { Text($0.promissor ?? $0.promissorId ?? "—") }
                        TableColumn("Significator") { Text($0.significator ?? $0.significatorId ?? "—") }
                        TableColumn("Dir") { Text($0.directionType ?? "—") }
                        TableColumn("Arc") { Text($0.arcSigned.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("Age") { Text($0.ageFromAbsArc.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("Method") { Text($0.methodKey ?? $0.algorithmName ?? "").font(.caption) }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }
}
