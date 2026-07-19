import SwiftUI

// MARK: - Relocation

struct RelocationResultPane: View {
    let result: RelocationResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { MarkdownExportBuilder.relocation(result) },
                jsonProvider: { TextExportBuilder.relocationJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "relocation"
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [
            ("biwheel", "双盘"),
            ("relocated_houses", "迁移宫位/角点"),
            ("overlays", "Overlays"),
            ("compare", "Compare"),
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
        case "biwheel":
            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                Text("同一 birth UTC：\(result.meta.birthUTC)")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
                Text("原地点 \(result.meta.birthPlace.name ?? "") → 新地点 \(result.meta.relocation.name ?? "")")
                    .font(TS.Font.label)
                HStack(alignment: .top, spacing: TS.Spacing.xl) {
                    PositionTableView(title: "本命行星（共享黄经）", positions: result.natalChart.planets)
                    PositionTableView(title: "迁移盘行星（宫位重算）", positions: result.relocatedChart.planets)
                }
                ChartWheelView(data: ChartWheelData(relocationChart: result.relocatedChart))
                    .frame(minHeight: 360)
            }
        case "relocated_houses":
            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                ClassicalPointsView(angles: result.relocatedChart.angles, lots: [], experimentalLots: nil)
                ClassicalHouseTableView(houses: result.relocatedChart.houses)
                Text(
                    "宫制 requested=\(result.meta.houseSystemRequested ?? "") "
                        + "effective=\(result.meta.houseSystemEffectiveRelocated ?? "")"
                )
                .font(TS.Font.label)
                .foregroundStyle(.secondary)
            }
        case "overlays":
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                Text("迁移角点落入本命宫").font(TS.Font.sectionTitle)
                overlayTable(result.relocatedAnglesInNatalHouses)
                Text("本命角点落入迁移宫").font(TS.Font.sectionTitle)
                overlayTable(result.natalAnglesInRelocatedHouses)
            }
        case "compare":
            Table(result.planetHouseChanges) {
                TableColumn("Body") { Text($0.name) }
                TableColumn("Natal") { Text("\($0.natalHouse)") }
                TableColumn("Relocated") { Text("\($0.relocatedHouse)") }
                TableColumn("Changed") { Text($0.changed ? "yes" : "no") }
            }
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            PositionTableView(title: "迁移盘行星", positions: result.relocatedChart.planets)
        }
    }

    private func overlayTable(_ rows: [AngleOverlayRow]) -> some View {
        Table(rows) {
            TableColumn("Angle") { Text($0.name ?? $0.angleID ?? "") }
            TableColumn("Lon") { Text(String(format: "%.4f", $0.longitude)).monospacedDigit() }
            TableColumn("House") { Text("\($0.house)") }
            TableColumn("From→To") { Text("\($0.sourceChart ?? "")→\($0.targetChart ?? "")") }
        }
    }
}

// MARK: - Cycles

struct ModernCyclesResultPane: View {
    let result: ModernCyclesResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { MarkdownExportBuilder.modernCycles(result) },
                jsonProvider: { TextExportBuilder.modernCyclesJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "modern_cycles"
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [("events", "周期事件"), ("contacts", "本命接触"), ("timing", "时间线源")]
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
        case "events":
            Table(result.events) {
                TableColumn("Type") { Text($0.cycleType) }
                TableColumn("Maximum UTC") { Text($0.maximumUTC).monospacedDigit() }
                TableColumn("Sep°") {
                    Text($0.separationDeg.map { String(format: "%.4f", $0) } ?? "—").monospacedDigit()
                }
                TableColumn("Eclipse") { Text($0.eclipseType ?? "—") }
                TableColumn("Visible") {
                    if let value = $0.visibleAtLocation {
                        Text(value ? "yes" : "no")
                    } else {
                        Text("—")
                    }
                }
            }
        case "contacts":
            let contacts = result.events.flatMap { event in
                (event.contacts ?? []).map { ($0, event) }
            }
            if contacts.isEmpty {
                EmptyStateView(
                    title: "无本命接触",
                    systemImage: "moon.stars",
                    description: "在请求中提供 birth + target_point_set 可计算接触；接触 exact_utc 与周期 maximum 相同。"
                )
            } else {
                Table(contacts.map { ContactRow(contact: $0.0, event: $0.1) }) {
                    TableColumn("Cycle") { Text($0.event.cycleType) }
                    TableColumn("Body") { Text($0.contact.bodyID) }
                    TableColumn("Aspect") { Text($0.contact.aspectName ?? $0.contact.aspectID ?? "") }
                    TableColumn("Exact UTC") { Text($0.contact.exactUTC).monospacedDigit() }
                }
            }
        case "timing":
            Table(result.timingEvents ?? []) {
                TableColumn("Source") { Text($0.sourceType ?? "") }
                TableColumn("Type") { Text($0.eventType ?? "") }
                TableColumn("Exact UTC") { Text($0.exactUTC ?? "").monospacedDigit() }
                TableColumn("ID") { Text($0.id) }
            }
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            EmptyStateView(title: "周期事件", systemImage: "moon.stars", description: "选择标签页查看结果。")
        }
    }

    private struct ContactRow: Identifiable {
        let contact: CycleContact
        let event: CycleEvent
        var id: String { "\(event.id)|\(contact.id)" }
    }
}

