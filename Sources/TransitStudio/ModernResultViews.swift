import SwiftUI

// MARK: - Synastry Views

struct SynastryResultPane: View {
    let result: SynastryResult
    @Binding var selectedTab: String
    let analysis: String
    let reasoning: String
    let isAnalyzing: Bool
    let canAnalyze: Bool
    let onAnalyze: () -> Void

    init(result: SynastryResult, selectedTab: Binding<String>, analysis: String = "", reasoning: String = "", isAnalyzing: Bool = false, canAnalyze: Bool = false, onAnalyze: @escaping () -> Void = {}) {
        self.result = result
        self._selectedTab = selectedTab
        self.analysis = analysis
        self.reasoning = reasoning
        self.isAnalyzing = isAnalyzing
        self.canAnalyze = canAnalyze
        self.onAnalyze = onAnalyze
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabRows: tabRows,
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
        .padding(14)
    }

    var tabRows: [[(String, String)]] {
        [
            [("cross_aspects", "跨盘相位"), ("a_in_b_houses", "A入B宫"), ("b_in_a_houses", "B入A宫")],
            [("person_a_planets", "A本命"), ("person_b_planets", "B本命"), ("ai", "AI分析")],
        ]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        switch selectedTab {
        case "cross_aspects": return "跨盘相位"
        case "a_in_b_houses": return "A落入B宫"
        case "b_in_a_houses": return "B落入A宫"
        case "person_a_planets": return "A本命位置"
        case "person_b_planets": return "B本命位置"
        case "diagnostics": return "诊断"
        case "json": return "JSON"
        case "ai": return "AI分析"
        default: return ""
        }
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
        case "diagnostics":
            RawJSONView(value: result)
        case "json":
            RawJSONView(value: result)
        case "ai":
            AIAnalysisView(
                analysis: analysis,
                reasoning: reasoning,
                isAnalyzing: isAnalyzing,
                canAnalyze: canAnalyze
            ) {
                onAnalyze()
            }
        default:
            AspectTableView(title: "跨盘相位", leftColumnTitle: "A天体", rightColumnTitle: "B天体", aspects: result.crossAspects)
        }
    }

    var markdown: String { MarkdownModernExportBuilder.synastry(result) }
    var json: String { TextExportBuilder.json(result) }
    var csv: String { TextExportBuilder.json(result) }
}

struct HousePlacementView: View {
    let title: String
    let placements: [HousePlacement]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if placements.isEmpty {
                Text("无数据").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(placements) {
                    TableColumn("天体", value: \.bodyName)
                    TableColumn("宫位") { Text("\($0.house)") }
                }
            }
        }
    }
}

// MARK: - Composite / Davison Shared View

struct CompositeDavisonResultPane<T: ChartResultFields>: View {
    let title: String
    let result: T
    @Binding var selectedTab: String
    let analysis: String
    let reasoning: String
    let isAnalyzing: Bool
    let canAnalyze: Bool
    let onAnalyze: () -> Void

    init(title: String, result: T, selectedTab: Binding<String>, analysis: String = "", reasoning: String = "", isAnalyzing: Bool = false, canAnalyze: Bool = false, onAnalyze: @escaping () -> Void = {}) {
        self.title = title
        self.result = result
        self._selectedTab = selectedTab
        self.analysis = analysis
        self.reasoning = reasoning
        self.isAnalyzing = isAnalyzing
        self.canAnalyze = canAnalyze
        self.onAnalyze = onAnalyze
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabRows: tabRows,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { markdown },
                jsonProvider: { json },
                csvProvider: { csv },
                basename: title.lowercased()
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(14)
    }

    var tabRows: [[(String, String)]] {
        [
            [("planets", "行星"), ("angles", "角点"), ("houses", "宫位"), ("aspects", "相位")],
            [("patterns", "图形"), ("ai", "AI分析")],
        ]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        switch selectedTab {
        case "planets": return "行星位置"
        case "angles": return "角点"
        case "houses": return "宫位"
        case "aspects": return "相位"
        case "patterns": return "图形"
        case "diagnostics": return "诊断"
        case "json": return "JSON"
        case "ai": return "AI分析"
        default: return ""
        }
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
        case "diagnostics", "json":
            RawJSONView(value: result)
        case "ai":
            AIAnalysisView(
                analysis: analysis,
                reasoning: reasoning,
                isAnalyzing: isAnalyzing,
                canAnalyze: canAnalyze
            ) {
                onAnalyze()
            }
        default:
            PositionTableView(title: "\(title) 行星位置", positions: result.planets)
        }
    }

    var markdown: String { "" }
    var json: String { "" }
    var csv: String { "" }
}

// MARK: - Progression Views

struct ProgressionResultPane: View {
    let result: ProgressionResult
    @Binding var selectedTab: String
    let analysis: String
    let reasoning: String
    let isAnalyzing: Bool
    let canAnalyze: Bool
    let onAnalyze: () -> Void

    init(result: ProgressionResult, selectedTab: Binding<String>, analysis: String = "", reasoning: String = "", isAnalyzing: Bool = false, canAnalyze: Bool = false, onAnalyze: @escaping () -> Void = {}) {
        self.result = result
        self._selectedTab = selectedTab
        self.analysis = analysis
        self.reasoning = reasoning
        self.isAnalyzing = isAnalyzing
        self.canAnalyze = canAnalyze
        self.onAnalyze = onAnalyze
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabRows: tabRows,
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
        .padding(14)
    }

