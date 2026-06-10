import SwiftUI

extension ContentView {
    // MARK: - Rectify Results Pane

    var rectifyResultsPane: some View {
        VStack {
            if calcVM.isRunning {
                EmptyStateView(
                    title: "生时矫正计算中",
                    systemImage: "hourglass",
                    description: calcVM.calculationProgressText.isEmpty ? "正在调用后端计算 61 个候选点。" : calcVM.calculationProgressText
                )
            } else if let response = calcVM.rectifyResponse {
                PrimaryDirectionRectifierView(
                    response: response,
                    centerDate: natalDate,
                    timeZone: selectedTimeZone,
                    level2Response: $calcVM.rectifyLevel2Response,
                    level3Response: $calcVM.rectifyLevel3Response,
                    s1Index: $calcVM.rectifyS1Index,
                    s2Index: $calcVM.rectifyS2Index,
                    activeLevel: $calcVM.rectifyActiveLevel,
                    level3ResponseID: $calcVM.rectifyLevel3ResponseID,
                    onComputeLevel2: { offsetSec in
                        // Invalidate in-flight immediately, before debounce fires
                        calcVM.rectifyLevel2Gen += 1
                        calcVM.rectifyLevel3Gen += 1
                        Task { await runRectifyLevel2(offsetSeconds: offsetSec) }
                    },
                    onComputeLevel3: { offsetSec in
                        calcVM.rectifyLevel3Gen += 1
                        Task { await runRectifyLevel3(offsetSeconds: offsetSec) }
                    }
                )
            } else {
                EmptyStateView(
                    title: "等待计算",
                    systemImage: "clock.arrow.circlepath",
                    description: "点击左侧「计算生时矫正」按钮开始计算。"
                )
            }
        }
    }

    // MARK: - Vedic Results Pane

    var vedicResultsPane: some View {
        Group {
            if calcVM.isRunning {
                EmptyStateView(
                    title: "吠陀计算中",
                    systemImage: "hourglass",
                    description: calcVM.calculationProgressText.isEmpty ? "正在调用后端计算。" : calcVM.calculationProgressText
                )
            } else if let result = calcVM.vedicResult {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    ResultPaneToolbar(
                        selection: $calcVM.vedicSelectedTab,
                        tabs: vedicTabs,
                        moreTabs: vedicMoreTabs,
                        currentTabTitle: vedicTabTitle,
                        markdownProvider: { MarkdownExportBuilder.vedic(result, sections: vedicExportSections) },
                        jsonProvider: { TextExportBuilder.json(result) },
                        csvProvider: { TextExportBuilder.csv(result) },
                        basename: "vedic_chart",
                        classicalSectionPicker: { showVedicExportSheet = true }
                    )
                    .padding(.horizontal, TS.Padding.resultContent)

                    Group {
                        switch calcVM.vedicSelectedTab {
                        case "overview":
                            VedicOverviewView(result: result)
                        case "panchanga":
                            if let panchanga = result.panchanga {
                                VedicPanchangaView(panchanga: panchanga, solarDay: result.solarDay)
                            } else {
                                EmptyStateView(title: "无 Pañcāṅga 数据", systemImage: "calendar")
                            }
                        case "dasa":
                            VedicDasaContainerView(
                                vimshottari: result.vimshottari,
                                yogini: result.yoginiDasa,
                                ashtottari: result.ashtottariDasa
                            )
                        case "shadbala":
                            if let shadbala = result.shadbala {
                                VedicShadbalaView(shadbala: shadbala)
                            } else {
                                EmptyStateView(title: "无 Ṣaḍbala 数据", systemImage: "chart.bar")
                            }
                        case "yoga":
                            if let yogas = result.yogas, !yogas.isEmpty {
                                VedicYogaListView(yogas: yogas)
                            } else {
                                EmptyStateView(title: "未检测到 Yōga", systemImage: "sparkles")
                            }
                        case "navamsa":
                            if let navamsa = result.navamsa {
                                VedicNavamsaView(navamsa: navamsa)
                            } else {
                                EmptyStateView(title: "无 Navāṃśa 数据", systemImage: "square.grid.3x3")
                            }
                        case "varga":
                            if let charts = result.divisionalCharts, !charts.isEmpty {
                                VedicDivisionalChartView(charts: charts)
                            } else {
                                EmptyStateView(title: "无 Varga 数据", systemImage: "square.grid.3x3")
                            }
                        case "jaimini":
                            VedicJaiminiView(
                                karakas: result.jaiminiKarakas,
                                arudha: result.arudha
                            )
                        case "ashtakavarga":
                            if let ashtakavarga = result.ashtakavarga {
                                VedicAshtakavargaView(data: ashtakavarga)
                            } else {
                                EmptyStateView(title: "无 Aṣṭakavarga 数据", systemImage: "tablecells")
                            }
                        case "relationships":
                            if let relationships = result.planetRelationships {
                                VedicRelationshipsView(relationships: relationships)
                            } else {
                                EmptyStateView(title: "无行星关系数据", systemImage: "link")
                            }
                        case "moon_chart":
                            if let moonChart = result.moonChart {
                                VedicDerivedChartView(title: "Moon Chart", chart: moonChart)
                            } else {
                                EmptyStateView(title: "无 Moon Chart 数据", systemImage: "moon")
                            }
                        case "bhava":
                            if let bhavaChart = result.bhavaChart {
                                VedicDerivedChartView(title: "Bhava Chart", chart: bhavaChart)
                            } else {
                                EmptyStateView(title: "无 Bhava Chart 数据", systemImage: "building.columns")
                            }
                        case "upagrahas":
                            if let upagrahas = result.upagrahas, !upagrahas.isEmpty {
                                VedicUpagrahaView(upagrahas: upagrahas)
                            } else {
                                EmptyStateView(title: "无副行星数据", systemImage: "smallcircle.filled.circle")
                            }
                        case "special_lagnas":
                            if let lagnas = result.specialLagnas, !lagnas.isEmpty {
                                VedicSpecialLagnaView(lagnas: lagnas)
                            } else {
                                EmptyStateView(title: "无特殊 Lagna 数据", systemImage: "scope")
                            }
                        case "ai":
                            AIAnalysisView(
                                streamKey: "vedic",
                                analysis: aiVM.vedicAnalysis,
                                reasoning: aiVM.vedicReasoning,
                                isAnalyzing: aiVM.isAnalyzing,
                                canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ) {
                                Task { await analyzeVedicResult() }
                            }
                        case "diagnostics":
                            if let warnings = result.warnings, !warnings.isEmpty {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                                        ForEach(warnings, id: \.self) { warning in
                                            Label(warning, systemImage: "exclamationmark.triangle")
                                                .font(TS.Font.body)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(TS.Padding.resultContent)
                                }
                            } else {
                                EmptyStateView(title: "无诊断警告", systemImage: "checkmark.circle")
                            }
                        case "json":
                            RawJSONView(value: result)
                        default:
                            VedicOverviewView(result: result)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, TS.Padding.resultContent)
                }
                .padding(.vertical, TS.Spacing.md)
                .sheet(isPresented: $showVedicExportSheet) {
                    vedicExportSheet
                }
            } else {
                EmptyStateView(
                    title: "等待吠陀排盘",
                    systemImage: "sun.max.circle",
                    description: "填写出生设置后开始排盘。"
                )
            }
        }
    }

