import SwiftUI

extension ContentView {
    var runSection: some View {
        Group {
            if calcVM.calculationProgress != nil || !calcVM.asteroidPreparationMessage.isEmpty {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    if calcVM.calculationProgress != nil {
                        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                            ProgressView(value: calcVM.calculationProgress)
                            Text(calcVM.calculationProgressText)
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
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
        }
    }

    var runButtonTitle: String {
        switch mode {
        case .settings:
            if practiceMode == .classical { return "古典排盘" }
            if practiceMode == .vedic { return "吠陀排盘" }
            switch modernSubMode {
            case .natal: return "现代排盘"
            case .synastry: return "计算合盘"
            case .composite: return "计算组合盘"
            case .davison: return "计算戴维森盘"
            case .progression: return "计算次限推进"
            case .solarArc: return "计算太阳弧"
            case .harmonic: return "计算调和盘"
            case .returnChart: return "计算返照盘"
            case .midpoint: return "计算中点"
            case .progressedComposite: return "计算推进组合盘"
            }
        case .horary:
            return "Horary 起盘"
        case .moment:
            return "计算时间点"
        case .scan:
            return isModernTimingWorkspace ? "计算综合时间线" : "扫描窗口"
        case .rectify:
            return "计算生时矫正"
        }
    }

    var runButtonHelp: String {
        if calcVM.isRunning {
            return canStopCurrentRun ? "停止当前计算" : "计算中"
        }
        switch mode {
        case .settings:
            if practiceMode == .classical { return "保存本命盘资料并计算古典排盘" }
            if practiceMode == .vedic { return "计算吠陀排盘" }
            if modernSubMode == .natal { return "保存本命盘资料并计算现代排盘" }
            return runButtonTitle
        default:
            return runButtonTitle
        }
    }

    var canStopCurrentRun: Bool {
        // Based on the *active task* (stoppability captured at start), not the
        // currently visible page — so mid-run mode switches do not flip stop UI.
        calcVM.isRunning && calcVM.currentRunTask != nil && calcVM.currentRunIsStoppable
    }

    var runDisabled: Bool {
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
            case .progressedComposite:
                let pointSet = progressedCompositePointSet()
                return parseDouble(birthLatitude) == nil
                    || parseDouble(birthLongitude) == nil
                    || parseDouble(modernPersonBLatitude) == nil
                    || parseDouble(modernPersonBLongitude) == nil
                    || (pointSet.bodyIDs.isEmpty && !pointSet.includeNodes && pointSet.customAsteroids.isEmpty)
            case .progression, .solarArc:
                return parseDouble(birthLatitude) == nil || parseDouble(birthLongitude) == nil
            case .returnChart:
                return parseDouble(birthLatitude) == nil || parseDouble(birthLongitude) == nil
                    || (modernReturnLocationSource == "custom" && (
                        parseDouble(modernReturnLocationLatitude) == nil
                        || parseDouble(modernReturnLocationLongitude) == nil
                        || modernReturnLocationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || modernReturnLocationTimezone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ))
            case .midpoint:
                return parseDouble(birthLatitude) == nil
                    || parseDouble(birthLongitude) == nil
                    || midpointSelectedPointIDs.count < 2
                    || midpointEffectiveFocusPointIDs.isEmpty
            }
        case .horary:
            return parseDouble(horaryLatitude) == nil
                || parseDouble(horaryLongitude) == nil
                || horaryQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .moment:
            return selectedNatalBodies.isEmpty || selectedTransitBodies.isEmpty || selectedAspectRequests(orb: globalOrb).isEmpty
        case .scan:
            if isModernTimingWorkspace {
                let techniques = timingTechniqueRequests()
                let pointSet = timingEffectiveTargetPointSet()
                let hasExactBirthCoordinates = modernTimingTargetChart != nil
                    || (parseDouble(birthLatitude) != nil && parseDouble(birthLongitude) != nil)
                return scanEndDate <= scanStartDate
                    || !hasExactBirthCoordinates
                    || TimeZone(identifier: timingDisplayTimezone.trimmingCharacters(in: .whitespacesAndNewlines)) == nil
                    || techniques.isEmpty
                    || techniques.contains(where: {
                        $0.movingBodyIDs.isEmpty
                            || $0.eventTypes.isEmpty
                            || ($0.eventTypes.contains("aspect") && $0.aspects.isEmpty)
                    })
                    || ModernTimingWorkEstimator.targetCount(for: pointSet) == 0
            }
            return scanTransitBodyIDs().isEmpty && parseAsteroids(customAsteroids).isEmpty
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
            if let message = calcVM.warningMessage {
                HStack(spacing: TS.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(message).textSelection(.enabled)
                    Spacer(minLength: 0)
                    Button { calcVM.warningMessage = nil } label: {
                        Image(systemName: "xmark")
                    }.buttonStyle(.plain)
                }
                .font(TS.Font.body)
                .foregroundStyle(TS.SemanticColor.warning)
                .padding(TS.Padding.cardInner)
                .background(TS.SemanticColor.warning.opacity(TS.Opacity.subtle))
            }
            if let message = calcVM.errorMessage {
                HStack(spacing: TS.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(message).textSelection(.enabled)
                    Spacer(minLength: 0)
                    Button { calcVM.errorMessage = nil } label: {
                        Image(systemName: "xmark")
                    }.buttonStyle(.plain)
                }
                .font(TS.Font.body)
                .foregroundStyle(TS.SemanticColor.error)
                .padding(TS.Padding.cardInner)
                .background(TS.SemanticColor.error.opacity(TS.Opacity.subtle))
            }
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
            case .progressedComposite: return AnyView(progressedCompositeResultsPane)
            case .progression: return AnyView(progressionResultsPane)
            case .solarArc: return AnyView(solarArcResultsPane)
            case .harmonic: return AnyView(harmonicResultsPane)
            case .returnChart: return AnyView(modernReturnResultsPane)
            case .midpoint: return AnyView(midpointResultsPane)
            }
        case .horary:
            return AnyView(horaryResultsPane)
        case .moment:
            return AnyView(momentResultsPane)
        case .scan:
            return isModernTimingWorkspace
                ? AnyView(modernTimingResultsPane)
                : AnyView(scanResultsPane)
        case .rectify:
            return AnyView(rectifyResultsPane)
        }
    }

    // MARK: - Modern Natal Results Pane
    var modernNatalResultsPane: some View {
        Group {
            if calcVM.modernNatalResult != nil {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    ResultPaneToolbar(
                        selection: $calcVM.modernNatalSelectedTab,
                        tabs: modernNatalTabs,
                        moreTabs: modernNatalMoreTabs,
                        currentTabTitle: modernNatalTabTitle,
                        markdownProvider: { MarkdownExportBuilder.natal(calcVM.modernNatalResult!) },
                        jsonProvider: { TextExportBuilder.natalJSON(calcVM.modernNatalResult!) },
                        csvProvider: { TextExportBuilder.natalCSV(calcVM.modernNatalResult!) },
                        basename: "natal_chart"
                    )
                    modernNatalSelectedResultView(calcVM.modernNatalResult!)
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
            ("wheel", "星盘图"), ("natal_positions", "本命位置"), ("natal_aspects", "本命相位"), ("structure", "结构"),
        ]
    }

    var modernNatalMoreTabs: [(id: String, title: String)] {
        [("declination", "赤纬"), ("fixed_stars", "固定星"), ("diagnostics", "诊断")]
    }

    var modernNatalTabTitle: String {
        resultTabTitle(calcVM.modernNatalSelectedTab, in: modernNatalTabs, modernNatalMoreTabs)
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
        case "structure":
            ModernStructureView(profile: result.chartProfile, patterns: result.patterns ?? [])
        case "declination":
            ModernDeclinationView(positions: result.natalPositions, aspects: result.declinationAspects ?? [])
        case "fixed_stars":
            ModernFixedStarsView(conjunctions: result.natalStarConjunctions ?? [])
        case "diagnostics":
            DiagnosticsView(result: result)
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
            ("wheel", "星盘图"), ("aspects", "相位"), ("transit_positions", "行运位置"), ("natal_positions", "本命位置"),
        ]
    }

    var momentMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断")]
    }

    var momentTabTitle: String {
        resultTabTitle(calcVM.momentSelectedTab, in: momentTabs, momentMoreTabs)
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
        default:
            ChartWheelView(data: ChartWheelData(transitResult: result))
        }
    }

    // MARK: - Scan Results Pane
    var modernTimingResultsPane: some View {
        Group {
            if let result = calcVM.modernTimingResult {
                ModernTimingResultPane(result: result, selectedTab: $calcVM.modernTimingSelectedTab)
            } else {
                EmptyStateView(
                    title: "等待综合时间线",
                    systemImage: "calendar.day.timeline.leading",
                    description: "配置三种技法、目标点和时间窗口后开始计算。"
                )
            }
        }
    }

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
            ("timeline", "时间轴"), ("hits", "命中表格"),
        ]
    }

    var scanMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断")]
    }

    var scanTabTitle: String {
        resultTabTitle(calcVM.scanSelectedTab, in: scanTabs, scanMoreTabs)
    }

    @ViewBuilder
    func scanSelectedResultView(_ result: ScanResult) -> some View {
        switch calcVM.scanSelectedTab {
        case "timeline":
            ScanTimelineView(result: result)
        case "hits":
            ScanTableView(hits: result.hits)
        case "diagnostics":
            ScanDiagnosticsView(result: result)
        default:
            ScanTableView(hits: result.hits)
        }
    }

    // MARK: - Horary Results Pane
    var horaryResultsPane: some View {
        Group {
            if calcVM.horaryResult != nil {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    HStack(spacing: TS.Spacing.md) {
                        Spacer(minLength: 0)
                        CopyMarkdownButton(title: "复制 Markdown", textProvider: { MarkdownExportBuilder.horary(calcVM.horaryResult!) })
                        ExportMenu(
                            markdownProvider: { MarkdownExportBuilder.horary(calcVM.horaryResult!) },
                            jsonProvider: { TextExportBuilder.json(calcVM.horaryResult!) },
                            csvProvider: { TextExportBuilder.csv(calcVM.horaryResult!) },
                            basename: "horary_chart"
                        )
                        .fixedSize()
                    }
                    HStack(alignment: .top, spacing: TS.Spacing.lg) {
                        VerticalSectionNav(
                            selection: $calcVM.horarySelectedTab,
                            sections: horaryTabs,
                            secondarySections: horaryMoreTabs
                        )
                        Rectangle()
                            .fill(TS.SemanticColor.line)
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                        horarySelectedResultView(calcVM.horaryResult!)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
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
            ("aspects", "相位/接纳"), ("judgement", "评分明细"),
        ]
    }

    var horaryMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var horaryTabTitle: String {
        resultTabTitle(calcVM.horarySelectedTab, in: horaryTabs, horaryMoreTabs)
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
            ClassicalPointsView(
                angles: result.angles,
                lots: result.lots.filter { $0.lotGroup != "experimental" },
                experimentalLots: result.lots.filter { $0.lotGroup == "experimental" }
            )
        case "houses":
            ClassicalHouseTableView(houses: result.houses)
        case "aspects":
            ClassicalAspectReceptionView(aspects: result.aspects, receptions: result.receptions)
        case "judgement":
            ClassicalJudgementView(planets: result.planets)
        case "diagnostics":
            HoraryDiagnosticsView(result: result)
        case "json":
            RawJSONView(value: result)
        default:
            HoraryOverviewView(result: result)
        }
    }
}
