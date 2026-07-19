import SwiftUI

struct OrbitalDialResultPane: View {
    let result: OrbitalDialResult
    @Binding var selectedTab: String
    private var tabs: [(String, String)] { [("dial", "轨道点"), ("pictures", "Dial Pictures")] }
    private var more: [(String, String)] { [("assumptions", "假设"), ("diagnostics", "诊断"), ("json", "JSON")] }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: more,
                currentTabTitle: resultTabTitle(selectedTab, in: tabs, more),
                markdownProvider: { MarkdownExportBuilder.orbitalDial(result) },
                jsonProvider: { TextExportBuilder.orbitalDialJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "orbital_dial"
            )
            Group {
                switch selectedTab {
                case "pictures":
                    Table(result.dialPictures) {
                        TableColumn("Picture") { Text($0.picture ?? "—") }
                        TableColumn("Mid°") { Text($0.midpointLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("Mod") { Text($0.modulus.map(String.init) ?? "—") }
                        TableColumn("Method") { Text($0.methodKey ?? "").font(.caption) }
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
                    Table(result.orbitalPoints) {
                        TableColumn("Body") { Text($0.bodyId ?? "—") }
                        TableColumn("Kind") { Text($0.pointKind ?? "—") }
                        TableColumn("Lon") { Text($0.longitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("Center") { Text($0.coordinateCenter ?? "—") }
                        TableColumn("System") { Text($0.coordinateSystem ?? "—") }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }
}
