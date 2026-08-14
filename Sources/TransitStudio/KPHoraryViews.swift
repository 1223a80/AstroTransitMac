import SwiftUI

extension ContentView {
    var kpHoraryResultsPane: some View {
        Group {
            if let result = calcVM.kpHoraryResult {
                KPHoraryResultPane(result: result, selectedTab: $calcVM.kpHorarySelectedTab)
            } else {
                EmptyStateView(
                    title: "等待 KP 起盘",
                    systemImage: "number.circle",
                    description: "选择 1–249 数字、焦点宫位，填写提问时刻、地点和问题后开始起盘。"
                )
            }
        }
    }
}

struct KPHoraryResultPane: View {
    let result: KPHoraryResult
    @Binding var selectedTab: String

    static let tabs: [(id: String, title: String)] = [
        ("overview", "数字总览"),
        ("planets", "行星层级"),
        ("houses", "宫头层级"),
        ("planet_significators", "行星征象"),
        ("house_significators", "宫位征象"),
        ("focus_house", "焦点宫"),
    ]

    static let moreTabs: [(id: String, title: String)] = [
        ("diagnostics", "诊断"),
        ("json", "JSON"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: Self.tabs,
                moreTabs: Self.moreTabs,
                currentTabTitle: resultTabTitle(selectedTab, in: Self.tabs, Self.moreTabs),
                markdownProvider: { MarkdownExportBuilder.kpHorary(result) },
                jsonProvider: { TextExportBuilder.json(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "kp_horary_\(result.question.horaryNumber)"
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    @ViewBuilder
    private var selectedResultView: some View {
        switch selectedTab {
        case "overview":
            KPHoraryOverviewView(result: result)
        case "planets":
            KPPlanetTableView(planets: result.planets)
        case "houses":
            KPHouseTableView(houses: result.houses)
        case "planet_significators":
            KPPlanetSignificatorsView(rows: result.planetSignificators)
        case "house_significators":
            KPHouseSignificatorsView(rows: result.houseSignificators)
        case "focus_house":
            KPFocusHouseView(row: result.focusHouse)
        case "diagnostics":
            KPHoraryDiagnosticsView(result: result)
        case "json":
            RawJSONView(value: result)
        default:
            KPHoraryOverviewView(result: result)
        }
    }
}

struct KPHoraryOverviewView: View {
    let result: KPHoraryResult

    private let columns = [GridItem(.adaptive(minimum: 190), spacing: TS.Spacing.md)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                HStack(alignment: .top, spacing: TS.Spacing.xl) {
                    VStack(spacing: TS.Spacing.xs) {
                        Text("KP")
                            .font(TS.Font.label)
                            .foregroundStyle(TS.SemanticColor.inkFaint)
                        Text("\(result.question.horaryNumber)")
                            .font(.system(size: 44, weight: .semibold, design: .serif))
                            .foregroundStyle(TS.SemanticColor.goldDeep)
                            .monospacedDigit()
                        Text("焦点 · 第 \(result.question.focusHouse) 宫")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 130)
                    .padding(TS.Padding.cardInner)
                    .background(TS.SemanticColor.goldSoft, in: RoundedRectangle(cornerRadius: TS.Radius.card))

                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        Text(result.question.text)
                            .font(TS.Font.sectionTitle)
                            .textSelection(.enabled)
                        Text("\(result.question.placeName) · \(result.timeAndLocation.questionLocal)")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Divider()
                        KPPositionSummary(position: result.horaryNumber)
                        Text(String(
                            format: "数字区间 %.9f° – %.9f°",
                            result.horaryNumber.intervalStartLongitude,
                            result.horaryNumber.intervalEndLongitude
                        ))
                        .font(TS.Font.monoSmall)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(TS.Padding.cardInner)
                    .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.card))
                }

                Text("Ruling Planets · 原始来源")
                    .font(TS.Font.sectionTitle)
                LazyVGrid(columns: columns, alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(result.rulingPlanets) { row in
                        HStack {
                            Text(kpSourceLabel(row.source))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: TS.Spacing.md)
                            Text(row.planet.name)
                                .fontWeight(.semibold)
                        }
                        .font(TS.Font.body)
                        .padding(TS.Padding.cardInner)
                        .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.card))
                    }
                }

