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
            if practiceMode == .classical {
                switch ClassicalSettingsGate.route(workspace: classicalSettingsWorkspace) {
                case .natalChart:
                    return "古典排盘"
                case .expansion(let expansionMode):
                    return modernSubModeRunTitle(expansionMode)
                }
            }
            if practiceMode == .vedic { return "吠陀排盘" }
            return modernSubModeRunTitle(modernSubMode)
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

    /// Run button title for a modern / classical-expansion sub-mode.
    func modernSubModeRunTitle(_ subMode: ModernSubMode) -> String {
        ModernSubModeChrome.runButtonTitle(subMode)
    }

    var runButtonHelp: String {
        if calcVM.isRunning {
            return canStopCurrentRun ? "停止当前计算" : "计算中"
        }
        switch mode {
        case .settings:
            if practiceMode == .classical {
                switch ClassicalSettingsGate.route(workspace: classicalSettingsWorkspace) {
                case .natalChart:
                    return "保存本命盘资料并计算古典排盘"
                case .expansion:
                    return runButtonTitle
                }
            }
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
                switch ClassicalSettingsGate.route(workspace: classicalSettingsWorkspace) {
                case .natalChart:
                    return parseDouble(birthLatitude) == nil || parseDouble(birthLongitude) == nil
                case .expansion(let expansionMode):
                    return isModernSubModeRunDisabled(expansionMode)
                }
            }
            if practiceMode == .vedic {
                return parseDouble(birthLatitude) == nil || parseDouble(birthLongitude) == nil
            }
            return isModernSubModeRunDisabled(modernSubMode)
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

    /// Disable rules for modern / classical-expansion sub-modes (shared by modern rail + classical workspace).
    func isModernSubModeRunDisabled(_ subMode: ModernSubMode) -> Bool {
        switch subMode {
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
        case .relocation:
            return parseDouble(birthLatitude) == nil
                || parseDouble(birthLongitude) == nil
                || parseDouble(relocationLatitude) == nil
                || parseDouble(relocationLongitude) == nil
                || relocationPlaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || relocationTimezone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .modernCycles:
            return cyclesSelectedTypes.isEmpty
        case .declinationTiming:
            return parseDouble(birthLatitude) == nil
                || parseDouble(birthLongitude) == nil
                || declinationMovingBodies.isEmpty
                || declinationEventTypes.isEmpty
        case .retrogradeCycles:
            return retrogradeBodies.isEmpty
        case .classicalVisibility:
            return parseDouble(birthLatitude) == nil
                || parseDouble(birthLongitude) == nil
                || visibilityInclude.isEmpty
        case .planetarySynodic:
            return synodicBodyA == synodicBodyB
        case .classicalDerivatives, .timeLordsExtended, .methodFamilies, .primaryDirectionsAudit,
             .distributionsPd, .prenatalParans, .orbitalDial, .mundaneElectional,
             .hellenisticConditionAudit, .draconicHeliocentric:
            return parseDouble(birthLatitude) == nil || parseDouble(birthLongitude) == nil
        case .astrocartography:
            return mapBodies.isEmpty
        case .localSpace:
            let lat = localSpaceLatitude.isEmpty ? birthLatitude : localSpaceLatitude
            let lon = localSpaceLongitude.isEmpty ? birthLongitude : localSpaceLongitude
            return parseDouble(lat) == nil || parseDouble(lon) == nil || mapBodies.isEmpty
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
            if practiceMode == .classical {
                switch ClassicalSettingsGate.route(workspace: classicalSettingsWorkspace) {
                case .natalChart:
                    return AnyView(classicalResultsPane)
                case .expansion(let expansionMode):
                    return AnyView(classicalExpansionResultsWrapper(expansionMode))
                }
            }
            if practiceMode == .vedic { return AnyView(vedicResultsPane) }
            return modernSubModeResultsPane(modernSubMode)
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

    /// Classical expansion results: shared modern pane + D6 section/merge export bar.
    @ViewBuilder
    func classicalExpansionResultsWrapper(_ expansionMode: ModernSubMode) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ClassicalExpansionExportBar(
                mode: expansionMode,
                hasCurrentResult: calcVM.modernResultData?.classicalExpansionMode == expansionMode
                    || calcVM.classicalExpansionResults[expansionMode] != nil,
                cachedCount: calcVM.classicalExpansionResults.count,
                onExport: { showExpansionExportSheet = true }
            )
            .padding(.horizontal, TS.Padding.resultContent)
            .padding(.top, TS.Spacing.md)
            modernSubModeResultsPane(expansionMode)
        }
        .sheet(isPresented: $showExpansionExportSheet) {
            ExpansionExportSheet(
                mode: expansionMode,
                currentData: calcVM.classicalExpansionResults[expansionMode] ?? calcVM.modernResultData,
                classicalExpansionResults: calcVM.classicalExpansionResults,
                onDismiss: { showExpansionExportSheet = false }
            )
        }
    }

    /// Results pane for a modern / classical-expansion sub-mode (shared gate).
    func modernSubModeResultsPane(_ subMode: ModernSubMode) -> AnyView {
        switch subMode {
        case .natal: return AnyView(modernNatalResultsPane)
        case .synastry: return AnyView(synastryResultsPane)
        case .composite: return AnyView(compositeResultsPane)
        case .davison: return AnyView(davisonResultsPane)
        case .progressedComposite: return AnyView(progressedCompositeResultsPane)
        case .relocation: return AnyView(relocationResultsPane)
        case .modernCycles: return AnyView(modernCyclesResultsPane)
        case .declinationTiming: return AnyView(declinationTimingResultsPane)
        case .retrogradeCycles: return AnyView(retrogradeCyclesResultsPane)
        case .classicalVisibility: return AnyView(classicalVisibilityResultsPane)
        case .planetarySynodic: return AnyView(planetarySynodicResultsPane)
        case .hellenisticConditionAudit: return AnyView(hellenisticConditionAuditResultsPane)
        case .draconicHeliocentric: return AnyView(draconicHeliocentricResultsPane)
        case .classicalDerivatives: return AnyView(classicalDerivativesResultsPane)
        case .timeLordsExtended: return AnyView(timeLordsExtendedResultsPane)
        case .methodFamilies: return AnyView(methodFamiliesResultsPane)
        case .primaryDirectionsAudit: return AnyView(primaryDirectionsAuditResultsPane)
        case .distributionsPd: return AnyView(distributionsPdResultsPane)
        case .prenatalParans: return AnyView(prenatalParansResultsPane)
        case .orbitalDial: return AnyView(orbitalDialResultsPane)
        case .mundaneElectional: return AnyView(mundaneElectionalResultsPane)
        case .astrocartography: return AnyView(astrocartographyResultsPane)
        case .localSpace: return AnyView(localSpaceResultsPane)
        case .progression: return AnyView(progressionResultsPane)
        case .solarArc: return AnyView(solarArcResultsPane)
        case .harmonic: return AnyView(harmonicResultsPane)
        case .returnChart: return AnyView(modernReturnResultsPane)
        case .midpoint: return AnyView(midpointResultsPane)
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
                        CopyMarkdownButton(
                            title: "复制 Markdown",
                            textProvider: {
                                MarkdownExportBuilder.horary(
                                    calcVM.horaryResult!,
                                    prompt: appState.aiPromptHorary
                                )
                            }
                        )
                        ExportMenu(
                            markdownProvider: {
                                MarkdownExportBuilder.horary(
                                    calcVM.horaryResult!,
                                    prompt: appState.aiPromptHorary
                                )
                            },
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
            ("wheel", "星盘图"),
            ("overview", "数据总览"),
            ("planets", "天体/偶然"),
            ("points", "角点/Lots"),
            ("houses", "宫位"),
            ("aspects", "相位候选"),
            ("receptions", "接纳"),
            ("judgement", "尊贵归属"),
            ("moon", "月亮/VOC"),
            ("events", "事件/图"),
        ]
    }

    var horaryMoreTabs: [(id: String, title: String)] {
        [
            ("hours", "行星时"),
            ("considerations", "判断前事实"),
            ("declination", "赤纬"),
            ("antiscia", "Antiscia"),
            ("stars", "固定星"),
            ("visibility", "可见性"),
            ("diagnostics", "校验"),
            ("json", "JSON"),
        ]
    }

    var horaryTabTitle: String {
        resultTabTitle(calcVM.horarySelectedTab, in: horaryTabs, horaryMoreTabs)
    }

    @ViewBuilder
    func horarySelectedResultView(_ result: HoraryDataPacket) -> some View {
        switch calcVM.horarySelectedTab {
        case "wheel":
            ChartWheelView(data: ChartWheelData(horaryResult: result))
        case "overview":
            HoraryOverviewView(result: result)
        case "planets":
            HoraryBodiesTableView(bodies: result.bodies)
        case "points":
            HoraryLotsDataView(lots: result.lots, angles: result.angles.points)
        case "houses":
            HoraryHousesDataView(houses: result.houses)
        case "aspects":
            HoraryAspectsDataView(
                aspects: result.aspectCandidates ?? result.aspects,
                receptions: result.receptions
            )
        case "receptions":
            HoraryAspectsDataView(aspects: [], receptions: result.receptions)
        case "judgement":
            HoraryDignitiesView(dignities: result.dignities)
        case "moon":
            HoraryMoonDataView(moon: result.moon)
        case "events":
            HoraryEventsTimelineView(result: result)
        case "hours":
            HoraryJSONBlockView(title: "Planetary Day / Hour", value: result.planetaryDayHour)
        case "considerations":
            HoraryJSONBlockView(
                title: "Considerations Evidence",
                value: result.considerationsEvidence.map { .array($0) }
            )
        case "declination":
            HoraryJSONBlockView(
                title: "Declination (parallels / contacts / moon sequence)",
                value: result.optionalModules.flatMap { mods in
                    guard case .object(let o) = mods else { return mods }
                    var sub: [String: HoraryV2JSONValue] = [:]
                    for k in ["declination_parallels", "declination_contacts", "declination_moon_sequence"] {
                        if let v = o[k] { sub[k] = v }
                    }
                    return .object(sub)
                }
            )
        case "antiscia":
            HoraryJSONBlockView(
                title: "Antiscia (positions + contacts)",
                value: result.optionalModules.flatMap { mods in
                    guard case .object(let o) = mods else { return mods }
                    var sub: [String: HoraryV2JSONValue] = [:]
                    for k in ["antiscia", "antiscia_contacts"] {
                        if let v = o[k] { sub[k] = v }
                    }
                    return .object(sub)
                }
            )
        case "stars":
            HoraryJSONBlockView(
                title: "Fixed Stars",
                value: result.optionalModules.flatMap { mods in
                    guard case .object(let o) = mods else { return mods }
                    if let stars = o["fixed_stars"] { return stars }
                    return .null
                }
            )
        case "visibility":
            HoraryVisibilityTableView(rows: result.visibility)
        case "diagnostics":
            HoraryDiagnosticsView(result: result)
        case "json":
            RawJSONView(value: result)
        default:
            HoraryOverviewView(result: result)
        }
    }
}
