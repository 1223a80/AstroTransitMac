import SwiftUI

extension ContentView {
    var runSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if mode != .scan {
                Button {
                    Task { await runCurrentMode() }
                } label: {
                    Label(isRunning ? "计算中" : runButtonTitle, systemImage: isRunning ? "hourglass" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(runDisabled)
            }

            if let calculationProgress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: calculationProgress)
                    Text(calculationProgressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            if !asteroidPreparationMessage.isEmpty {
                Text(asteroidPreparationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    var runButtonTitle: String {
        switch mode {
        case .settings:
            if practiceMode == .classical { return "保存本命盘并古典排盘" }
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
        if isRunning {
            return true
        }

        switch mode {
        case .settings:
            if practiceMode == .classical {
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
            if let momentResult {
                VStack(alignment: .leading, spacing: 10) {
                    ResultPaneToolbar(
                        selection: $modernNatalSelectedTab,
                        tabRows: modernNatalTabRows,
                        moreTabs: modernNatalMoreTabs,
                        currentTabTitle: modernNatalTabTitle,
                        markdownProvider: { MarkdownExportBuilder.natal(momentResult) },
                        jsonProvider: { TextExportBuilder.natalJSON(momentResult) },
                        csvProvider: { TextExportBuilder.natalCSV(momentResult) },
                        basename: "natal_chart"
                    )
                    modernNatalSelectedResultView(momentResult)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(14)
            } else {
                EmptyStateView(title: "等待现代排盘", systemImage: "circle.grid.2x2", description: "填写出生设置并选择天体后开始排盘。")
            }
        }
    }

    var modernNatalTabRows: [[(id: String, title: String)]] {
        [
            [("wheel", "星盘图"), ("natal_positions", "本命位置"), ("natal_aspects", "本命相位"), ("ai", "AI 分析")],
        ]
    }

    var modernNatalMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断")]
    }

    var modernNatalTabTitle: String {
        switch modernNatalSelectedTab {
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
        switch modernNatalSelectedTab {
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
                analysis: momentAIAnalysis,
                isAnalyzing: isAnalyzingAI,
                canAnalyze: !llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            if let momentResult {
                VStack(alignment: .leading, spacing: 10) {
                    ResultPaneToolbar(
                        selection: $momentSelectedTab,
                        tabRows: momentTabRows,
                        moreTabs: momentMoreTabs,
                        currentTabTitle: momentTabTitle,
                        markdownProvider: { MarkdownExportBuilder.moment(momentResult) },
                        jsonProvider: { TextExportBuilder.json(momentResult) },
                        csvProvider: { TextExportBuilder.csv(momentResult) },
                        basename: "moment_chart"
                    )
                    momentSelectedResultView(momentResult)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(14)
            } else {
                EmptyStateView(title: "等待计算", systemImage: "chart.line.uptrend.xyaxis", description: "选择天体、相位和容许度后开始计算。")
            }
        }
    }

    var momentTabRows: [[(id: String, title: String)]] {
        [
            [("wheel", "星盘图"), ("aspects", "相位"), ("transit_positions", "行运位置"), ("natal_positions", "本命位置"), ("ai", "AI 分析")],
        ]
    }

    var momentMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断")]
    }

    var momentTabTitle: String {
        switch momentSelectedTab {
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
        switch momentSelectedTab {
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
                analysis: momentAIAnalysis,
                isAnalyzing: isAnalyzingAI,
                canAnalyze: !llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            if let scanResult {
                VStack(alignment: .leading, spacing: 10) {
                    ResultPaneToolbar(
                        selection: $scanSelectedTab,
                        tabRows: scanTabRows,
                        moreTabs: scanMoreTabs,
                        currentTabTitle: scanTabTitle,
                        markdownProvider: { MarkdownExportBuilder.scan(scanResult) },
                        jsonProvider: { TextExportBuilder.json(scanResult) },
                        csvProvider: { TextExportBuilder.csv(scanResult) },
                        basename: "transit_scan"
                    )
                    scanSelectedResultView(scanResult)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(14)
            } else {
                EmptyStateView(title: "等待扫描", systemImage: "calendar.badge.clock", description: "选择窗口、行运体、目标点和相位后开始扫描。")
            }
        }
    }

    var scanTabRows: [[(id: String, title: String)]] {
        [
            [("hits", "命中"), ("ai", "AI 分析")],
        ]
    }

    var scanMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断")]
    }

    var scanTabTitle: String {
        switch scanSelectedTab {
        case "hits": return "命中"
        case "ai": return "AI 分析"
        case "diagnostics": return "诊断"
        default: return ""
        }
    }

    @ViewBuilder
    func scanSelectedResultView(_ result: ScanResult) -> some View {
        switch scanSelectedTab {
        case "hits":
            ScanTableView(hits: result.hits)
        case "diagnostics":
            ScanDiagnosticsView(result: result)
        case "ai":
            AIAnalysisView(
                analysis: scanAIAnalysis,
                isAnalyzing: isAnalyzingAI,
                canAnalyze: !llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            if let horaryResult {
                VStack(alignment: .leading, spacing: 10) {
                    ResultPaneToolbar(
                        selection: $horarySelectedTab,
                        tabRows: horaryTabRows,
                        moreTabs: horaryMoreTabs,
                        currentTabTitle: horaryTabTitle,
                        markdownProvider: { MarkdownExportBuilder.horary(horaryResult) },
                        jsonProvider: { TextExportBuilder.json(horaryResult) },
                        csvProvider: { TextExportBuilder.csv(horaryResult) },
                        basename: "horary_chart"
                    )
                    horarySelectedResultView(horaryResult)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(14)
            } else {
                EmptyStateView(title: "等待 Horary 起盘", systemImage: "questionmark.circle", description: "填写提问时间、地点和问题文本后开始起盘。")
            }
        }
    }

    var horaryTabRows: [[(id: String, title: String)]] {
        [
            [("wheel", "星盘图"), ("overview", "问卜总览"), ("planets", "行星状态"), ("points", "点位/Lots"), ("houses", "宫位")],
            [("aspects", "相位/接纳"), ("judgement", "评分明细"), ("ai", "AI 分析")],
        ]
    }

    var horaryMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var horaryTabTitle: String {
        switch horarySelectedTab {
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
        switch horarySelectedTab {
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
                analysis: horaryAIAnalysis,
                isAnalyzing: isAnalyzingAI,
                canAnalyze: !llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            if isRunning {
                EmptyStateView(
                    title: "古典计算中",
                    systemImage: "hourglass",
                    description: calculationProgressText.isEmpty ? "正在调用后端计算。" : calculationProgressText
                )
            } else if let classicalResult {
                VStack(alignment: .leading, spacing: 10) {
                    ResultPaneToolbar(
                        selection: $classicalSelectedTab,
                        tabRows: classicalTabRows,
                        moreTabs: classicalMoreTabs,
                        currentTabTitle: classicalTabTitle,
                        markdownProvider: { MarkdownExportBuilder.classical(classicalResult) },
                        jsonProvider: { TextExportBuilder.json(classicalResult) },
                        csvProvider: { TextExportBuilder.csv(classicalResult) },
                        basename: "classical_chart",
                        classicalSectionPicker: { showClassicalExportSheet = true }
                    )

                    HStack(spacing: 8) {
                        Label("参考时间", systemImage: "clock")
                            .font(.caption)
                        DatePicker("", selection: $classicalReferenceDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .frame(width: 180)
                        Button("重算全盘") {
                            Task { await runClassicalTiming() }
                        }
                        .disabled(isRunning)
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)

                    classicalSelectedResultView(classicalResult)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(14)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("选择导出内容")
                .font(.headline)
                .padding(.top, 8)

            let sections = MarkdownExportBuilder.ExportSection.allCases
            let timingIDs = MarkdownExportBuilder.ExportSection.timingSectionIDs
            let diagnosticIDs: Set<MarkdownExportBuilder.ExportSection> = [.activeOverview, .warnings]

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    sectionToggleGroup(title: "本命", sections: sections.filter { !timingIDs.contains($0) && !diagnosticIDs.contains($0) })
                    sectionToggleGroup(title: "时间技法", sections: sections.filter(timingIDs.contains))
                    sectionToggleGroup(title: "诊断", sections: sections.filter(diagnosticIDs.contains))
                }
            }

            HStack {
                Button("取消") { showClassicalExportSheet = false }
                Spacer()
                Button("全选") { classicalExportSections = Set(sections) }
                Button("全不选") { classicalExportSections = [] }
                Button("导出 Markdown") {
                    let md = MarkdownExportBuilder.classical(classicalResult!, sections: classicalExportSections)
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

    private func sectionToggleGroup(title: String, sections: [MarkdownExportBuilder.ExportSection]) -> some View {
        GroupBox(label: Text(title).font(.subheadline.weight(.medium))) {
            ForEach(sections) { section in
                Toggle(isOn: Binding(
                    get: { classicalExportSections.contains(section) },
                    set: { if $0 { classicalExportSections.insert(section) } else { classicalExportSections.remove(section) } }
                )) {
                    Text(section.label).font(.caption)
                }
            }
        }
    }

    var classicalTabRows: [[(id: String, title: String)]] {
        guard let result = classicalResult else { return [] }
        let row1: [(String, String)] = [
            ("wheel", "星盘图"),
            ("planets", "行星状态"),
            ("points", "点位/Lots"),
            ("houses", "宫位"),
            ("aspects", "相位/接纳"),
            ("judgement", "评分明细"),
        ]
        var row2: [(String, String)] = []
        if result.antiscia?.isEmpty == false {
            row2.append(("antiscia", "映点"))
        }
        if result.primaryDirections?.isEmpty == false {
            row2.append(("primary", "主限法"))
        }
        if result.circumambulations?.isEmpty == false {
            row2.append(("circumambulations", "沿界推进"))
        }
        row2.append(("timing", "时间技法"))
        row2.append(("ai", "AI 分析"))
        return [row1, row2]
    }

    var classicalMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var classicalTabTitle: String {
        switch classicalSelectedTab {
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
    func classicalSelectedResultView(_ classicalResult: ClassicalResult) -> some View {
        switch classicalSelectedTab {
        case "wheel":
            ChartWheelView(data: ChartWheelData(classicalResult: classicalResult))
        case "points":
            ClassicalPointsView(angles: classicalResult.angles, lots: classicalResult.lots, experimentalLots: classicalResult.experimentalLots)
        case "houses":
            ClassicalHouseTableView(houses: classicalResult.houses)
        case "aspects":
            ClassicalAspectReceptionView(aspects: classicalResult.aspects, receptions: classicalResult.receptions)
        case "judgement":
            ClassicalJudgementView(planets: classicalResult.planets)
        case "antiscia":
            if let antiscia = classicalResult.antiscia, !antiscia.isEmpty {
                AntisciaView(antiscia: antiscia)
            } else {
                ClassicalPlanetTableView(planets: classicalResult.planets)
            }
        case "primary":
            if let pd = classicalResult.primaryDirections, !pd.isEmpty {
                PrimaryDirectionsView(directions: pd)
            } else {
                ClassicalPlanetTableView(planets: classicalResult.planets)
            }
        case "circumambulations":
            if let circ = classicalResult.circumambulations, !circ.isEmpty {
                CircumambulationsView(circumambulations: circ)
            } else {
                ClassicalPlanetTableView(planets: classicalResult.planets)
            }
        case "timing":
            ClassicalTimingView(
                timing: classicalResult.timing,
                planetaryReturns: classicalResult.planetaryReturns,
                circumambulations: classicalResult.circumambulations
            )
        case "diagnostics":
            ClassicalDiagnosticsView(result: classicalResult)
        case "ai":
            AIAnalysisView(
                analysis: classicalAIAnalysis,
                isAnalyzing: isAnalyzingAI,
                canAnalyze: !llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await analyzeClassicalResult() }
            }
        case "json":
            RawJSONView(value: classicalResult)
        default:
            ClassicalPlanetTableView(planets: classicalResult.planets)
        }
    }

    var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isShowingAppSettingsPage ? "程序设置" : mode.title)
                    .font(.title2.weight(.semibold))
                Text(isShowingAppSettingsPage ? "本地设置 / AI / 星历" : "\(practiceMode.title)占星 / pyswisseph backend / SwiftUI macOS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // removed: ProgressView() here triggers 60fps full-view layout
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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
            if let result = modernResultData, case .synastry(let r) = result {
                SynastryResultPane(result: r, selectedTab: $modernSelectedTab)
            } else {
                EmptyStateView(title: "等待 Synastry 计算", systemImage: "person.2", description: "填写两人出生信息后开始计算。")
            }
        }
    }

    var compositeResultsPane: some View {
        Group {
            if let result = modernResultData, case .composite(let r) = result {
                CompositeDavisonResultPane(title: "Composite", result: r, selectedTab: $modernSelectedTab)
            } else {
                EmptyStateView(title: "等待 Composite 计算", systemImage: "circle.hexagongrid", description: "填写两人出生信息后开始计算。")
            }
        }
    }

    var davisonResultsPane: some View {
        Group {
            if let result = modernResultData, case .davison(let r) = result {
                CompositeDavisonResultPane(title: "Davison", result: r, selectedTab: $modernSelectedTab)
            } else {
                EmptyStateView(title: "等待 Davison 计算", systemImage: "arrow.triangle.merge", description: "填写两人出生信息后开始计算。")
            }
        }
    }

    var progressionResultsPane: some View {
        Group {
            if let result = modernResultData, case .progression(let r) = result {
                ProgressionResultPane(result: r, selectedTab: $modernSelectedTab)
            } else {
                EmptyStateView(title: "等待次限推进计算", systemImage: "forward.fill", description: "填写出生和参考时间后开始计算。")
            }
        }
    }

    var solarArcResultsPane: some View {
        Group {
            if let result = modernResultData, case .solarArc(let r) = result {
                SolarArcResultPane(result: r, selectedTab: $modernSelectedTab)
            } else {
                EmptyStateView(title: "等待 Solar Arc 计算", systemImage: "sun.max", description: "填写出生和参考时间后开始计算。")
            }
        }
    }

    var harmonicResultsPane: some View {
        Group {
            if let result = modernResultData, case .harmonic(let r) = result {
                HarmonicResultPane(result: r, selectedTab: $modernSelectedTab)
            } else {
                EmptyStateView(title: "等待 Harmonic 计算", systemImage: "music.note.list", description: "选择调和阶数后开始计算。")
            }
        }
    }

    // MARK: - Rectify Results Pane

    var rectifyResultsPane: some View {
        VStack {
            if isRunning {
                EmptyStateView(
                    title: "生时矫正计算中",
                    systemImage: "hourglass",
                    description: calculationProgressText.isEmpty ? "正在调用后端计算 61 个候选点。" : calculationProgressText
                )
            } else if let response = rectifyResponse {
                PrimaryDirectionRectifierView(
                    response: response,
                    centerDate: natalDate,
                    timeZone: selectedTimeZone,
                    level2Response: $rectifyLevel2Response,
                    level3Response: $rectifyLevel3Response,
                    s1Index: $rectifyS1Index,
                    s2Index: $rectifyS2Index,
                    activeLevel: $rectifyActiveLevel,
                    level3ResponseID: $rectifyLevel3ResponseID,
                    onComputeLevel2: { offsetSec in
                        // Invalidate in-flight immediately, before debounce fires
                        rectifyLevel2Gen += 1
                        rectifyLevel3Gen += 1
                        Task { await runRectifyLevel2(offsetSeconds: offsetSec) }
                    },
                    onComputeLevel3: { offsetSec in
                        rectifyLevel3Gen += 1
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
}
