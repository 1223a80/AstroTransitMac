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

    // MARK: - Classical Results Pane
    var classicalResultsPane: some View {
        Group {
            if calcVM.isRunning {
                EmptyStateView(
                    title: "古典计算中",
                    systemImage: "hourglass",
                    description: calcVM.calculationProgressText.isEmpty ? "正在调用后端计算。" : calcVM.calculationProgressText
                )
            } else if calcVM.classicalResult != nil {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    ResultPaneToolbar(
                        selection: $calcVM.classicalSelectedTab,
                        tabs: classicalTabs,
                        moreTabs: classicalMoreTabs,
                        currentTabTitle: classicalTabTitle,
                        markdownProvider: { MarkdownExportBuilder.classical(calcVM.classicalResult!) },
                        jsonProvider: { TextExportBuilder.json(calcVM.classicalResult!) },
                        csvProvider: { TextExportBuilder.csv(calcVM.classicalResult!) },
                        basename: "classical_chart",
                        classicalSectionPicker: { showClassicalExportSheet = true }
                    )

                    HStack(spacing: TS.Spacing.md) {
                        Label("参考时间", systemImage: "clock")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $classicalReferenceDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .frame(width: 180)
                        Button("重算全盘") {
                            Task { await runClassicalTiming() }
                        }
                        .disabled(calcVM.isRunning)
                        .font(TS.Font.label)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, TS.Spacing.sm)

                    classicalSelectedResultView(calcVM.classicalResult!)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(TS.Padding.resultContent)
                .sheet(isPresented: $showClassicalExportSheet) {
                    classicalExportSheet
                }
            } else {
                EmptyStateView(title: "等待古典排盘", systemImage: "circle.grid.cross", description: "填写出生设置后输出结构化古典数据。")
            }
        }
    }

    @ViewBuilder
    private var classicalExportSheet: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("选择导出内容")
                .font(TS.Font.sectionTitle)
                .padding(.top, 8)

            let sections = MarkdownExportBuilder.ExportSection.classicalSectionIDs
            let timingIDs = MarkdownExportBuilder.ExportSection.timingSectionIDs
            let diagnosticIDs: Set<MarkdownExportBuilder.ExportSection> = [.activeOverview, .warnings]
            let natalSections = sections.filter { !timingIDs.contains($0) && !diagnosticIDs.contains($0) }.sorted { $0.label < $1.label }
            let timingSections = sections.filter(timingIDs.contains).sorted { $0.label < $1.label }
            let diagSections = sections.filter(diagnosticIDs.contains).sorted { $0.label < $1.label }

            ScrollView {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    sectionToggleGroup(
                        title: "本命",
                        sections: natalSections,
                        allSections: Set(natalSections),
                        selection: $classicalExportSections
                    )
                    sectionToggleGroup(
                        title: "时间技法",
                        sections: timingSections,
                        allSections: Set(timingSections),
                        selection: $classicalExportSections
                    )
                    sectionToggleGroup(
                        title: "诊断",
                        sections: diagSections,
                        allSections: Set(diagSections),
                        selection: $classicalExportSections
                    )
                }
            }

            HStack {
                Button("取消") { showClassicalExportSheet = false }
                Spacer()
                Button("全选") { classicalExportSections = Set(sections) }
                Button("全不选") { classicalExportSections = [] }
                Button("导出 Markdown") {
                    let md = MarkdownExportBuilder.classical(calcVM.classicalResult!, sections: classicalExportSections)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(md, forType: .string)
                    showClassicalExportSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(classicalExportSections.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 400)
    }

    private func sectionToggleGroup(
        title: String,
        sections: [MarkdownExportBuilder.ExportSection],
        allSections: Set<MarkdownExportBuilder.ExportSection>,
        selection: Binding<Set<MarkdownExportBuilder.ExportSection>>
    ) -> some View {
        let allSelected = allSections.isSubset(of: selection.wrappedValue)
        let noneSelected = selection.wrappedValue.intersection(allSections).isEmpty

        return VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Toggle(isOn: Binding(
                get: { allSelected },
                set: { newValue in
                    if newValue {
                        selection.wrappedValue.formUnion(allSections)
                    } else {
                        selection.wrappedValue.subtract(allSections)
                    }
                }
            )) {
                HStack(spacing: TS.Spacing.sm) {
                    Text(title)
                        .font(TS.Font.sectionTitle)
                    if noneSelected {
                        Text("（全不选）")
                            .font(TS.Font.detail)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .toggleStyle(.checkbox)

            Divider()

            ForEach(sections) { section in
                Toggle(isOn: Binding(
                    get: { selection.wrappedValue.contains(section) },
                    set: { if $0 { selection.wrappedValue.insert(section) } else { selection.wrappedValue.remove(section) } }
                )) {
                    Text(section.label).font(TS.Font.label)
                }
                .toggleStyle(.checkbox)
                .padding(.leading, 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
    }

    var classicalTabs: [(id: String, title: String)] {
        guard let result = calcVM.classicalResult else { return [] }
        var tabs: [(String, String)] = [
            ("wheel", "星盘图"),
            ("planets", "行星状态"),
            ("points", "点位/Lots"),
            ("houses", "宫位"),
            ("aspects", "相位/接纳"),
            ("judgement", "评分明细"),
        ]
        if result.antiscia?.isEmpty == false {
            tabs.append(("antiscia", "映点"))
        }
        if result.primaryDirections?.isEmpty == false {
            tabs.append(("primary", "主限法"))
        }
        if result.circumambulations?.isEmpty == false {
            tabs.append(("circumambulations", "沿界推进"))
        }
        tabs.append(("timing", "时间技法"))
        tabs.append(("ai", "AI 分析"))
        return tabs
    }

    var classicalMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var classicalTabTitle: String {
        switch calcVM.classicalSelectedTab {
        case "wheel": return "星盘图"
        case "planets": return "行星状态"
        case "points": return "点位/Lots"
        case "houses": return "宫位"
        case "aspects": return "相位/接纳"
        case "judgement": return "评分明细"
        case "antiscia": return "映点"
        case "primary": return "主限法"
        case "circumambulations": return "沿界推进"
        case "timing": return "时间技法"
        case "diagnostics": return "诊断"
        case "ai": return "AI 分析"
        case "json": return "JSON"
        default: return ""
        }
    }

    @ViewBuilder
    func classicalSelectedResultView(_ result: ClassicalResult) -> some View {
        switch calcVM.classicalSelectedTab {
        case "wheel":
            ChartWheelView(data: ChartWheelData(classicalResult: result))
        case "points":
            ClassicalPointsView(angles: result.angles, lots: result.lots, experimentalLots: result.experimentalLots)
        case "houses":
            ClassicalHouseTableView(houses: result.houses)
        case "aspects":
            ClassicalAspectReceptionView(aspects: result.aspects, receptions: result.receptions)
        case "judgement":
            ClassicalJudgementView(planets: result.planets)
        case "antiscia":
            if let antiscia = result.antiscia, !antiscia.isEmpty {
                AntisciaView(antiscia: antiscia)
            } else {
                ClassicalPlanetTableView(planets: result.planets)
            }
        case "primary":
            if let pd = result.primaryDirections, !pd.isEmpty {
                PrimaryDirectionsView(directions: pd)
            } else {
                ClassicalPlanetTableView(planets: result.planets)
            }
        case "circumambulations":
            if let circ = result.circumambulations, !circ.isEmpty {
                CircumambulationsView(circumambulations: circ)
            } else {
                ClassicalPlanetTableView(planets: result.planets)
            }
        case "timing":
            ClassicalTimingView(
                timing: result.timing,
                planetaryReturns: result.planetaryReturns,
                circumambulations: result.circumambulations,
                birthdayTransition: result.birthdayTransition,
                activatedLordFocus: result.activatedLordFocus
            )
        case "diagnostics":
            ClassicalDiagnosticsView(result: result)
        case "ai":
            AIAnalysisView(
                analysis: aiVM.classicalAnalysis,
                reasoning: aiVM.classicalReasoning,
                isAnalyzing: aiVM.isAnalyzing,
                canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await analyzeClassicalResult() }
            }
        case "json":
            RawJSONView(value: result)
        default:
            ClassicalPlanetTableView(planets: result.planets)
        }
    }

    var header: some View {
        HStack(spacing: TS.Spacing.lg) {
            VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                Text(isShowingAppSettingsPage ? "程序设置" : mode.title)
                    .font(TS.Font.pageTitle)
                Text(isShowingAppSettingsPage ? "本地设置 · AI · 星历" : "\(practiceMode.title)占星")
                    .font(TS.Font.label)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, TS.Spacing.xxl)
        .padding(.vertical, TS.Spacing.lg)
    }

    func toggleBinding(for id: String, in selection: Binding<Set<String>>) -> Binding<Bool> {
        Binding(
            get: { selection.wrappedValue.contains(id) },
            set: { isSelected in
                if isSelected {
                    selection.wrappedValue.insert(id)
                } else {
                    selection.wrappedValue.remove(id)
                }
            }
        )
    }

    func natalAspects(from result: TransitResult) -> [AspectHit] {
        var seen = Set<String>()
        return result.aspects.filter { aspect in
            guard aspect.transitBodyID != aspect.natalBodyID else {
                return false
            }
            let pair = [aspect.transitBodyID, aspect.natalBodyID].sorted().joined(separator: "::")
            let key = "\(pair)::\(aspect.aspectID)"
            guard !seen.contains(key) else {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    // MARK: - Modern Sub-Mode Result Panes

    var synastryResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .synastry(let r) = result {
                SynastryResultPane(
                    result: r,
                    selectedTab: $calcVM.modernSelectedTab,
                    analysis: aiVM.modernAnalysisByMode["synastry", default: ""],
                    reasoning: aiVM.modernReasoningByMode["synastry", default: ""],
                    isAnalyzing: aiVM.isAnalyzing,
                    canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await analyzeModernResult(modeKey: "synastry", title: "Synastry 关系分析", markdown: MarkdownModernExportBuilder.synastry(r)) }
                }
            } else {
                EmptyStateView(title: "等待 Synastry 计算", systemImage: "person.2", description: "填写两人出生信息后开始计算。")
            }
        }
    }

    var compositeResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .composite(let r) = result {
                CompositeDavisonResultPane(
                    title: "Composite",
                    result: r,
                    selectedTab: $calcVM.modernSelectedTab,
                    analysis: aiVM.modernAnalysisByMode["composite", default: ""],
                    reasoning: aiVM.modernReasoningByMode["composite", default: ""],
                    isAnalyzing: aiVM.isAnalyzing,
                    canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await analyzeModernResult(modeKey: "composite", title: "Composite 关系盘分析", markdown: MarkdownModernExportBuilder.compositeOrDavison(title: "Composite", result: r)) }
                }
            } else {
                EmptyStateView(title: "等待 Composite 计算", systemImage: "circle.hexagongrid", description: "填写两人出生信息后开始计算。")
            }
        }
    }

    var davisonResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .davison(let r) = result {
                CompositeDavisonResultPane(
                    title: "Davison",
                    result: r,
                    selectedTab: $calcVM.modernSelectedTab,
                    analysis: aiVM.modernAnalysisByMode["davison", default: ""],
                    reasoning: aiVM.modernReasoningByMode["davison", default: ""],
                    isAnalyzing: aiVM.isAnalyzing,
                    canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await analyzeModernResult(modeKey: "davison", title: "Davison 关系盘分析", markdown: MarkdownModernExportBuilder.compositeOrDavison(title: "Davison", result: r)) }
                }
            } else {
                EmptyStateView(title: "等待 Davison 计算", systemImage: "arrow.triangle.merge", description: "填写两人出生信息后开始计算。")
            }
        }
    }

    var progressionResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .progression(let r) = result {
                ProgressionResultPane(
                    result: r,
                    selectedTab: $calcVM.modernSelectedTab,
                    analysis: aiVM.modernAnalysisByMode["progression", default: ""],
                    reasoning: aiVM.modernReasoningByMode["progression", default: ""],
                    isAnalyzing: aiVM.isAnalyzing,
                    canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await analyzeModernResult(modeKey: "progression", title: "次限推进盘分析", markdown: MarkdownModernExportBuilder.progression(r)) }
                }
            } else {
                EmptyStateView(title: "等待次限推进计算", systemImage: "forward.fill", description: "填写出生和参考时间后开始计算。")
            }
        }
    }

    var solarArcResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .solarArc(let r) = result {
                SolarArcResultPane(
                    result: r,
                    selectedTab: $calcVM.modernSelectedTab,
                    analysis: aiVM.modernAnalysisByMode["solar_arc", default: ""],
                    reasoning: aiVM.modernReasoningByMode["solar_arc", default: ""],
                    isAnalyzing: aiVM.isAnalyzing,
                    canAnalyze: !appState.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await analyzeModernResult(modeKey: "solar_arc", title: "Solar Arc 盘分析", markdown: MarkdownModernExportBuilder.solarArc(r)) }
                }
            } else {
                EmptyStateView(title: "等待 Solar Arc 计算", systemImage: "sun.max", description: "填写出生和参考时间后开始计算。")
            }
        }
    }

    var harmonicResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .harmonic(let r) = result {
                HarmonicResultPane(result: r, selectedTab: $calcVM.modernSelectedTab)
            } else {
                EmptyStateView(title: "等待 Harmonic 计算", systemImage: "music.note.list", description: "选择调和阶数后开始计算。")
            }
        }
    }

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
                        tabs: [
                            (id: "overview", title: "综览"),
                            (id: "panchanga", title: "Pañcāṅga"),
                            (id: "dasa", title: "Daśā"),
                            (id: "shadbala", title: "Ṣaḍbala"),
                            (id: "yoga", title: "Yōga"),
                            (id: "navamsa", title: "Navāṃśa"),
                            (id: "varga", title: "Varga"),
                            (id: "jaimini", title: "Jaimini"),
                            (id: "ashtakavarga", title: "Aṣṭakavarga"),
                            (id: "relationships", title: "关系"),
                        ],
                        moreTabs: [
                            (id: "moon_chart", title: "Moon Chart"),
                            (id: "bhava", title: "Bhava"),
                            (id: "upagrahas", title: "副行星"),
                            (id: "special_lagnas", title: "特殊 Lagna"),
                            (id: "ai", title: "AI 分析"),
                            (id: "diagnostics", title: "诊断"),
                            (id: "json", title: "JSON"),
                        ],
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

    var vedicTabTitle: String {
        switch calcVM.vedicSelectedTab {
        case "overview": return "综览"
        case "panchanga": return "Pañcāṅga"
        case "dasa": return "Daśā"
        case "shadbala": return "Ṣaḍbala"
        case "yoga": return "Yōga"
        case "navamsa": return "Navāṃśa"
        case "varga": return "分割图"
        case "jaimini": return "Jaimini"
        case "ashtakavarga": return "Aṣṭakavarga"
        case "relationships": return "行星关系"
        case "moon_chart": return "Moon Chart"
        case "bhava": return "Bhava Chart"
        case "upagrahas": return "副行星"
        case "special_lagnas": return "特殊 Lagna"
        default: return ""
        }
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
