import Foundation
import SwiftUI

struct ModernDiagnosticsView: View {
    let warnings: [String]
    let sectionErrors: [String: String]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                WarningList(warnings: warnings)
                if let sectionErrors, !sectionErrors.isEmpty {
                    SectionErrorList(errors: sectionErrors)
                } else {
                    Label("没有子模块错误", systemImage: "checkmark.circle")
                        .font(TS.Font.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ModernStructureView: View {
    let profile: ChartProfile?
    let patterns: [PatternResult]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                Text("结构统计").font(TS.Font.sectionTitle)
                if let profile {
                    profileBlock("统计点集", profile.pointIDs.joined(separator: ", "))
                    profileBlock("元素", profile.elements.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: " · "))
                    profileBlock("模式", profile.modalities.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: " · "))
                    profileBlock("阴阳", profile.polarities.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: " · "))
                    profileBlock("半球", profile.hemispheres.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: " · "))
                    profileBlock("象限", profile.quadrants.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: " · "))
                    if !profile.omittedSections.isEmpty {
                        profileBlock("未计算", profile.omittedSections.joined(separator: ", "))
                    }
                } else {
                    Text("暂无结构统计。请使用现代本命排盘并启用结构分析。").foregroundStyle(.secondary)
                }
                Text("相位图形").font(TS.Font.sectionTitle)
                PatternListView(patterns: patterns)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func profileBlock(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xs) {
            Text(title).font(TS.Font.label).foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value).font(TS.Font.body)
        }
    }
}

