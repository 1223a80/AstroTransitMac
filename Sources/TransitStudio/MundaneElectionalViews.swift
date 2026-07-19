import SwiftUI

struct MundaneElectionalResultPane: View {
    let result: MundaneElectionalResult
    @Binding var selectedTab: String
    private var tabs: [(String, String)] { [("ingresses", "Ingress"), ("candidates", "择时事实")] }
    private var more: [(String, String)] { [("assumptions", "假设"), ("diagnostics", "诊断"), ("json", "JSON")] }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: more,
                currentTabTitle: resultTabTitle(selectedTab, in: tabs, more),
                markdownProvider: { MarkdownExportBuilder.mundaneElectional(result) },
                jsonProvider: { TextExportBuilder.mundaneElectionalJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "mundane_electional"
            )
            Group {
                switch selectedTab {
                case "candidates":
                    Table(result.electionalCandidates) {
                        TableColumn("UTC") { Text($0.candidateUtc ?? "—").font(.caption) }
                        TableColumn("Moon°") { Text($0.moonLongitude.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("Sep") { Text($0.sunMoonSeparation.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("ASC") { Text($0.ascLongitude.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("PH") { Text($0.planetaryHoursStatus ?? "—") }
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
                    Table(result.mundaneIngresses) {
                        TableColumn("Ingress") { Text($0.ingress ?? "—") }
                        TableColumn("UTC") { Text($0.exactUtc ?? "—") }
                        TableColumn("Local") { Text($0.exactLocal ?? "—") }
                        TableColumn("Orb") { Text($0.exactOrb.map { String(format: "%.6f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("HS") { Text($0.houseSystem ?? "—") }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }
}