                Text("四轴层级")
                    .font(TS.Font.sectionTitle)
                Table(result.angles) {
                    TableColumn("轴点", value: \.name)
                    TableColumn("位置", value: \.degreeText)
                    TableColumn("星座主") { Text($0.signLord.name) }
                    TableColumn("宿 / 宿主") { Text("\($0.nakshatra.name) · \($0.nakshatra.lord.name)") }
                    TableColumn("副星主") { Text($0.subLord.name) }
                    TableColumn("副副星主") { Text($0.subSubLord.name) }
                }
                .frame(minHeight: 190)
                .tsTableStyle()

                Label(
                    "这是可审计数据包：行星来自提问时刻，数字确定上升和宫头；系统不自动给出 yes/no 或吉凶裁决。",
                    systemImage: "checkmark.shield"
                )
                .font(TS.Font.label)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct KPPositionSummary<Position: KPPositionRepresentable>: View {
    let position: Position

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: TS.Spacing.xl, verticalSpacing: TS.Spacing.sm) {
            GridRow {
                Text("位置").foregroundStyle(.secondary)
                Text(position.degreeText).monospacedDigit()
                Text("星座主").foregroundStyle(.secondary)
                Text(position.signLord.name)
            }
            GridRow {
                Text("Nakshatra").foregroundStyle(.secondary)
                Text("\(position.nakshatra.name) · 第 \(position.nakshatra.pada) 足")
                Text("宿主").foregroundStyle(.secondary)
                Text(position.nakshatra.lord.name)
            }
            GridRow {
                Text("副星主").foregroundStyle(.secondary)
                Text(position.subLord.name)
                Text("副副星主").foregroundStyle(.secondary)
                Text(position.subSubLord.name)
            }
        }
        .font(TS.Font.body)
        .textSelection(.enabled)
    }
}

struct KPPlanetTableView: View {
    let planets: [KPPlanet]

    var body: some View {
        Table(planets) {
            TableColumn("行星", value: \.name)
            TableColumn("位置", value: \.degreeText)
            TableColumn("宫") { Text("\($0.house)").monospacedDigit() }
            TableColumn("星座主") { Text($0.signLord.name) }
            TableColumn("宿 / 宿主") { Text("\($0.nakshatra.name) · \($0.nakshatra.lord.name)") }
            TableColumn("副星主") { Text($0.subLord.name) }
            TableColumn("副副星主") { Text($0.subSubLord.name) }
            TableColumn("运动") { Text($0.retrograde ? "逆行" : "顺行") }
        }
        .tsTableStyle()
    }
}

struct KPHouseTableView: View {
    let houses: [KPHouse]

    var body: some View {
        Table(houses) {
            TableColumn("宫位") { Text("第 \($0.house) 宫") }
            TableColumn("宫头", value: \.degreeText)
            TableColumn("星座主") { Text($0.signLord.name) }
            TableColumn("宿 / 宿主") { Text("\($0.nakshatra.name) · \($0.nakshatra.lord.name)") }
            TableColumn("副星主") { Text($0.subLord.name) }
            TableColumn("副副星主") { Text($0.subSubLord.name) }
        }
        .tsTableStyle()
    }
}

struct KPPlanetSignificatorsView: View {
    let rows: [KPPlanetSignificator]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text("候选宫位是三组来源的并集，不代表权重或自动结论。")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        HStack {
                            Text(row.planet.name).font(TS.Font.sectionTitle)
                            Spacer()
                            Text(row.candidateHouses.map(String.init).joined(separator: " · "))
                                .font(TS.Font.monoSmall)
                                .foregroundStyle(TS.SemanticColor.goldDeep)
                        }
                        Grid(alignment: .leading, horizontalSpacing: TS.Spacing.xl, verticalSpacing: TS.Spacing.sm) {
                            kpScopeRow("行星本身", row.direct)
                            kpScopeRow("宿主来源", row.starLordScope)
                            kpScopeRow("副星主来源", row.subLordScope)
                        }
                    }
                    .padding(TS.Padding.cardInner)
                    .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.card))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func kpScopeRow(_ label: String, _ scope: KPSignificatorScope) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(scope.planet.name)
            Text(scope.occupiedHouse.map { "落 \($0) 宫" } ?? "无落宫")
            Text(scope.ownedHouses.isEmpty ? "无守护宫" : "守 \(scope.ownedHouses.map(String.init).joined(separator: ", ")) 宫")
        }
        .font(TS.Font.body)
    }
}

