import SwiftUI

struct DistributionsPdResultPane: View {
    let result: DistributionsPdResult
    @Binding var selectedTab: String

    private var tabs: [(String, String)] {
        [("distributions", "沿界"), ("pd_profiles", "主限多配置"), ("assumptions", "假设")]
    }
    private var more: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    private var chrome: ExpansionChromeModel {
        ExpansionChromeFactory.chrome(
            for: .distributionsPd,
            metaMethod: result.meta.method,
            extras: ExpansionChromeExtras(baselineAlgorithm: result.meta.baselineAlgorithm)
        )
    }

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
            MethodChromeBanner(chrome: chrome)
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case "pd_profiles":
            pdProfilesView
        case "assumptions":
            AssumptionsListView(assumptions: result.calculationAssumptions ?? [])
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            distributionsView
        }
    }

    private var distributionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                ExpansionOverviewStrip(cards: [
                    ("沿界包", "\(result.distributions.count)", "significators"),
                    ("基线算法", result.meta.baselineAlgorithm ?? "—", "baseline"),
                ])
                if result.distributions.isEmpty {
                    EmptyStateView(title: "无沿界数据", systemImage: "rectangle.split.3x1", description: "当前结果没有 distribution packets。")
                } else {
                    ForEach(result.distributions) { row in
                        distributionCard(row)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.cardInner)
        }
    }

    @ViewBuilder
    private func distributionCard(_ row: DistributionPacketRow) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack {
                Text(row.significator ?? "—")
                    .font(TS.Font.sectionTitle)
                Spacer()
                Text(row.methodKey ?? "—")
                    .font(TS.Font.label)
                    .foregroundStyle(TS.SemanticColor.goldDeep)
            }
            Text("界系统：\(row.boundsSystem ?? "—") · λ \(row.significatorLongitude.map { String(format: "%.2f", $0) } ?? "—")°")
                .font(TS.Font.label)
                .foregroundStyle(.secondary)

            if let packet = row.circumambulationPacket {
                Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.sm) {
                    GridRow {
                        Text("当前界主").foregroundStyle(.secondary)
                        Text(packet.currentRuler ?? packet.currentRulerId ?? "—")
                    }
                    GridRow {
                        Text("当前界").foregroundStyle(.secondary)
                        Text(packet.currentBoundInfo ?? "—")
                    }
                    GridRow {
                        Text("界范围").foregroundStyle(.secondary)
                        Text("\(packet.boundSign ?? "—") \(packet.boundStartDegree.map { String(format: "%.2f", $0) } ?? "—")°–\(packet.boundEndDegree.map { String(format: "%.2f", $0) } ?? "—")°")
                    }
                    GridRow {
                        Text("日期").foregroundStyle(.secondary)
                        Text("\(packet.boundStartDate ?? "—") → \(packet.boundEndDate ?? "—")")
                            .monospacedDigit()
                    }
                }
                if let boundaries = packet.boundaries, !boundaries.isEmpty {
                    Text("沿界序列")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                    Table(boundaries) {
                        TableColumn("星座") { Text($0.sign ?? "—") }
                        TableColumn("起°") {
                            Text($0.startDegree.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                        }
                        TableColumn("止°") {
                            Text($0.endDegree.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                        }
                        TableColumn("主星") { Text($0.ruler ?? "—") }
                        TableColumn("年龄") {
                            Text($0.ageAtBoundary.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                        }
                        TableColumn("日期") { Text($0.estimatedDate ?? "—").font(.caption) }
                        TableColumn("当前") { Text($0.isCurrent == true ? "是" : "") }
                    }
                    .frame(minHeight: min(CGFloat(boundaries.count) * 28 + 36, 240))
                }
            } else if row.packet != nil {
                Text("packet 存在但无法 typed 解码 — 完整结构见 JSON。")
                    .font(TS.Font.label)
                    .foregroundStyle(TS.SemanticColor.warning)
            }
        }
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.card))
    }

    private var pdProfilesView: some View {
        Group {
            if result.primaryDirectionsByProfile.isEmpty {
                EmptyStateView(title: "无主限多配置", systemImage: "rectangle.split.3x1", description: "primary_directions_by_profile 为空。")
            } else {
                Table(result.primaryDirectionsByProfile) {
                    TableColumn("配置") { Text($0.methodProfile ?? $0.methodKey ?? "—") }
                    TableColumn("促动星") { Text($0.promissor ?? $0.promissorId ?? "—") }
                    TableColumn("指示星") { Text($0.significator ?? $0.significatorId ?? "—") }
                    TableColumn("弧°") {
                        Text($0.arcSigned.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit()
                    }
                    TableColumn("年龄") {
                        Text($0.ageFromAbsArc.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                    }
                }
            }
        }
    }
}
