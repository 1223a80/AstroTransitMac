import SwiftUI

struct DistributionsPdResultPane: View {
    let result: DistributionsPdResult
    @Binding var selectedTab: String
    private var tabs: [(String, String)] { [("distributions", "沿界"), ("pd_profiles", "PD Profiles")] }
    private var more: [(String, String)] { [("assumptions", "假设"), ("diagnostics", "诊断"), ("json", "JSON")] }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: more,
                currentTabTitle: resultTabTitle(selectedTab, in: tabs, more),
                markdownProvider: { MarkdownExportBuilder.distributionsPd(result) },
                jsonProvider: { TextExportBuilder.distributionsPdJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "distributions_pd"
            )
            Group {
                switch selectedTab {
                case "pd_profiles":
                    Table(result.primaryDirectionsByProfile) {
                        TableColumn("Profile") { Text($0.methodProfile ?? $0.methodKey ?? "—") }
                        TableColumn("ID") { Text($0.directionId).font(.caption) }
                        TableColumn("Dir") { Text($0.directionType ?? "—") }
                        TableColumn("Arc") { Text($0.arcSigned.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("Age") { Text($0.ageFromAbsArc.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("Key") { Text($0.key ?? "—") }
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
                    Table(result.distributions) {
                        TableColumn("Significator") { Text($0.significator ?? "—") }
                        TableColumn("Lon") { Text($0.significatorLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("Bounds") { Text($0.boundsSystem ?? "—") }
                        TableColumn("Method") { Text($0.methodKey ?? "").font(.caption) }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }
}