struct KPHouseSignificatorsView: View {
    let rows: [KPHouseSignificator]

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 330), spacing: TS.Spacing.md)],
                alignment: .leading,
                spacing: TS.Spacing.md
            ) {
                ForEach(rows) { row in
                    KPHouseSignificatorCard(row: row)
                }
            }
        }
    }
}

struct KPFocusHouseView: View {
    let row: KPHouseSignificator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                Text("第 \(row.house) 宫")
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .foregroundStyle(TS.SemanticColor.goldDeep)
                Text("焦点宫直接复用同一套四级候选来源，没有另加隐藏评分。")
                    .font(TS.Font.body)
                    .foregroundStyle(.secondary)
                KPHouseSignificatorCard(row: row)
                    .frame(maxWidth: 720, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct KPHouseSignificatorCard: View {
    let row: KPHouseSignificator

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack {
                Text("第 \(row.house) 宫").font(TS.Font.sectionTitle)
                Spacer()
                Text("宫头主 · \(row.cuspSignLord.name)")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
            }
            ForEach(row.tiers) { tier in
                HStack(alignment: .top, spacing: TS.Spacing.md) {
                    Text("T\(tier.tier)")
                        .font(TS.Font.monoSmall)
                        .foregroundStyle(TS.SemanticColor.goldDeep)
                        .frame(width: 24, alignment: .leading)
                    VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                        Text(kpSourceLabel(tier.source))
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                        Text(tier.planets.isEmpty ? "—" : tier.planets.map(\.name).joined(separator: " · "))
                            .font(TS.Font.body)
                    }
                }
            }
        }
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.card))
    }
}

struct KPHoraryDiagnosticsView: View {
    let result: KPHoraryResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                Text("契约与方法")
                    .font(TS.Font.sectionTitle)
                Grid(alignment: .leading, horizontalSpacing: TS.Spacing.xl, verticalSpacing: TS.Spacing.sm) {
                    diagnosticRow("Schema", result.schema.schemaID)
                    diagnosticRow("黄道 / 岁差", "\(result.calculationConfig.zodiac) / \(result.calculationConfig.ayanamsha)")
                    diagnosticRow("Ayanamsha", String(format: "%.9f°", result.calculationConfig.ayanamshaDegreesAtQuestion))
                    diagnosticRow("宫制 / 交点", "\(result.calculationConfig.houseSystem) / \(result.calculationConfig.nodeMode)")
                    diagnosticRow("问题 UTC", result.timeAndLocation.questionUTC)
                    diagnosticRow("宫位求解 UTC", result.timeAndLocation.houseSolutionUTC)
                    diagnosticRow("目标上升", String(format: "%.12f°", result.houseSolution.targetAscendant))
                    diagnosticRow("实算上升", String(format: "%.12f°", result.houseSolution.solvedAscendant))
                    diagnosticRow("求解残差", String(format: "%.12g°", result.houseSolution.residualDegrees))
                    diagnosticRow("求值次数", "\(result.houseSolution.evaluations)")
                    diagnosticRow("自动裁决", result.calculationConfig.automaticJudgment ? "开启" : "关闭")
                }
                .font(TS.Font.body)
                .textSelection(.enabled)

                Text("交点直接代表关系")
                    .font(TS.Font.sectionTitle)
                ForEach(result.nodeRepresentations) { row in
                    Text("\(row.node.name)：落 \(row.occupiedHouse) 宫 · 星座主 \(row.signLord.name) · 宿主 \(row.starLord.name) · 副星主 \(row.subLord.name)")
                        .font(TS.Font.body)
                        .textSelection(.enabled)
                }

                WarningList(warnings: result.warnings)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }
}

private func kpSourceLabel(_ source: String) -> String {
    switch source {
    case "ascendant_sign_lord": return "上升星座主"
    case "ascendant_star_lord": return "上升宿主"
    case "ascendant_sub_lord": return "上升副星主"
    case "moon_sign_lord": return "月亮星座主"
    case "moon_star_lord": return "月亮宿主"
    case "moon_sub_lord": return "月亮副星主"
    case "local_weekday_lord": return "本地星期主"
    case "planets_in_stars_of_occupants": return "落宫行星之宿内行星"
    case "occupants": return "落宫行星"
    case "planets_in_stars_of_cusp_sign_lord": return "宫头星座主之宿内行星"
    case "cusp_sign_lord": return "宫头星座主"
    default: return source.replacingOccurrences(of: "_", with: " ")
    }
}