struct ModernDeclinationView: View {
    let positions: [PositionRow]
    let aspects: [DeclinationAspect]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                Text("赤纬位置（含 OOB）").font(TS.Font.sectionTitle)
                Table(positions) {
                    TableColumn("天体", value: \.name)
                    TableColumn("赤纬") { row in Text(row.declination.map { String(format: "%.4f°", $0) } ?? "—") }
                    TableColumn("OOB") { row in Text(row.outOfBounds == true ? "是" : "") }
                }
                .tsTableStyle()
                Text("赤纬相位").font(TS.Font.sectionTitle)
                if aspects.isEmpty {
                    Text("没有平行或反平行命中").foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                        ForEach(Array(aspects.enumerated()), id: \.offset) { item in
                            HStack(spacing: TS.Spacing.md) {
                                Text(item.element.body1)
                                Text(item.element.type == "contraparallel" ? "反平行" : "平行")
                                    .foregroundStyle(.secondary)
                                Text(item.element.body2)
                                Text(String(format: "%.4f°", item.element.diff))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ModernFixedStarsView: View {
    let conjunctions: [FixedStarConjunction]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("固定星合相").font(TS.Font.sectionTitle)
            if conjunctions.isEmpty {
                EmptyStateView(title: "无固定星合相", systemImage: "star")
            } else {
                VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                    ForEach(Array(conjunctions.enumerated()), id: \.offset) { item in
                        HStack(spacing: TS.Spacing.md) {
                            Text(item.element.planet)
                            Text(item.element.star)
                            Text(String(format: "%.2f°", item.element.orb)).monospacedDigit()
                            Text(item.element.starNature).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Synastry Views

struct SynastryResultPane: View {
    let result: SynastryResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { markdown },
                jsonProvider: { json },
                csvProvider: { csv },
                basename: "synastry"
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [
            ("cross_aspects", "跨盘相位"), ("a_in_b_houses", "A入B宫"), ("b_in_a_houses", "B入A宫"),
            ("person_a_planets", "A本命"), ("person_b_planets", "B本命"),
        ]
    }

    var moreTabs: [(String, String)] {
        [("declination", "赤纬"), ("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        resultTabTitle(selectedTab, in: tabs, moreTabs)
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "cross_aspects":
            AspectTableView(
                title: "跨盘相位",
                leftColumnTitle: "A天体",
                rightColumnTitle: "B天体",
                aspects: result.crossAspects
            )
        case "a_in_b_houses":
            HousePlacementView(title: "A 的行星落入 B 的宫位", placements: result.aInBHouses)
        case "b_in_a_houses":
            HousePlacementView(title: "B 的行星落入 A 的宫位", placements: result.bInAHouses)
        case "person_a_planets":
            PositionTableView(title: "A 本命位置", positions: result.personAPlanets)
        case "person_b_planets":
            PositionTableView(title: "B 本命位置", positions: result.personBPlanets)
        case "declination":
            ModernDeclinationView(positions: result.personAPlanets, aspects: result.crossDeclinationAspects ?? [])
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            AspectTableView(title: "跨盘相位", leftColumnTitle: "A天体", rightColumnTitle: "B天体", aspects: result.crossAspects)
        }
    }

    var markdown: String { MarkdownModernExportBuilder.synastry(result) }
    var json: String { TextExportBuilder.json(result) }
    var csv: String { TextExportBuilder.csv(result) }
}

struct HousePlacementView: View {
    let title: String
    let placements: [HousePlacement]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text(title).font(TS.Font.sectionTitle)
            if placements.isEmpty {
                EmptyStateView(title: "无数据", systemImage: "house")
            } else {
                Table(placements) {
                    TableColumn("天体", value: \.bodyName)
                    TableColumn("宫位") { Text("\($0.house)").monospacedDigit() }
                }
                .tsTableStyle()
            }
        }
    }
}

// MARK: - Composite / Davison Shared View

struct CompositeDavisonResultPane<T: ChartResultFields>: View {
    let title: String
    let result: T
    @Binding var selectedTab: String
    let onOpenTiming: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { markdown },
                jsonProvider: { json },
                csvProvider: { csv },
                basename: title.lowercased()
            )
            if let onOpenTiming {
                HStack(spacing: TS.Spacing.md) {
                    Label("Transit → \(title) 动态", systemImage: "calendar.badge.clock")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("动态") { onOpenTiming() }
                        .buttonStyle(.borderedProminent)
                        .tint(TS.SemanticColor.gold)
                        .controlSize(.small)
                }
                .padding(.vertical, TS.Spacing.xs)
            }
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [
            ("planets", "行星"), ("angles", "角点"), ("houses", "宫位"), ("aspects", "相位"),
            ("patterns", "图形"),
        ]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        resultTabTitle(selectedTab, in: tabs, moreTabs)
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "planets":
            PositionTableView(title: "\(title) 行星位置", positions: result.planets)
        case "angles":
            ClassicalPointsView(angles: result.angles, lots: [], experimentalLots: nil)
        case "houses":
            ClassicalHouseTableView(houses: result.houses)
        case "aspects":
            AspectTableView(aspects: result.aspects)
        case "patterns":
            PatternListView(patterns: result.patterns ?? [])
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            PositionTableView(title: "\(title) 行星位置", positions: result.planets)
        }
    }

    var markdown: String { MarkdownModernExportBuilder.compositeOrDavison(title: title, result: result) }
    var json: String { TextExportBuilder.json(result) }
    var csv: String { TextExportBuilder.csv(result) }
}

// MARK: - Progression Views

struct ProgressionResultPane: View {
    let result: ProgressionResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { markdown },
                jsonProvider: { json },
                csvProvider: { csv },
                basename: "progressions"
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [
            ("progressed_planets", "推进盘"), ("natal_planets", "本命盘"), ("prog_to_natal", "推进→本命相位"),
            ("prog_to_prog", "推进盘相位"), ("lunation", "推进月相"),
        ]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        resultTabTitle(selectedTab, in: tabs, moreTabs)
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "progressed_planets":
            PositionTableView(title: "次限推进盘", positions: result.progressedPlanets)
        case "natal_planets":
            PositionTableView(title: "本命盘", positions: result.natalPlanets)
        case "prog_to_natal":
            AspectTableView(
                title: "推进→本命相位",
                leftColumnTitle: "推进天体",
                rightColumnTitle: "本命天体",
                aspects: result.progressedToNatalAspects
            )
        case "prog_to_prog":
            AspectTableView(
                title: "推进盘相位",
                leftColumnTitle: "天体A",
                rightColumnTitle: "天体B",
                aspects: result.progressedToProgressedAspects
            )
        case "lunation":
            if let lunation = result.progressedLunation {
                ProgressedLunationView(lunation: lunation)
            } else {
                Text("无月相数据").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            PositionTableView(title: "次限推进盘", positions: result.progressedPlanets)
        }
    }

    var markdown: String { MarkdownModernExportBuilder.progression(result) }
    var json: String { TextExportBuilder.json(result) }
    var csv: String { TextExportBuilder.csv(result) }
}

struct ProgressedLunationView: View {
    let lunation: ProgressedLunation

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xl) {
            Text("推进月相").font(TS.Font.sectionTitle)

            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                Text(lunation.phaseName)
                    .font(TS.Font.pageTitle)

                Grid(alignment: .leading, horizontalSpacing: TS.Spacing.xl, verticalSpacing: TS.Spacing.md) {
                    GridRow {
                        Text("日月夹角").foregroundStyle(.secondary).font(TS.Font.label)
                        Text("\(lunation.sunMoonSeparation, specifier: "%.2f")°")
                            .font(TS.Font.mono).monospacedDigit()
                    }
                    GridRow {
                        Text("最近相位").foregroundStyle(.secondary).font(TS.Font.label)
                        Text("\(lunation.phaseAngle, specifier: "%.0f")°")
                            .font(TS.Font.mono).monospacedDigit()
                    }
                }
            }
            .padding(TS.Padding.sectionGap)
            .background(TS.SemanticColor.cardBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
        }
    }
}