    var tabRows: [[(String, String)]] {
        [
            [("progressed_planets", "推进盘"), ("natal_planets", "本命盘"), ("prog_to_natal", "推进→本命相位")],
            [("prog_to_prog", "推进盘相位"), ("lunation", "推进月相"), ("ai", "AI分析")],
        ]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        switch selectedTab {
        case "progressed_planets": return "次限推进盘"
        case "natal_planets": return "本命盘"
        case "prog_to_natal": return "推进→本命相位"
        case "prog_to_prog": return "推进盘相位"
        case "lunation": return "推进月相"
        case "diagnostics": return "诊断"
        case "json": return "JSON"
        case "ai": return "AI分析"
        default: return ""
        }
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
        case "diagnostics", "json":
            RawJSONView(value: result)
        case "ai":
            AIAnalysisView(
                analysis: analysis,
                reasoning: reasoning,
                isAnalyzing: isAnalyzing,
                canAnalyze: canAnalyze
            ) {
                onAnalyze()
            }
        default:
            PositionTableView(title: "次限推进盘", positions: result.progressedPlanets)
        }
    }

    var markdown: String { MarkdownModernExportBuilder.progression(result) }
    var json: String { TextExportBuilder.json(result) }
    var csv: String { TextExportBuilder.json(result) }
}

struct ProgressedLunationView: View {
    let lunation: ProgressedLunation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推进月相").font(.headline)
            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("日月夹角").foregroundStyle(.secondary)
                        Text("\(lunation.sunMoonSeparation, specifier: "%.2f")°")
                    }
                    GridRow {
                        Text("最近相位").foregroundStyle(.secondary)
                        Text("\(lunation.phaseAngle, specifier: "%.0f")°")
                    }
                    GridRow {
                        Text("月相名称").foregroundStyle(.secondary)
                        Text(lunation.phaseName).font(.title2.weight(.semibold))
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Solar Arc Views

struct SolarArcResultPane: View {
    let result: SolarArcResult
    @Binding var selectedTab: String
    let analysis: String
    let reasoning: String
    let isAnalyzing: Bool
    let canAnalyze: Bool
    let onAnalyze: () -> Void

    init(result: SolarArcResult, selectedTab: Binding<String>, analysis: String = "", reasoning: String = "", isAnalyzing: Bool = false, canAnalyze: Bool = false, onAnalyze: @escaping () -> Void = {}) {
        self.result = result
        self._selectedTab = selectedTab
        self.analysis = analysis
        self.reasoning = reasoning
        self.isAnalyzing = isAnalyzing
        self.canAnalyze = canAnalyze
        self.onAnalyze = onAnalyze
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabRows: tabRows,
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
        .padding(14)
    }

    var tabRows: [[(String, String)]] {
        [
            [("sa_planets", "Solar Arc盘"), ("natal_planets", "本命盘"), ("sa_to_natal", "SA→本命相位")],
            [("patterns", "图形"), ("ai", "AI分析")],
        ]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        switch selectedTab {
        case "sa_planets": return "Solar Arc 盘"
        case "natal_planets": return "本命盘"
        case "sa_to_natal": return "SA→本命相位"
        case "patterns": return "图形"
        case "diagnostics": return "诊断"
        case "json": return "JSON"
        case "ai": return "AI分析"
        default: return ""
        }
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "sa_planets":
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Solar Arc").font(.headline)
                    Spacer()
                    Text("Arc: \(result.arcValue, specifier: "%.4f")°").font(.caption).monospacedDigit()
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
        case "diagnostics", "json":
            RawJSONView(value: result)
        case "ai":
            AIAnalysisView(
                analysis: analysis,
                reasoning: reasoning,
                isAnalyzing: isAnalyzing,
                canAnalyze: canAnalyze
            ) {
                onAnalyze()
            }
        default:
            PositionTableView(title: "Solar Arc 盘", positions: result.solarArcPlanets)
        }
    }

    var markdown: String { MarkdownModernExportBuilder.solarArc(result) }
    var json: String { TextExportBuilder.json(result) }
    var csv: String { TextExportBuilder.json(result) }
}

// MARK: - Pattern List View

// MARK: - Harmonic Views

struct HarmonicResultPane: View {
    let result: HarmonicResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("H\(result.harmonicOrder) 调和盘").font(.headline)
            ResultPaneToolbar(
                selection: $selectedTab,
                tabRows: tabRows,
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
        .padding(14)
    }

    var tabRows: [[(String, String)]] {
        [
            [("planets", "调和行星"), ("aspects", "调和相位"), ("json", "JSON")],
        ]
    }

    var moreTabs: [(String, String)] {
        []
    }

    var tabTitle: String {
        switch selectedTab {
        case "planets": return "调和行星"
        case "aspects": return "调和相位"
        case "json": return "JSON"
        default: return ""
        }
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "planets":
            PositionTableView(title: "H\(result.harmonicOrder) 调和盘", positions: result.planets)
        case "aspects":
            AspectTableView(title: "H\(result.harmonicOrder) 调和相位", aspects: result.aspects)
        case "json":
            RawJSONView(value: result)
        default:
            PositionTableView(title: "H\(result.harmonicOrder) 调和盘", positions: result.planets)
        }
    }

    var markdown: String { MarkdownModernExportBuilder.harmonic(result) }
    var json: String { TextExportBuilder.json(result) }
    var csv: String { TextExportBuilder.json(result) }
}

struct PatternListView: View {
    let patterns: [PatternResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图形模式").font(.headline)
            if patterns.isEmpty {
                Text("未检测到图形模式").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(patterns) { pattern in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(pattern.typeName).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(pattern.confidence).font(.caption).foregroundStyle(.secondary)
                            Text(pattern.orbSummary).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("成员: \(pattern.members.joined(separator: ", "))")
                            .font(.caption).foregroundStyle(.secondary)
                        if let sign = pattern.stelliumSign {
                            Text("星座: \(sign)").font(.caption).foregroundStyle(.secondary)
                        }
                        if let house = pattern.stelliumHouse {
                            Text("宫位: \(house)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
