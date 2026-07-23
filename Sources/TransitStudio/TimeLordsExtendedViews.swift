import SwiftUI

struct TimeLordsExtendedResultPane: View {
    let result: TimeLordsExtendedResult
    @Binding var selectedTab: String

    private var tabs: [(String, String)] {
        [("concordance", "技法汇合"), ("daily", "日小限"), ("zr", "ZR")]
    }
    private var more: [(String, String)] {
        [("assumptions", "假设"), ("diagnostics", "诊断"), ("json", "JSON")]
    }

    private var chrome: ExpansionChromeModel {
        ExpansionChromeFactory.chrome(
            for: .timeLordsExtended,
            metaMethod: result.meta.method,
            extras: ExpansionChromeExtras(
                dailyMethodKey: result.dailyProfection?.methodKey,
                dailyNote: result.dailyProfection?.note
            )
        )
    }

    private var zr: ZodiacalReleasingPayload? { result.zrPayload }

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
            MethodChromeBanner(chrome: chrome)
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case "daily":
            dailyView
        case "zr":
            zrView
        case "assumptions":
            AssumptionsListView(assumptions: result.calculationAssumptions ?? [])
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            concordanceView
        }
    }

    private var concordanceView: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            ExpansionOverviewStrip(cards: [
                ("汇合行", "\(result.revolutionsConcordance.count)", "techniques"),
                ("年龄", result.meta.age.map(String.init) ?? "—", "岁"),
                ("Fortune λ", result.meta.fortuneLongitude.map { String(format: "%.2f", $0) } ?? "—", "°"),
                ("Spirit λ", result.meta.spiritLongitude.map { String(format: "%.2f", $0) } ?? "—", "°"),
            ])
            if result.revolutionsConcordance.isEmpty {
                EmptyStateView(title: "无技法汇合", systemImage: "hourglass", description: "当前结果没有 concordance 行。")
            } else {
                Table(result.revolutionsConcordance) {
                    TableColumn("天体") { Text($0.bodyId) }
                    TableColumn("名称") { Text($0.bodyName ?? "—") }
                    TableColumn("次数") { Text($0.count.map(String.init) ?? "—").monospacedDigit() }
                    TableColumn("技法") { Text($0.techniques.joined(separator: "、")) }
                }
            }
        }
    }

    private var dailyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                ExpansionOverviewStrip(cards: [
                    ("激活星座", result.dailyProfection?.activatedSign ?? "—", "日小限"),
                    ("主星", result.dailyProfection?.lordId ?? result.dailyProfection?.lord ?? "—", "lord"),
                    ("method_key", result.dailyProfection?.methodKey ?? "—", "代理"),
                ])
                if let note = result.dailyProfection?.note, !note.isEmpty {
                    Text(note)
                        .font(TS.Font.body)
                        .foregroundStyle(TS.SemanticColor.inkSoft)
                }
                Text("日小限为代理输出，badge 见上方 chrome。")
                    .font(TS.Font.label)
                    .foregroundStyle(TS.SemanticColor.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.cardInner)
        }
    }

    @ViewBuilder
    private var zrView: some View {
        if let zr {
            ScrollView {
                VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                    ExpansionOverviewStrip(cards: [
                        ("Fortune λ", (zr.fortuneLongitude ?? result.meta.fortuneLongitude).map { String(format: "%.2f", $0) } ?? "—", "°"),
                        ("Spirit λ", (zr.spiritLongitude ?? result.meta.spiritLongitude).map { String(format: "%.2f", $0) } ?? "—", "°"),
                        ("max_level", zr.maxLevel.map(String.init) ?? "—", "层"),
                    ])
                    if let fortune = zr.fortune {
                        zrLotSection(title: "Fortune", block: fortune)
                    }
                    if let spirit = zr.spirit {
                        zrLotSection(title: "Spirit", block: spirit)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(TS.Padding.cardInner)
            }
        } else if result.zodiacalReleasing != nil {
            EmptyStateView(
                title: "ZR 结构无法解析",
                systemImage: "hourglass",
                description: "zodiacal_releasing 存在但无法解码为 typed 结构。完整包见 JSON 标签。"
            )
        } else {
            EmptyStateView(title: "无 ZR 数据", systemImage: "hourglass", description: "当前结果未包含 zodiacal_releasing。")
        }
    }

    @ViewBuilder
    private func zrLotSection(title: String, block: ZRLotBlock) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text(title)
                .font(TS.Font.sectionTitle)
            HStack(spacing: TS.Spacing.lg) {
                labeled("当前层", block.currentActiveLevel ?? "—")
                labeled("主星", block.currentLevelRuler ?? "—")
                labeled("星座", block.currentLevelSign ?? "—")
                if block.loosingOfBond == true {
                    Text("LoB")
                        .font(TS.Font.label)
                        .foregroundStyle(TS.SemanticColor.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(TS.SemanticColor.warning.opacity(TS.Opacity.subtle), in: Capsule())
                }
            }
            if let detail = block.loosingOfBondDetail, block.loosingOfBond == true {
                Text(detail).font(TS.Font.label).foregroundStyle(TS.SemanticColor.inkFaint)
            }
            periodTable("L1", block.l1Periods ?? [])
            periodTable("L2", block.l2Periods ?? [])
            periodTable("L3", block.l3Periods ?? [])
            periodTable("L4", block.l4Periods ?? [])
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(TS.Font.label).foregroundStyle(.secondary)
            Text(value).font(TS.Font.body)
        }
    }

    @ViewBuilder
    private func periodTable(_ level: String, _ rows: [ZRPeriodRow]) -> some View {
        if !rows.isEmpty {
            Text("\(level) 周期")
                .font(TS.Font.label)
                .foregroundStyle(.secondary)
            Table(rows) {
                TableColumn("层") { Text($0.level ?? level) }
                TableColumn("星座") { Text($0.sign ?? "—") }
                TableColumn("主星") { Text($0.ruler ?? "—") }
                TableColumn("年数") {
                    Text($0.years.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit()
                }
                TableColumn("起") { Text($0.startLocal ?? "—").font(.caption) }
                TableColumn("止") { Text($0.endLocal ?? "—").font(.caption) }
                TableColumn("当前") { Text($0.isActive == true ? "是" : "") }
            }
            .frame(minHeight: min(CGFloat(rows.count) * 28 + 36, 220))
        }
    }
}
