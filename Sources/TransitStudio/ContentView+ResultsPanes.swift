import SwiftUI

extension ContentView {
    var runSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Button {
                Task { await runCurrentMode() }
            } label: {
                Label(calcVM.isRunning ? "计算中" : runButtonTitle, systemImage: calcVM.isRunning ? "hourglass" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(runDisabled)

            if calcVM.calculationProgress != nil {
                VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                    ProgressView(value: calcVM.calculationProgress)
                    Text(calcVM.calculationProgressText)
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if calcVM.errorMessage != nil {
                Text(calcVM.errorMessage!)
                    .font(TS.Font.body)
                    .foregroundStyle(TS.SemanticColor.error)
                    .textSelection(.enabled)
            }

            if !calcVM.asteroidPreparationMessage.isEmpty {
                Text(calcVM.asteroidPreparationMessage)
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.card))
    }

    var runButtonTitle: String {
        switch mode {
        case .settings:
            if practiceMode == .classical { return "保存本命盘并古典排盘" }
            if practiceMode == .vedic { return "计算吠陀排盘" }
            switch modernSubMode {
            case .natal: return "保存本命盘并现代排盘"
            case .synastry: return "计算合盘"
            case .composite: return "计算组合盘"
            case .davison: return "计算戴维森盘"
            case .progression: return "计算次限推进"
            case .solarArc: return "计算太阳弧"
            case .harmonic: return "计算调和盘"
            }
        case .horary:
            return "Horary 起盘"
        case .moment:
            return "计算时间点"
        case .scan:
            return "扫描窗口"
        case .rectify:
            return "计算生时矫正"
        }
    }

    var runDisabled: Bool {
        if calcVM.isRunning {
            return true
        }

        switch mode {
        case .settings:
            if practiceMode == .classical {
                return parseDouble(birthLatitude) == nil || parseDouble(birthLongitude) == nil
            }
            if practiceMode == .vedic {
                return parseDouble(birthLatitude) == nil || parseDouble(birthLongitude) == nil
            }
            switch modernSubMode {
            case .natal, .harmonic:
                return parseDouble(birthLatitude) == nil || parseDouble(birthLongitude) == nil
            case .synastry, .composite, .davison:
                return parseDouble(birthLatitude) == nil || parseDouble(birthLongitude) == nil
                    || parseDouble(modernPersonBLatitude) == nil || parseDouble(modernPersonBLongitude) == nil
            case .progression, .solarArc:
                return parseDouble(birthLatitude) == nil || parseDouble(birthLongitude) == nil
            }
        case .horary:
            return parseDouble(horaryLatitude) == nil
                || parseDouble(horaryLongitude) == nil
                || horaryQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .moment:
            return selectedNatalBodies.isEmpty || selectedTransitBodies.isEmpty || selectedAspectRequests(orb: globalOrb).isEmpty
        case .scan:
            return selectedTransitBodies.isEmpty
                || (selectedScanKind == "aspect" && selectedAspectRequests(orb: 0).isEmpty)
                || (selectedScanKind == "aspect" && resolvedScanTargetText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        case .rectify:
            return parseDouble(birthLatitude) == nil || parseDouble(birthLongitude) == nil
        }
    }

    var resultsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if isShowingAppSettingsPage {
                AppSettingsView(usesFixedFrame: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                resultsContent
            }
        }
    }

    var resultsContent: AnyView {
        switch mode {
        case .settings:
            if practiceMode == .classical { return AnyView(classicalResultsPane) }
            if practiceMode == .vedic { return AnyView(vedicResultsPane) }
            switch modernSubMode {
            case .natal: return AnyView(modernNatalResultsPane)
            case .synastry: return AnyView(synastryResultsPane)
            case .composite: return AnyView(compositeResultsPane)
            case .davison: return AnyView(davisonResultsPane)
            case .progression: return AnyView(progressionResultsPane)
            case .solarArc: return AnyView(solarArcResultsPane)
            case .harmonic: return AnyView(harmonicResultsPane)
            }
        case .horary:
            return AnyView(horaryResultsPane)
        case .moment:
            return AnyView(momentResultsPane)
        case .scan:
            return AnyView(scanResultsPane)
        case .rectify:
            return AnyView(rectifyResultsPane)
        }
    }

    // MARK: - Modern Natal Results Pane
    var modernNatalResultsPane: some View {
        Group {
            if calcVM.momentResult != nil {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    ResultPaneToolbar(
                        selection: $calcVM.modernNatalSelectedTab,
                        tabs: modernNatalTabs,
                        moreTabs: modernNatalMoreTabs,
                        currentTabTitle: modernNatalTabTitle,
                        markdownProvider: { MarkdownExportBuilder.natal(calcVM.momentResult!) },
                        jsonProvider: { TextExportBuilder.natalJSON(calcVM.momentResult!) },
                        csvProvider: { TextExportBuilder.natalCSV(calcVM.momentResult!) },
                        basename: "natal_chart"
                    )
                    modernNatalSelectedResultView(calcVM.momentResult!)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(TS.Padding.resultContent)
            } else {
                EmptyStateView(title: "等待现代排盘", systemImage: "circle.grid.2x2", description: "填写出生设置并选择天体后开始排盘。")
            }
        }
    }

    var modernNatalTabs: [(id: String, title: String)] {
        [
            ("wheel", "星盘图"), ("natal_positions", "本命位置"), ("natal_aspects", "本命相位"), ("ai", "AI 分析"),
        ]
    }

    var modernNatalMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断")]
    }