// MARK: - Solar Arc Views

struct SolarArcResultPane: View {
    let result: SolarArcResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { markdown },
                jsonProvider: { json },
                csvProvider: { csv },
                basename: "solar_arc"
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [
            ("sa_planets", "Solar Arc盘"), ("natal_planets", "本命盘"), ("sa_to_natal", "SA→本命相位"),
            ("patterns", "图形"),
        ]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        resultTabTitle(selectedTab, in: tabs, moreTabs)
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "sa_planets":
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                HStack {
                    Text("Solar Arc").font(TS.Font.sectionTitle)
                    Spacer()
                    Text("Arc: \(result.arcValue, specifier: "%.4f")°").font(TS.Font.label).monospacedDigit()
                }
                PositionTableView(title: "Solar Arc 盘", positions: result.solarArcPlanets)
            }
        case "natal_planets":
            PositionTableView(title: "本命盘", positions: result.natalPlanets)
        case "sa_to_natal":
            AspectTableView(
                title: "Solar Arc→本命相位",
                leftColumnTitle: "SA天体",
                rightColumnTitle: "本命天体",
                aspects: result.solarArcToNatalAspects
            )
        case "patterns":
            PatternListView(patterns: result.patterns ?? [])
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            PositionTableView(title: "Solar Arc 盘", positions: result.solarArcPlanets)
        }
    }

    var markdown: String { MarkdownModernExportBuilder.solarArc(result) }
    var json: String { TextExportBuilder.json(result) }
    var csv: String { TextExportBuilder.csv(result) }
}

// MARK: - Pattern List View

// MARK: - Harmonic Views

