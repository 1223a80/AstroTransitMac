import SwiftUI

struct PrenatalParansResultPane: View {
    let result: PrenatalParansResult
    @Binding var selectedTab: String

    private var tabs: [(String, String)] {
        [("packet", "朔望包"), ("parans", "Parans 事件"), ("legacy", "兼容代理"), ("assumptions", "假设")]
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
                hasProxyMethodKey: false,
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
        case "legacy":
            legacyParansView
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
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                Text("\(result.methodTrace?.provider ?? "Swiss Ephemeris") · \(result.methodTrace?.function ?? "swe.rise_trans")")
                    .font(.subheadline.weight(.semibold))
                Text(result.methodTrace?.pairingRule ?? "按两端本地事件绝对时间差配对")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let start = result.methodTrace?.localDayStart, let end = result.methodTrace?.localDayEnd {
                    Text("本地民用日：\(start) → \(end)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if result.polarDegradation?.active == true {
                    Label(
                        "极区降级：省略不可用升落事件，保留可用中天事件（\(result.polarDegradation?.affectedObjectCount ?? 0) 个对象）",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
            if result.fixedStarParans.isEmpty {
                EmptyStateView(
                    title: "无真实 Paran 事件配对",
                    systemImage: "sparkles",
                    description: "当前秒级容许度内没有行星与固定星的本地升落/中天事件配对。"
                )
            } else {
                Table(result.fixedStarParans) {
                    TableColumn("行星") { Text($0.planetName ?? $0.planetId ?? "—") }
                    TableColumn("行星事件") { Text(eventLabel($0.planetEventType)) }
                    TableColumn("行星本地时间") { Text($0.planetEventLocal ?? "—").monospacedDigit() }
                    TableColumn("恒星") { Text($0.starName ?? "—") }
                    TableColumn("恒星事件") { Text(eventLabel($0.starEventType)) }
                    TableColumn("恒星本地时间") { Text($0.starEventLocal ?? "—").monospacedDigit() }
                    TableColumn("Δt 秒") {
                        Text($0.eventDeltaSeconds.map { String(format: "%.3f", $0) } ?? "—").monospacedDigit()
                    }
                    TableColumn("method_key") { Text($0.methodKey ?? "—").font(.caption) }
                }
            }
        }
    }

    private var legacyParansView: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text("以下仅为 schema v1 的 ΔRA 共中天代理迁移输出，不等同于真实 Paran 事件。")
                .font(.caption)
                .foregroundStyle(.secondary)
            if result.legacyFixedStarParans.isEmpty {
                EmptyStateView(
                    title: "未输出兼容代理",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: "请求已关闭 legacy 代理，或当前 RA 容许度内无命中。"
                )
            } else {
                Table(result.legacyFixedStarParans) {
                    TableColumn("行星") { Text($0.planetName ?? $0.planetId ?? "—") }
                    TableColumn("恒星") { Text($0.starName ?? "—") }
                    TableColumn("行星 RA") {
                        Text($0.planetRa.map { String(format: "%.4f°", $0) } ?? "—").monospacedDigit()
                    }
                    TableColumn("恒星 RA") {
                        Text($0.starRa.map { String(format: "%.4f°", $0) } ?? "—").monospacedDigit()
                    }
                    TableColumn("ΔRA") {
                        Text($0.raDeltaDeg.map { String(format: "%.4f°", $0) } ?? "—").monospacedDigit()
                    }
                    TableColumn("legacy method") {
                        Text($0.methodKeyLegacy ?? $0.methodKey ?? "—").font(.caption)
                    }
                }
            }
        }
    }

    private func eventLabel(_ value: String?) -> String {
        switch value {
        case "rising": return "升"
        case "culminating": return "上中天"
        case "setting": return "落"
        case "lower_culminating": return "下中天"
        default: return value ?? "—"
        }
    }
}