    var vedicTabs: [(id: String, title: String)] {
        [
            ("overview", "综览"),
            ("panchanga", "Pañcāṅga"),
            ("dasa", "Daśā"),
            ("shadbala", "Ṣaḍbala"),
            ("yoga", "Yōga"),
            ("navamsa", "Navāṃśa"),
            ("varga", "Varga"),
            ("jaimini", "Jaimini"),
            ("ashtakavarga", "Aṣṭakavarga"),
            ("relationships", "关系"),
        ]
    }

    var vedicMoreTabs: [(id: String, title: String)] {
        [
            ("moon_chart", "Moon Chart"),
            ("bhava", "Bhava"),
            ("upagrahas", "副行星"),
            ("special_lagnas", "特殊 Lagna"),
            ("ai", "AI 分析"),
            ("diagnostics", "诊断"),
            ("json", "JSON"),
        ]
    }

    var vedicTabTitle: String {
        resultTabTitle(calcVM.vedicSelectedTab, in: vedicTabs, vedicMoreTabs)
    }

    @ViewBuilder
    private var vedicExportSheet: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("选择导出内容")
                .font(TS.Font.sectionTitle)
                .padding(.top, 8)

            let vedicSections = MarkdownExportBuilder.ExportSection.vedicSectionIDs

            ScrollView {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    sectionToggleGroup(
                        title: "吠陀",
                        sections: Array(vedicSections).sorted { $0.label < $1.label },
                        allSections: vedicSections,
                        selection: $vedicExportSections
                    )
                }
            }

            HStack {
                Button("取消") { showVedicExportSheet = false }
                Spacer()
                Button("全选") { vedicExportSections = vedicSections }
                Button("全不选") { vedicExportSections = [] }
                Button("导出 Markdown") {
                    let md = MarkdownExportBuilder.vedic(calcVM.vedicResult!, sections: vedicExportSections)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(md, forType: .string)
                    showVedicExportSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(vedicExportSections.isEmpty)
            }
        }
        .padding()
        .frame(width: 380, height: 360)
    }
}
