import SwiftUI

struct TimeLordsExtendedResultPane: View {
    let result: TimeLordsExtendedResult
    @Binding var selectedTab: String
    private var tabs: [(String, String)] { [("concordance", "Concordance"), ("daily", "日小限"), ("zr", "ZR")] }
    private var more: [(String, String)] { [("assumptions", "假设"), ("diagnostics", "诊断"), ("json", "JSON")] }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: more,
                currentTabTitle: resultTabTitle(selectedTab, in: tabs, more),
                markdownProvider: { MarkdownExportBuilder.timeLordsExtended(result) },
                jsonProvider: { TextExportBuilder.timeLordsExtendedJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "time_lords_extended"
            )
            Group {
                switch selectedTab {
                case "daily":
                    VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                        Text("Sign: \(result.dailyProfection?.activatedSign ?? "—")")
                        Text("Lord: \(result.dailyProfection?.lordId ?? result.dailyProfection?.lord ?? "—")")
                        Text("Method: \(result.dailyProfection?.methodKey ?? "—")").foregroundStyle(.secondary)
                        Text(result.dailyProfection?.note ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                case "zr":
                    ScrollView {
                        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                            Text("Fortune λ: \(result.meta.fortuneLongitude.map { String(format: "%.4f", $0) } ?? "—")")
                            Text("Spirit λ: \(result.meta.spiritLongitude.map { String(format: "%.4f", $0) } ?? "—")")
                            if let zr = result.zodiacalReleasing {
                                Text(nestedPreview(zr)).font(.system(.caption, design: .monospaced))
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
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
                    Table(result.revolutionsConcordance) {
                        TableColumn("Body") { Text($0.bodyId) }
                        TableColumn("Name") { Text($0.bodyName ?? "") }
                        TableColumn("Count") { Text($0.count.map(String.init) ?? "—").monospacedDigit() }
                        TableColumn("Techniques") { Text($0.techniques.joined(separator: ", ")) }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }

    private func nestedPreview(_ value: NestedJSON) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(value), let s = String(data: data, encoding: .utf8) else { return "—" }
        return s
    }
}
