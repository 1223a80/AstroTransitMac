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
            MethodChromeBanner(chrome: ExpansionChromeFactory.chrome(
                for: .methodFamilies,
                metaMethod: result.meta.method,
                extras: ExpansionChromeExtras(profileIds: result.progressionProfiles.map(\.profileId) + result.solarArcProfiles.map(\.profileId))
            ))
            Group {
                switch selectedTab {
                case "solar_arc":
                    if result.solarArcProfiles.isEmpty {
                        EmptyStateView(title: "无太阳弧配置", systemImage: "square.stack.3d.up", description: "solar_arc_profiles 为空。")
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                                ForEach(result.solarArcProfiles) { pack in
                                    Text("\(pack.profileId) · 弧 \(pack.arcDeg.map { String(format: "%.4f", $0) } ?? "—")°")
                                        .font(TS.Font.sectionTitle)
                                    if pack.rows.isEmpty {
                                        Text("无行").foregroundStyle(.secondary)
                                    } else {
                                        Table(pack.rows) {
                                            TableColumn("天体") { Text($0.bodyId) }
                                            TableColumn("本命°") { Text($0.natalLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                                            TableColumn("太阳弧°") { Text($0.solarArcLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                                        }.frame(minHeight: 120)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(TS.Padding.cardInner)
                        }
                    }
                case "assumptions":
                    AssumptionsListView(assumptions: result.calculationAssumptions ?? [])
                case "diagnostics":
                    ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
                case "json":
                    RawJSONView(value: result)
                default:
                    // Default tab: progression profiles with nested Overview
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        ExpansionOverviewStrip(cards: [
                            ("次限配置", "\(result.progressionProfiles.count)", "profiles"),
                            ("太阳弧配置", "\(result.solarArcProfiles.count)", "solar arc"),
                        ])
                        if result.progressionProfiles.isEmpty {
                            EmptyStateView(title: "无次限角点配置", systemImage: "square.stack.3d.up", description: "progression_profiles 为空。")
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                                    ForEach(result.progressionProfiles) { pack in
                                        Text(pack.profileId).font(TS.Font.sectionTitle)
                                        if let desc = pack.description, !desc.isEmpty {
                                            Text(desc).font(TS.Font.label).foregroundStyle(.secondary)
                                        }
                                        let angleRows = pack.rows.filter { $0.bodyId == "ASC" || $0.bodyId == "MC" || $0.component == "angle" }
                                        if angleRows.isEmpty {
                                            Text("无角点行").foregroundStyle(.secondary)
                                        } else {
                                            Table(angleRows) {
                                                TableColumn("天体") { Text($0.bodyId) }
                                                TableColumn("本命°") { Text($0.natalLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                                                TableColumn("次限°") { Text($0.progressedLongitude.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit() }
                                            }.frame(minHeight: 80)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(TS.Padding.cardInner)
                            }
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(TS.Padding.resultContent)
    }
}
