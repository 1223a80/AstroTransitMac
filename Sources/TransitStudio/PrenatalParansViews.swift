import SwiftUI

struct PrenatalParansResultPane: View {
    let result: PrenatalParansResult
    @Binding var selectedTab: String
    private var tabs: [(String, String)] { [("packet", "朔望包"), ("parans", "Parans proxy")] }
    private var more: [(String, String)] { [("assumptions", "假设"), ("diagnostics", "诊断"), ("json", "JSON")] }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: more,
                currentTabTitle: resultTabTitle(selectedTab, in: tabs, more),
                markdownProvider: { MarkdownExportBuilder.prenatalParans(result) },
                jsonProvider: { TextExportBuilder.prenatalParansJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "prenatal_parans"
            )
            Group {
                switch selectedTab {
                case "parans":
                    Table(result.fixedStarParans) {
                        TableColumn("Planet") { Text($0.planetName ?? $0.planetId ?? "—") }
                        TableColumn("Star") { Text($0.starName ?? "—") }
                        TableColumn("ΔRA") { Text($0.raDeltaDeg.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                        TableColumn("Class") { Text($0.paranClass ?? "—") }
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
                    ScrollView {
                        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                            Text("Paran count: \(result.meta.paranCount ?? result.fixedStarParans.count)")
                            if let packet = result.prenatalPacket {
                                Text(nestedPreview(packet)).font(.system(.caption, design: .monospaced))
                            } else {
                                Text("prenatal_packet missing").foregroundStyle(.secondary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
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