struct HarmonicResultPane: View {
    let result: HarmonicResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { markdown },
                jsonProvider: { json },
                csvProvider: { csv },
                basename: "harmonic_h\(result.harmonicOrder)"
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [
            ("planets", "调和行星"), ("aspects", "调和相位"), ("diagnostics", "诊断"), ("json", "JSON"),
        ]
    }

    var moreTabs: [(String, String)] {
        []
    }

    var tabTitle: String {
        resultTabTitle(selectedTab, in: tabs, moreTabs)
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "planets":
            PositionTableView(title: "H\(result.harmonicOrder) 调和盘", positions: result.planets)
        case "aspects":
            AspectTableView(title: "H\(result.harmonicOrder) 调和相位", aspects: result.aspects)
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            PositionTableView(title: "H\(result.harmonicOrder) 调和盘", positions: result.planets)
        }
    }

    var markdown: String { MarkdownModernExportBuilder.harmonic(result) }
    var json: String { TextExportBuilder.json(result) }
    var csv: String { TextExportBuilder.csv(result) }
}

// MARK: - Return Views

struct ModernReturnResultPane: View {
    let result: ModernReturnResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { markdown },
                jsonProvider: { json },
                csvProvider: { csv },
                basename: "modern_return"
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [
            ("current_return", "当前返照"),
            ("biwheel", "双盘"),
            ("previous_next", "前后返照"),
            ("return_to_natal", "返照→本命"),
            ("house_overlay", "宫位落点"),
            ("patterns", "图形"),
        ]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        resultTabTitle(selectedTab, in: tabs, moreTabs)
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "current_return":
            if let occurrence = result.currentCycleReturn {
                ModernReturnOccurrenceView(title: "当前返照", occurrence: occurrence)
            } else {
                EmptyStateView(title: "未找到当前返照", systemImage: "calendar.badge.exclamationmark", description: result.suggestedWindow ?? "请检查参考时间和星历设置。")
            }
        case "biwheel":
            if let occurrence = result.currentCycleReturn,
               let chart = occurrence.chart {
                ChartWheelView(data: ChartWheelData(modernReturnChart: chart, returnToNatalAspects: occurrence.returnToNatalAspects))
            } else {
                EmptyStateView(title: "无法构建双盘", systemImage: "circle.grid.2x2", description: "当前返照快照缺少本命或返照端点。")
            }
        case "previous_next":
            ModernReturnCycleView(result: result)
        case "return_to_natal":
            if let occurrence = result.currentCycleReturn {
                AspectTableView(
                    title: "返照→本命相位",
                    leftColumnTitle: "返照天体",
                    rightColumnTitle: "本命天体",
                    aspects: occurrence.returnToNatalAspects
                )
            } else {
                EmptyStateView(title: "无返照相位", systemImage: "arrow.left.arrow.right", description: "当前返照快照不可用。")
            }
        case "house_overlay":
            if let occurrence = result.currentCycleReturn {
                ReturnHouseOverlayView(overlays: occurrence.houseOverlay)
            } else {
                EmptyStateView(title: "无宫位落点", systemImage: "house", description: "当前返照快照不可用。")
            }
        case "patterns":
            PatternListView(patterns: result.currentCycleReturn?.chart?.patterns ?? [])
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            if let occurrence = result.currentCycleReturn {
                ModernReturnOccurrenceView(title: "当前返照", occurrence: occurrence)
            } else {
                EmptyStateView(title: "等待返照盘计算", systemImage: "arrow.clockwise.circle")
            }
        }
    }

    var markdown: String { MarkdownModernExportBuilder.modernReturn(result) }
    var json: String { TextExportBuilder.json(result) }
    var csv: String { TextExportBuilder.csv(result) }
}

