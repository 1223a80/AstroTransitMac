import SwiftUI

struct DraconicHeliocentricResultPane: View {
    let result: DraconicHeliocentricResult
    @Binding var selectedTab: String
    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: [("draconic", "Draconic"), ("heliocentric", "日心"), ("compare", "对照"), ("assumptions", "假设")],
                moreTabs: [("diagnostics", "诊断"), ("json", "JSON")],
                currentTabTitle: resultTabTitle(selectedTab, in: [("draconic", "Draconic"), ("heliocentric", "日心"), ("compare", "对照"), ("assumptions", "假设")], [("diagnostics", "诊断"), ("json", "JSON")]),
                markdownProvider: { MarkdownExportBuilder.draconicHeliocentric(result) },
                jsonProvider: { TextExportBuilder.draconicHeliocentricJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "draconic_heliocentric"
            )
            Group {
                switch selectedTab {
                case "draconic":
                    Table(result.draconic?.planets ?? []) {
                        TableColumn("Body") { Text($0.name ?? $0.bodyID) }
                        TableColumn("Lon") { Text(String(format: "%.4f", $0.longitude)).monospacedDigit() }
                        TableColumn("System") { Text($0.coordinateSystem ?? "") }
                    }
                case "heliocentric":
                    Table(result.heliocentric?.planets ?? []) {
                        TableColumn("Body") { Text($0.name ?? $0.bodyID) }
                        TableColumn("Lon") { Text(String(format: "%.4f", $0.longitude)).monospacedDigit() }
                        TableColumn("Center") { Text($0.coordinateCenter ?? "") }
                    }
                case "compare":
                    Table(result.geoHelioComparison ?? []) {
                        TableColumn("Body") { Text($0.name ?? $0.bodyID) }
                        TableColumn("Δ°") { Text($0.deltaDeg.map { String(format: "%.4f", $0) } ?? "—").monospacedDigit() }
                    }
                case "assumptions":
                    ScrollView { VStack(alignment: .leading) { ForEach(result.calculationAssumptions ?? [], id: \.self) { Text("• \($0)").foregroundStyle(.secondary) } }.frame(maxWidth: .infinity, alignment: .leading) }
                case "diagnostics": ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
                case "json": RawJSONView(value: result)
                default: EmptyStateView(title: "Draconic/日心", systemImage: "arrow.triangle.swap", description: "")
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }
}