// MARK: - ACG / Local Space

struct AstrocartographyResultPane: View {
    let result: AstrocartographyResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { MarkdownExportBuilder.astrocartography(result) },
                jsonProvider: { TextExportBuilder.astrocartographyJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "astrocartography"
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [("lines", "ACG 线"), ("map_note", "地图说明")]
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
        case "lines":
            Table(result.lines) {
                TableColumn("Line") { Text($0.id) }
                TableColumn("Angle") { Text($0.angleKind) }
                TableColumn("Geometry") { Text($0.geometry ?? "") }
                TableColumn("Lon") {
                    Text($0.longitude.map { String(format: "%.4f", $0) } ?? "curve").monospacedDigit()
                }
                TableColumn("Samples") { Text("\($0.points?.count ?? 0)") }
            }
        case "map_note":
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text("MapKit 产品地图")
                    .font(TS.Font.sectionTitle)
                Text(
                    "计算已输出 MC/IC 子午线与 ASC/DSC 采样曲线（segments）。"
                        + " SwiftUI MapKit polyline 渲染可在后续 UI 迭代接入；"
                        + "当前交付保证 geometry + method_key + trace 可审计。"
                )
                .font(TS.Font.body)
                if let unverified = result.meta.unverified, !unverified.isEmpty {
                    Text("Unverified: \(unverified.joined(separator: ", "))")
                        .foregroundStyle(.orange)
                }
            }
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            EmptyStateView(title: "ACG", systemImage: "globe", description: "选择标签页。")
        }
    }
}

struct LocalSpaceResultPane: View {
    let result: LocalSpaceResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { MarkdownExportBuilder.localSpace(result) },
                jsonProvider: { TextExportBuilder.localSpaceJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "local_space"
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [("directions", "方位"), ("map_note", "地图说明")]
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
        case "directions":
            Table(result.directions) {
                TableColumn("Body") { Text($0.bodyName ?? $0.bodyID) }
                TableColumn("Azimuth") { Text(String(format: "%.4f°", $0.azimuthDeg)).monospacedDigit() }
                TableColumn("Altitude") {
                    Text($0.altitudeDeg.map { String(format: "%.4f°", $0) } ?? "—").monospacedDigit()
                }
                TableColumn("Method") { Text($0.methodKey ?? "") }
            }
        case "map_note":
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text("Local Space 大圆方向")
                    .font(TS.Font.sectionTitle)
                Text(
                    "方位角来自 swe.azalt(ECL2HOR)。great_circle_points 为显示用近似远点，"
                        + "非专业测地库；见 meta.unverified。"
                )
                if let unverified = result.meta.unverified, !unverified.isEmpty {
                    Text("Unverified: \(unverified.joined(separator: ", "))")
                        .foregroundStyle(.orange)
                }
            }
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            EmptyStateView(title: "Local Space", systemImage: "location.north.line", description: "选择标签页。")
        }
    }
}

// MARK: - Chart wheel helper

extension ChartWheelData {
    init(relocationChart chart: RelocationChartSnapshot) {
        var points: [WheelPoint] = []
        for planet in chart.planets {
            let signIndex = Int(floor(planet.longitude / 30.0)) % 12
            points.append(
                WheelPoint(
                    id: planet.bodyID,
                    name: planet.name,
                    shortLabel: planetShortLabels[planet.bodyID] ?? String(planet.name.prefix(1)),
                    longitude: planet.longitude,
                    house: planet.house ?? 0,
                    sign: planet.sign,
                    signIndex: signIndex,
                    degreeText: planet.degreeText,
                    element: elementForSign(index: signIndex),
                    type: .planet,
                    isTransit: false
                )
            )
        }
        for angle in chart.angles {
            let signIndex = Int(floor(angle.longitude / 30.0)) % 12
            points.append(
                WheelPoint(
                    id: angle.id,
                    name: angle.name,
                    shortLabel: angleShortLabels[angle.id] ?? String(angle.name.prefix(1)),
                    longitude: angle.longitude,
                    house: angle.house,
                    sign: angle.sign,
                    signIndex: signIndex,
                    degreeText: angle.degreeText,
                    element: elementForSign(index: signIndex),
                    type: .angle,
                    isTransit: false
                )
            )
        }
        let cusps = chart.houses.map(\.cuspLongitude)
        let axes = chart.angles.compactMap { angle -> Double? in
            ["ASC", "MC", "DSC", "IC"].contains(angle.id) ? angle.longitude : nil
        }
        self.points = points
        self.houseCusps = cusps.isEmpty ? (0..<12).map { Double($0 * 30) } : cusps
        self.axisLongitudes = axes
        self.aspects = []
        self.unresolvedAspectEndpoints = []
    }
}