struct ModernReturnOccurrenceView: View {
    let title: String
    let occurrence: ModernReturnOccurrence

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                Text(title).font(TS.Font.sectionTitle)
                Grid(alignment: .leading, horizontalSpacing: TS.Spacing.xl, verticalSpacing: TS.Spacing.sm) {
                    GridRow { Text("精确 UTC").foregroundStyle(.secondary); Text(occurrence.exactUTC).monospacedDigit() }
                    GridRow { Text("当地时间").foregroundStyle(.secondary); Text(occurrence.exactLocal).monospacedDigit() }
                    GridRow { Text("返照黄经").foregroundStyle(.secondary); Text(String(format: "%.8f°", occurrence.returnLongitude)).monospacedDigit() }
                    GridRow { Text("求根误差").foregroundStyle(.secondary); Text(String(format: "%.3e°", occurrence.exactError)).monospacedDigit() }
                }
                if let error = occurrence.error {
                    Text(error).foregroundStyle(TS.SemanticColor.warning)
                }
                if let chart = occurrence.chart {
                    PositionTableView(title: "返照行星", positions: chart.planets)
                    if !chart.angles.isEmpty {
                        Table(chart.angles) {
                            TableColumn("角点", value: \.name)
                            TableColumn("黄经") { Text(String(format: "%.4f°", $0.longitude)).monospacedDigit() }
                            TableColumn("宫位") { Text("\($0.house)").monospacedDigit() }
                        }
                        .tsTableStyle()
                    }
                    if !chart.houses.isEmpty {
                        Table(chart.houses) {
                            TableColumn("宫位") { Text("\($0.house)") }
                            TableColumn("宫头") { Text($0.cuspText) }
                            TableColumn("主星", value: \.ruler)
                        }
                        .tsTableStyle()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ModernReturnCycleView: View {
    let result: ModernReturnResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                Text("返照序列").font(TS.Font.sectionTitle)
                occurrenceRow("上一次", result.previousReturn)
                occurrenceRow("当前周期", result.currentCycleReturn)
                occurrenceRow("下一次", result.nextReturn)
                if let start = result.searchStartLocal, let end = result.searchEndLocal {
                    Text("搜索范围：\(start) 至 \(end)")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func occurrenceRow(_ title: String, _ occurrence: ModernReturnOccurrence?) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            Text(title).font(TS.Font.label).foregroundStyle(.secondary)
            if let occurrence {
                HStack(spacing: TS.Spacing.lg) {
                    Text(occurrence.exactLocal).monospacedDigit()
                    Text(String(format: "%.8f°", occurrence.returnLongitude)).monospacedDigit()
                    Text("误差 \(String(format: "%.2e", occurrence.exactError))°")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } else {
                Text("未找到").foregroundStyle(.secondary)
            }
        }
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.card))
    }
}

struct ReturnHouseOverlayView: View {
    let overlays: [ReturnHouseOverlay]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("返照行星落入本命宫位").font(TS.Font.sectionTitle)
            if overlays.isEmpty {
                EmptyStateView(title: "无宫位落点", systemImage: "house")
            } else {
                Table(overlays) {
                    TableColumn("天体", value: \.bodyName)
                    TableColumn("返照宫") { Text("\($0.returnHouse)") }
                    TableColumn("本命宫") { Text("\($0.natalHouse)") }
                }
                .tsTableStyle()
            }
        }
    }
}

struct PatternListView: View {
    let patterns: [PatternResult]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("图形模式").font(TS.Font.sectionTitle)
            if patterns.isEmpty {
                EmptyStateView(title: "未检测到图形模式", systemImage: "triangle")
            } else {
                List(patterns) { pattern in
                    VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                        HStack {
                            Text(pattern.typeName).font(TS.Font.sectionTitle)
                            Spacer()
                            Text(pattern.confidence).font(TS.Font.label).foregroundStyle(.secondary)
                            Text(pattern.orbSummary).font(TS.Font.label).foregroundStyle(.secondary)
                        }
                        Text("成员: \(pattern.members.joined(separator: ", "))")
                            .font(TS.Font.label).foregroundStyle(.secondary)
                        if let sign = pattern.stelliumSign {
                            Text("星座: \(sign)").font(TS.Font.label).foregroundStyle(.secondary)
                        }
                        if let house = pattern.stelliumHouse {
                            Text("宫位: \(house)").font(TS.Font.label).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
