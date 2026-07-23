import SwiftUI

struct PrenatalParansResultPane: View {
    let result: PrenatalParansResult
    @Binding var selectedTab: String

    private var tabs: [(String, String)] {
        [("packet", "朔望包"), ("parans", "Parans 代理"), ("assumptions", "假设")]
    }
    private var more: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    private var packet: PrenatalPacketSummary? { result.prenatalPacketSummary }

    private var chrome: ExpansionChromeModel {
        ExpansionChromeFactory.chrome(
            for: .prenatalParans,
            metaMethod: result.meta.method,
            extras: ExpansionChromeExtras(
                hasProxyMethodKey: result.fixedStarParans.contains { ($0.methodKey ?? "").contains("proxy") || ($0.methodKey ?? "").contains("ra") },
                paranCount: result.meta.paranCount ?? result.fixedStarParans.count
            )
        )
    }

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
            MethodChromeBanner(chrome: chrome)
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case "parans":
            paransView
        case "assumptions":
            AssumptionsListView(assumptions: result.calculationAssumptions ?? [])
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            packetView
        }
    }

    @ViewBuilder
    private var packetView: some View {
        if let syz = packet?.prenatalSyzygy {
            ScrollView {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    ExpansionOverviewStrip(cards: [
                        ("类型", syz.syzygyType ?? "—", "syzygy"),
                        ("星座", syz.sign ?? "—", syz.degree.map { String(format: "%.2f°", $0) } ?? ""),
                        ("度数来源", syz.syzygyDegreeUsed ?? "—", "必须展示"),
                        ("主星", syz.ruler ?? "—", syz.methodVariant ?? ""),
                    ])
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.sm) {
                        GridRow {
                            Text("精确 UTC").foregroundStyle(.secondary)
                            Text(syz.exactUtc ?? "—").monospacedDigit()
                        }
                        GridRow {
                            Text("精确 JD").foregroundStyle(.secondary)
                            Text(syz.exactJd.map { String(format: "%.6f", $0) } ?? "—").monospacedDigit()
                        }
                        GridRow {
                            Text("黄经").foregroundStyle(.secondary)
                            Text(syz.longitude.map { String(format: "%.4f°", $0) } ?? "—").monospacedDigit()
                        }
                        GridRow {
                            Text("syzygy_degree_used").foregroundStyle(.secondary)
                            Text(syz.syzygyDegreeUsed ?? "—")
                                .fontWeight(.semibold)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(TS.Padding.cardInner)
            }
        } else if result.prenatalPacket != nil {
            EmptyStateView(
                title: "朔望包无法解析",
                systemImage: "sparkles",
                description: "prenatal_packet 存在但无法解码。完整结构见 JSON 标签。"
            )
        } else {
            EmptyStateView(title: "无朔望包", systemImage: "sparkles", description: "运行计算后查看产前朔望结构化结果。")
        }
    }

    private var paransView: some View {
        Group {
            if result.fixedStarParans.isEmpty {
                EmptyStateView(
                    title: "无 Parans 代理行",
                    systemImage: "sparkles",
                    description: "RA 共中天代理未命中恒星。"
                )
            } else {
                Table(result.fixedStarParans) {
                    TableColumn("行星") { Text($0.planetName ?? $0.planetId ?? "—") }
                    TableColumn("恒星") { Text($0.starName ?? "—") }
                    TableColumn("ΔRA°") {
                        Text($0.raDeltaDeg.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit()
                    }
                    TableColumn("类别") { Text($0.paranClass ?? "—") }
                    TableColumn("method_key") { Text($0.methodKey ?? "—").font(.caption) }
                }
            }
        }
    }
}
