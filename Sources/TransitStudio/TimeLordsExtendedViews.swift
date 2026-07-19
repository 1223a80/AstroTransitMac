import SwiftUI

struct TimeLordsExtendedResultPane: View {
    let result: TimeLordsExtendedResult
    @Binding var selectedTab: String
    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: [("summary", "摘要"), ("assumptions", "假设")],
                moreTabs: [("diagnostics", "诊断"), ("json", "JSON")],
                currentTabTitle: resultTabTitle(selectedTab, in: [("summary", "摘要"), ("assumptions", "假设")], [("diagnostics", "诊断"), ("json", "JSON")]),
                markdownProvider: { MarkdownExportBuilder.timeLordsExtended(result) },
                jsonProvider: { TextExportBuilder.timeLordsExtendedJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "time_lords_extended"
            )
            Group {
                switch selectedTab {
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
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        Text("Method: \(result.meta.method)")
                        Text("Assumptions: \(result.calculationAssumptions?.count ?? 0)")
                        Text("Warnings: \(result.warnings.count)")
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }
}