    var modernNatalTabTitle: String {
        switch calcVM.modernNatalSelectedTab {
        case "wheel": return "星盘图"
        case "natal_positions": return "本命位置"
        case "natal_aspects": return "本命相位"
        case "ai": return "AI 分析"
        case "diagnostics": return "诊断"
        default: return ""
        }
    }

    @ViewBuilder
    func modernNatalSelectedResultView(_ result: TransitResult) -> some View {
        switch calcVM.modernNatalSelectedTab {
        case "wheel":
            ChartWheelView(data: ChartWheelData(natalResult: result))
        case "natal_positions":
            PositionTableView(title: "本命位置", positions: result.natalPositions)
        case "natal_aspects":
            AspectTableView(
                title: "本命相位",
                leftColumnTitle: "天体 A",
                rightColumnTitle: "天体 B",
                aspects: natalAspects(from: result)
            )
        case "diagnostics":
            DiagnosticsView(result: result)
        case "ai":
            AIAnalysisView(
                streamKey: "moment",
                analysis: aiVM.momentAnalysis,
                reasoning: aiVM.momentReasoning,
                isAnalyzing: aiVM.isAnalyzing,
                canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await analyzeNatalResult() }
            }
        default:
            ChartWheelView(data: ChartWheelData(transitResult: result))
        }
    }

    // MARK: - Moment Results Pane
    var momentResultsPane: some View {
        Group {
            if calcVM.momentResult != nil {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    ResultPaneToolbar(
                        selection: $calcVM.momentSelectedTab,
                        tabs: momentTabs,
                        moreTabs: momentMoreTabs,
                        currentTabTitle: momentTabTitle,
                        markdownProvider: { MarkdownExportBuilder.moment(calcVM.momentResult!) },
                        jsonProvider: { TextExportBuilder.json(calcVM.momentResult!) },
                        csvProvider: { TextExportBuilder.csv(calcVM.momentResult!) },
                        basename: "moment_chart"
                    )
                    momentSelectedResultView(calcVM.momentResult!)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(TS.Padding.resultContent)
            } else {
                EmptyStateView(title: "等待计算", systemImage: "chart.line.uptrend.xyaxis", description: "选择天体、相位和容许度后开始计算。")
            }
        }
    }

    var momentTabs: [(id: String, title: String)] {
        [
            ("wheel", "星盘图"), ("aspects", "相位"), ("transit_positions", "行运位置"), ("natal_positions", "本命位置"), ("ai", "AI 分析"),
        ]
    }

    var momentMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断")]
    }

    var momentTabTitle: String {
        switch calcVM.momentSelectedTab {
        case "wheel": return "星盘图"
        case "aspects": return "相位"
        case "transit_positions": return "行运位置"
        case "natal_positions": return "本命位置"
        case "ai": return "AI 分析"
        case "diagnostics": return "诊断"
        default: return ""
        }
    }

    @ViewBuilder
    func momentSelectedResultView(_ result: TransitResult) -> some View {
        switch calcVM.momentSelectedTab {
        case "wheel":
            ChartWheelView(data: ChartWheelData(transitResult: result))
        case "aspects":
            AspectTableView(aspects: result.aspects)
        case "transit_positions":
            PositionTableView(title: "行运位置", positions: result.transitPositions)
        case "natal_positions":
            PositionTableView(title: "本命位置", positions: result.natalPositions)
        case "diagnostics":
            DiagnosticsView(result: result)
        case "ai":
            AIAnalysisView(
                streamKey: "moment",
                analysis: aiVM.momentAnalysis,
                reasoning: aiVM.momentReasoning,
                isAnalyzing: aiVM.isAnalyzing,
                canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await analyzeMomentResult() }
            }
        default:
            ChartWheelView(data: ChartWheelData(transitResult: result))
        }
    }

    // MARK: - Scan Results Pane
    var scanResultsPane: some View {
        Group {
            if calcVM.scanResult != nil {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    ResultPaneToolbar(
                        selection: $calcVM.scanSelectedTab,
                        tabs: scanTabs,
                        moreTabs: scanMoreTabs,
                        currentTabTitle: scanTabTitle,
                        markdownProvider: { MarkdownExportBuilder.scan(calcVM.scanResult!) },
                        jsonProvider: { TextExportBuilder.json(calcVM.scanResult!) },
                        csvProvider: { TextExportBuilder.csv(calcVM.scanResult!) },
                        basename: "transit_scan"
                    )
                    scanSelectedResultView(calcVM.scanResult!)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(TS.Padding.resultContent)
            } else {
                EmptyStateView(title: "等待扫描", systemImage: "calendar.badge.clock", description: "选择窗口、行运体、目标点和相位后开始扫描。")
            }
        }
    }

    var scanTabs: [(id: String, title: String)] {
        [
            ("hits", "命中"), ("ai", "AI 分析"),
        ]
    }

    var scanMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断")]
    }

    var scanTabTitle: String {
        switch calcVM.scanSelectedTab {
        case "hits": return "命中"
        case "ai": return "AI 分析"
        case "diagnostics": return "诊断"
        default: return ""
        }
    }

    @ViewBuilder
    func scanSelectedResultView(_ result: ScanResult) -> some View {
        switch calcVM.scanSelectedTab {
        case "hits":
            ScanTableView(hits: result.hits)
        case "diagnostics":
            ScanDiagnosticsView(result: result)
        case "ai":
            AIAnalysisView(
                streamKey: "scan",
                analysis: aiVM.scanAnalysis,
                reasoning: aiVM.scanReasoning,
                isAnalyzing: aiVM.isAnalyzing,
                canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await analyzeScanResult() }
            }
        default:
            ScanTableView(hits: result.hits)
        }
    }

    // MARK: - Horary Results Pane
    var horaryResultsPane: some View {
        Group {
            if calcVM.horaryResult != nil {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    ResultPaneToolbar(
                        selection: $calcVM.horarySelectedTab,
                        tabs: horaryTabs,
                        moreTabs: horaryMoreTabs,
                        currentTabTitle: horaryTabTitle,
                        markdownProvider: { MarkdownExportBuilder.horary(calcVM.horaryResult!) },
                        jsonProvider: { TextExportBuilder.json(calcVM.horaryResult!) },
                        csvProvider: { TextExportBuilder.csv(calcVM.horaryResult!) },
                        basename: "horary_chart"
                    )
                    horarySelectedResultView(calcVM.horaryResult!)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(TS.Padding.resultContent)
            } else {
                EmptyStateView(title: "等待 Horary 起盘", systemImage: "questionmark.circle", description: "填写提问时间、地点和问题文本后开始起盘。")
            }
        }
    }

    var horaryTabs: [(id: String, title: String)] {
        [
            ("wheel", "星盘图"), ("overview", "问卜总览"), ("planets", "行星状态"), ("points", "点位/Lots"), ("houses", "宫位"),
            ("aspects", "相位/接纳"), ("judgement", "评分明细"), ("ai", "AI 分析"),
        ]
    }

    var horaryMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var horaryTabTitle: String {
        switch calcVM.horarySelectedTab {
        case "wheel": return "星盘图"
        case "overview": return "问卜总览"
        case "planets": return "行星状态"
        case "points": return "点位/Lots"
        case "houses": return "宫位"
        case "aspects": return "相位/接纳"
        case "judgement": return "评分明细"
        case "ai": return "AI 分析"
        case "diagnostics": return "诊断"
        case "json": return "JSON"
        default: return ""
        }
    }

    @ViewBuilder
    func horarySelectedResultView(_ result: HoraryResult) -> some View {
        switch calcVM.horarySelectedTab {
        case "wheel":
            ChartWheelView(data: ChartWheelData(horaryResult: result))
        case "overview":
            HoraryOverviewView(result: result)
        case "planets":
            ClassicalPlanetTableView(planets: result.planets)
        case "points":
            ClassicalPointsView(angles: result.angles, lots: result.lots, experimentalLots: nil)
        case "houses":
            ClassicalHouseTableView(houses: result.houses)
        case "aspects":
            ClassicalAspectReceptionView(aspects: result.aspects, receptions: result.receptions)
        case "judgement":
            ClassicalJudgementView(planets: result.planets)
        case "diagnostics":
            HoraryDiagnosticsView(result: result)
        case "ai":
            AIAnalysisView(
                streamKey: "horary",
                analysis: aiVM.horaryAnalysis,
                reasoning: aiVM.horaryReasoning,
                isAnalyzing: aiVM.isAnalyzing,
                canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await analyzeHoraryResult() }
            }
        case "json":
            RawJSONView(value: result)
        default:
            HoraryOverviewView(result: result)
        }
    }
}
