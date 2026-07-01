import SwiftUI

extension ContentView {
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

    func sectionToggleGroup(
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

    /// Single source of truth for classical tab ids and titles; the visible
    /// list filters out sections the current result doesn't contain.
    var classicalAllTabs: [(id: String, title: String)] {
        [
            ("wheel", "星盘图"),
            ("planets", "行星状态"),
            ("points", "点位/Lots"),
            ("houses", "宫位"),
            ("aspects", "相位/接纳"),
            ("judgement", "评分明细"),
            ("antiscia", "映点"),
            ("primary", "主限法"),
            ("circumambulations", "沿界推进"),
            ("timing", "时间技法"),
            ("ai", "AI 分析"),
        ]
    }

    var classicalTabs: [(id: String, title: String)] {
        guard let result = calcVM.classicalResult else { return [] }
        return classicalAllTabs.filter { tab in
            switch tab.id {
            case "antiscia": return result.antiscia?.isEmpty == false
            case "primary": return result.primaryDirections?.isEmpty == false
            case "circumambulations": return result.circumambulations?.isEmpty == false
            default: return true
            }
        }
    }

    var classicalMoreTabs: [(id: String, title: String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var classicalTabTitle: String {
        resultTabTitle(calcVM.classicalSelectedTab, in: classicalAllTabs, classicalMoreTabs)
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
                streamKey: "classical",
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
                Text((isShowingAppSettingsPage ? "本地设置 · AI · 星历" : "\(practiceMode.title)占星").uppercased())
                    .font(TS.Font.eyebrow)
                    .tracking(1.4)
                    .foregroundStyle(TS.SemanticColor.gold)
                Text(isShowingAppSettingsPage ? "程序设置" : mode.title)
                    .font(TS.Font.pageTitle)
                    .foregroundStyle(TS.SemanticColor.ink)
            }

            Spacer()
        }
        .padding(.horizontal, TS.Spacing.xxl)
        .padding(.vertical, TS.Spacing.lg)
        .background(TS.SemanticColor.paper)
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
}
