import SwiftUI

struct PrimaryDirectionsAuditResultPane: View {
    let result: PrimaryDirectionsAuditResult
    @Binding var selectedTab: String

    private var tabs: [(String, String)] {
        [("audit", "主限表"), ("algorithm", "算法说明"), ("assumptions", "假设")]
    }
    private var more: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    private var algo: PDAlgorithmDescription? { result.algorithmDescriptionPayload }

    private var chrome: ExpansionChromeModel {
        ExpansionChromeFactory.chrome(
            for: .primaryDirectionsAudit,
            metaMethod: result.meta.method,
            extras: ExpansionChromeExtras(
                algorithmName: algo?.name ?? result.meta.algorithmName,
                algorithmKey: algo?.key,
                externalCrosscheckStatus: algo?.externalCrosscheckStatus,
                externalCrosscheckNote: algo?.externalCrosscheckNote,
                knownLimitsFirst: algo?.knownLimits?.first
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
                markdownProvider: { MarkdownExportBuilder.primaryDirectionsAudit(result) },
                jsonProvider: { TextExportBuilder.primaryDirectionsAuditJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "primary_directions_audit"
            )
            MethodChromeBanner(chrome: chrome)
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case "algorithm":
            algorithmView
        case "assumptions":
            AssumptionsListView(
                assumptions: result.calculationAssumptions ?? [],
                footer: algo?.name.map { "算法：\($0)" }
            )
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            auditTable
        }
    }

    private var auditTable: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            ExpansionOverviewStrip(cards: [
                ("主限数", "\(result.directions.count)", "行"),
                ("算法", algo?.name ?? result.meta.algorithmName ?? "—", "name"),
                ("Key", algo?.key ?? "—", "algorithm key"),
            ])
            if result.directions.isEmpty {
                EmptyStateView(title: "无主限行", systemImage: "arrow.up.right.circle", description: "当前审计未产出方向行。")
            } else {
                Table(result.directions) {
                    TableColumn("促动星") { Text($0.promissor ?? $0.promissorId ?? "—") }
                    TableColumn("指示星") { Text($0.significator ?? $0.significatorId ?? "—") }
                    TableColumn("方向") { Text($0.directionType ?? "—") }
                    TableColumn("弧°") {
                        Text($0.arcSigned.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit()
                    }
                    TableColumn("年龄") {
                        Text($0.ageFromAbsArc.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                    }
                    TableColumn("method_key") {
                        Text($0.methodKey ?? $0.algorithmName ?? "—").font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var algorithmView: some View {
        if let algo {
            ScrollView {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    ExpansionOverviewStrip(cards: [
                        ("名称", algo.name ?? "—", "algorithm"),
                        ("Key", algo.key ?? "—", "key"),
                        ("交叉核对", algo.externalCrosscheckStatus ?? "—", "status"),
                    ])
                    if let note = algo.externalCrosscheckNote, !note.isEmpty {
                        Text(note)
                            .font(TS.Font.body)
                            .foregroundStyle(TS.SemanticColor.inkSoft)
                            .textSelection(.enabled)
                    }
                    Text("已知限制")
                        .font(TS.Font.sectionTitle)
                    if let limits = algo.knownLimits, !limits.isEmpty {
                        ForEach(Array(limits.enumerated()), id: \.offset) { _, item in
                            Text("• \(item)")
                                .font(TS.Font.body)
                                .foregroundStyle(TS.SemanticColor.inkSoft)
                                .textSelection(.enabled)
                        }
                    } else {
                        Text("无 known_limits 条目。")
                            .foregroundStyle(TS.SemanticColor.inkFaint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(TS.Padding.cardInner)
            }
        } else if result.algorithmDescription != nil {
            EmptyStateView(
                title: "算法说明无法解析",
                systemImage: "arrow.up.right.circle",
                description: "algorithm_description 存在但无法解码。完整结构见 JSON 标签。"
            )
        } else {
            EmptyStateView(title: "无算法说明", systemImage: "arrow.up.right.circle", description: "结果未包含 algorithm_description。")
        }
    }
}
