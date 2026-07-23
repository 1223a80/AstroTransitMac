import SwiftUI

/// B20 fact-matrix only: no luck scores, recommendation badges, auspicious coloring, or sort-by-吉.
struct MundaneElectionalResultPane: View {
    let result: MundaneElectionalResult
    @Binding var selectedTab: String

    private var tabs: [(String, String)] {
        [("ingresses", "入宫"), ("candidates", "择时事实"), ("assumptions", "假设")]
    }
    private var more: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    private var chrome: ExpansionChromeModel {
        ExpansionChromeFactory.chrome(
            for: .mundaneElectional,
            metaMethod: result.meta.method
        )
    }

    /// Neutral chronological order only — never by luck/score.
    private var candidatesByTime: [ElectionalCandidateRow] {
        result.electionalCandidates.sorted {
            ($0.candidateUtc ?? "") < ($1.candidateUtc ?? "")
        }
    }

    private var ingressesByTime: [MundaneIngressRow] {
        result.mundaneIngresses.sorted {
            ($0.exactUtc ?? "") < ($1.exactUtc ?? "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: more,
                currentTabTitle: resultTabTitle(selectedTab, in: tabs, more),
                markdownProvider: { MarkdownExportBuilder.mundaneElectional(result) },
                jsonProvider: { TextExportBuilder.mundaneElectionalJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "mundane_electional"
            )
            MethodChromeBanner(chrome: chrome)
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case "candidates":
            candidatesView
        case "assumptions":
            AssumptionsListView(
                assumptions: result.calculationAssumptions ?? [],
                footer: "仅输出事实矩阵，不排序吉时。"
            )
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            ingressesView
        }
    }

    private var ingressesView: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            ExpansionOverviewStrip(cards: [
                ("入宫数", "\(result.mundaneIngresses.count)", "按时间"),
                ("候选数", "\(result.electionalCandidates.count)", "事实行"),
            ])
            if ingressesByTime.isEmpty {
                EmptyStateView(
                    title: "无入宫事实",
                    systemImage: "building.columns",
                    description: "当前窗口没有 cardinal solar ingress。"
                )
            } else {
                Table(ingressesByTime) {
                    TableColumn("入宫") { Text($0.ingress ?? "—") }
                    TableColumn("UTC") { Text($0.exactUtc ?? "—").font(.caption) }
                    TableColumn("本地") { Text($0.exactLocal ?? "—").font(.caption) }
                    TableColumn("精确差") {
                        Text($0.exactOrb.map { String(format: "%.6f", $0) } ?? "—").monospacedDigit()
                    }
                    TableColumn("宫制") { Text($0.houseSystem ?? "—") }
                }
            }
        }
    }

    private var candidatesView: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text("按时间排序 · 事实矩阵（无推荐/打分）")
                .font(TS.Font.label)
                .foregroundStyle(TS.SemanticColor.inkFaint)
            if candidatesByTime.isEmpty {
                EmptyStateView(
                    title: "无择时事实",
                    systemImage: "building.columns",
                    description: "当前扫描未产生候选时刻事实行。"
                )
            } else {
                Table(candidatesByTime) {
                    TableColumn("UTC") { Text($0.candidateUtc ?? "—").font(.caption) }
                    TableColumn("月黄经") {
                        Text($0.moonLongitude.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                    }
                    TableColumn("日月距") {
                        Text($0.sunMoonSeparation.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                    }
                    TableColumn("ASC") {
                        Text($0.ascLongitude.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                    }
                    TableColumn("行星时") { Text($0.planetaryHoursStatus ?? "—") }
                }
            }
        }
    }
}
