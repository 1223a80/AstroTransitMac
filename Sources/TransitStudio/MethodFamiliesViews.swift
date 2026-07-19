import SwiftUI

struct MethodFamiliesResultPane: View {
    let result: MethodFamiliesResult
    @Binding var selectedTab: String
    private var tabs: [(String, String)] { [("profiles", "次限角点"), ("solar_arc", "太阳弧")] }
    private var more: [(String, String)] { [("assumptions", "假设"), ("diagnostics", "诊断"), ("json", "JSON")] }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: more,
                currentTabTitle: resultTabTitle(selectedTab, in: tabs, more),
                markdownProvider: { MarkdownExportBuilder.methodFamilies(result) },
                jsonProvider: { TextExportBuilder.methodFamiliesJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "method_families"
            )
            Group {
                switch selectedTab {
                case "solar_arc":
                    ScrollView {
                        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                            ForEach(result.solarArcProfiles) { pack in
                                Text("\(pack.profileId) arc=\(pack.arcDeg.map { String(format: "%.4f", $0) } ?? "—")")
                                    .font(.headline)
                                Table(pack.rows) {
                                    TableColumn("Body") { Text($0.bodyId) }
                                    TableColumn("Natal") { Text($0.natalLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                                    TableColumn("SA") { Text($0.solarArcLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                                }.frame(minHeight: 120)
                            }
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
                    ScrollView {
                        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                            ForEach(result.progressionProfiles) { pack in
                                Text(pack.profileId).font(.headline)
                                Text(pack.description ?? "").font(.caption).foregroundStyle(.secondary)
                                Table(pack.rows.filter { $0.bodyId == "ASC" || $0.bodyId == "MC" || $0.component == "angle" }) {
                                    TableColumn("Body") { Text($0.bodyId) }
                                    TableColumn("Natal") { Text($0.natalLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                                    TableColumn("Prog") { Text($0.progressedLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                                }.frame(minHeight: 80)
                            }
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }
}
