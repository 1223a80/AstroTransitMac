import SwiftUI

struct HellenisticConditionAuditResultPane: View {
    let result: HellenisticConditionAuditResult
    @Binding var selectedTab: String

    private var tabs: [(String, String)] {
        [("conditions", "条件证据"), ("assumptions", "假设")]
    }
    private var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    private var chrome: ExpansionChromeModel {
        ExpansionChromeFactory.chrome(
            for: .hellenisticConditionAudit,
            metaMethod: result.meta.method,
            extras: ExpansionChromeExtras(sourceProfile: result.meta.sourceProfile)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: resultTabTitle(selectedTab, in: tabs, moreTabs),
                markdownProvider: { MarkdownExportBuilder.hellenisticConditionAudit(result) },
                jsonProvider: { TextExportBuilder.hellenisticConditionAuditJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "hellenistic_condition_audit"
            )
            MethodChromeBanner(chrome: chrome)
            selectedResultView.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "conditions":
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                ExpansionOverviewStrip(cards: [
                    ("条件数", "\(result.conditions.count)", "证据行"),
                    ("日盘", result.meta.isDay.map { $0 ? "是" : "否" } ?? "—", "sect"),
                    ("Method", result.meta.method, "meta"),
                ])
                if result.conditions.isEmpty {
                    EmptyStateView(
                        title: "无条件证据",
                        systemImage: "list.bullet.rectangle",
                        description: "当前结果没有条件行。本模式输出证据事实，不做综合打分。"
                    )
                } else {
                    Table(result.conditions) {
                        TableColumn("主体") { Text($0.subject) }
                        TableColumn("条件 ID") { Text($0.conditionID) }
                        TableColumn("几何") { Text($0.geometry ?? "—") }
                        TableColumn("容许度") {
                            Text($0.orb.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit()
                        }
                        TableColumn("method_key") {
                            Text($0.methodKey ?? "—").font(.caption)
                        }
                    }
                }
            }
        case "assumptions":
            AssumptionsListView(
                assumptions: result.calculationAssumptions ?? [],
                footer: "条件证据，不做综合打分。"
            )
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            EmptyStateView(
                title: "希腊状态审计",
                systemImage: "list.bullet.rectangle",
                description: "运行计算后查看条件证据表。"
            )
        }
    }
}
