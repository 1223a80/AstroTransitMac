import SwiftUI

struct ClassicalPlanetTableView: View {
    let planets: [ClassicalPlanetRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("七政古典状态")
                .font(.headline)
            Table(planets) {
                TableColumn("星体") { Text($0.name) }
                TableColumn("位置") { Text($0.degreeText).monospacedDigit() }
                TableColumn("宫") { Text("\($0.house)") }
                TableColumn("运动") { Text($0.motion) }
                TableColumn("Sect") { Text($0.sectStatus) }
                TableColumn("庙旺失陷") { planet in
                    Text([planet.domicile, planet.exaltation, planet.detriment, planet.fall]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " "))
                }
                TableColumn("三分/界/面") { planet in
                    Text([planet.triplicity, planet.bound, planet.decan].filter { !$0.isEmpty }.joined(separator: "/"))
                }
                TableColumn("Hayz/Joy") { planet in
                    Text([planet.hayz, planet.joy].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
                }
                TableColumn("善/虐") { planet in
                    Text("\(planet.bonification.count)/\(planet.maltreatment.count)")
                }
            }
        }
    }
}

struct ClassicalPointsView: View {
    let angles: [ClassicalPoint]
    let lots: [ClassicalPoint]
    let experimentalLots: [ClassicalPoint]?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("角点")
                .font(.headline)
            PointTable(points: angles)
            Text("Hermetic Lots")
                .font(.headline)
            PointTable(points: lots)
            if let expLots = experimentalLots, !expLots.isEmpty {
                Text("实验性 Lots（来源未确认）")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("以下 Lots 公式来源不确定，仅供参考")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PointTable(points: expLots, showConfidence: true)
            }
        }
    }
}

struct PointTable: View {
    let points: [ClassicalPoint]
    var showConfidence: Bool = false

    var body: some View {
        if showConfidence {
            Table(points) {
                TableColumn("点") { Text($0.name) }
                TableColumn("位置") { Text($0.degreeText).monospacedDigit() }
                TableColumn("宫") { Text("\($0.house)") }
                TableColumn("主星") { Text($0.ruler) }
                TableColumn("置信度") { point in
                    Text(point.confidence ?? "low")
                        .foregroundStyle((point.confidence ?? "low") == "high" ? .green : .orange)
                }
                TableColumn("公式") { Text($0.formula ?? "") }
            }
        } else {
            Table(points) {
                TableColumn("点") { Text($0.name) }
                TableColumn("位置") { Text($0.degreeText).monospacedDigit() }
                TableColumn("宫") { Text("\($0.house)") }
                TableColumn("主星") { Text($0.ruler) }
                TableColumn("公式") { Text($0.formula ?? "") }
            }
        }
    }
}

struct ClassicalHouseTableView: View {
    let houses: [HouseRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("宫位")
                .font(.headline)
            Table(houses) {
                TableColumn("宫") { Text("\($0.house)") }
                TableColumn("宫头") { Text($0.cuspText).monospacedDigit() }
                TableColumn("星座") { Text($0.sign) }
                TableColumn("主星") { Text($0.ruler) }
            }
        }
    }
}

struct ClassicalAspectReceptionView: View {
    let aspects: [ClassicalAspectRow]
    let receptions: [ReceptionRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("古典相位")
                .font(.headline)
            Table(aspects) {
                TableColumn("A") { Text($0.bodyA) }
                TableColumn("相位") { Text($0.aspect) }
                TableColumn("B") { Text($0.bodyB) }
                TableColumn("类型") { Text($0.aspectType) }
                TableColumn("容许") { Text(degree($0.orb)) }
                TableColumn("入离") { Text($0.applying ?? "") }
            }

            Text("接纳")
                .font(.headline)
            Table(receptions) {
                TableColumn("接纳者") { Text($0.receiver) }
                TableColumn("被接纳") { Text($0.received) }
                TableColumn("尊贵") { Text($0.dignity) }
                TableColumn("经由相位") { Text($0.viaAspect) }
                TableColumn("强度") { Text($0.strengthLabel ?? "") }
            }
        }
    }

    private func degree(_ value: Double?) -> String {
        guard let value else {
            return ""
        }
        return String(format: "%.2f°", value)
    }
}

struct ClassicalTimingView: View {
    let timing: TimingSummary
    let planetaryReturns: [SolarReturnSummary]
    let circumambulations: [Circumambulation]?

    private var solarReturn: SolarReturnSummary? {
        planetaryReturns.first { $0.bodyID == "SUN" }
    }

    private var currentSolarReturn: ReturnChartSnapshot? {
        solarReturn?.currentCycleReturn
    }

    private var previousSolarReturn: ReturnChartSnapshot? {
        solarReturn?.previousReturn
    }

    private var nextSolarReturn: ReturnChartSnapshot? {
        solarReturn?.nextReturn
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ActiveOverviewView(
                    timing: timing,
                    planetaryReturns: planetaryReturns,
                    circumambulations: circumambulations
                )

                TimingSectionBox(title: "Annual Profection") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                        GridRow {
                            Text("年龄").foregroundStyle(.secondary)
                            Text("\(timing.profection.age)岁")
                        }
                        GridRow {
                            Text("激活宫位").foregroundStyle(.secondary)
                            Text("\(timing.profection.house)宫 \(timing.profection.sign)")
                        }
                        GridRow {
                            Text("年主").foregroundStyle(.secondary)
                            Text(timing.profection.lord)
                        }
                        GridRow {
                            Text("年限区间").foregroundStyle(.secondary)
                            Text("\(timing.profection.startLocal) - \(timing.profection.endLocal)")
                                .monospacedDigit()
                        }
                        GridRow {
                            Text("年主状态").foregroundStyle(.secondary)
                            Text(timing.profection.lordCondition.isEmpty ? "未取得年主状态" : timing.profection.lordCondition)
                        }
                        GridRow {
                            Text("激活宫内行星").foregroundStyle(.secondary)
                            Text(timing.profection.activatedPlanets.isEmpty ? "无" : timing.profection.activatedPlanets.joined(separator: "、"))
                        }
                        if let profSign = timing.profection.profectedAscSign {
                            GridRow {
                                Text("Profected ASC").foregroundStyle(.secondary)
                                Text(profSign)
                            }
                        }
                    }

                    if let monthly = timing.profection.monthly {
                        Divider()
                        Text("月小限")
                            .font(.headline)
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            GridRow {
                                Text("月份").foregroundStyle(.secondary)
                                Text("第 \(monthly.month) 月")
                            }
                            GridRow {
                                Text("星座").foregroundStyle(.secondary)
                                Text(monthly.sign)
                            }
                            GridRow {
                                Text("月主").foregroundStyle(.secondary)
                                Text(monthly.lord)
                            }
                            if let cond = monthly.lordCondition, !cond.isEmpty {
                                GridRow {
                                    Text("月主状态").foregroundStyle(.secondary)
                                    Text(cond)
                                }
                            }
                        }
                    }

                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("逻辑链")
                            .font(.headline)
                        ForEach(timing.profection.logicSteps, id: \.self) { step in
                            Text(step)
                        }
                    }
                }

                TimingSectionBox(title: "Firdaria") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(timing.firdaria.ruler) \(timing.firdaria.level)")
                            .font(.headline)
                        Text("\(timing.firdaria.startLocal) - \(timing.firdaria.endLocal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        if !timing.firdaria.notes.isEmpty {
                            Text(timing.firdaria.notes.joined(separator: "、"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let next = timing.firdaria.nextTransition {
                            Text("下一次转换：\(next)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        if let houses = timing.firdaria.activatedHouses, !houses.isEmpty {
                            Text("激活宫位：\(houses.map { "第\($0)宫" }.joined(separator: "、"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let currentSub = timing.firdaria.currentSubPeriod {
                            Text("当前次限：\(currentSub.ruler) \(currentSub.startLocal) - \(currentSub.endLocal)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        if let method = timing.firdaria.method {
                            Text("\(method) / \(timing.firdaria.sourceTradition ?? "")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if let subPeriods = timing.firdaria.subPeriods, !subPeriods.isEmpty {
                            Divider()
                            Text("次限")
                                .font(.headline)
                            ForEach(subPeriods) { sub in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(sub.ruler)
                                        .frame(width: 44, alignment: .leading)
                                    Text(sub.startLocal)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    Text("-")
                                        .foregroundStyle(.secondary)
                                    Text(sub.endLocal)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    Spacer()
                                    Text(String(format: "%.1f%%", sub.fraction * 100))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                TimingSectionBox(title: "Decennials") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(timing.decennials.ruler) \(timing.decennials.level)")
                            .font(.headline)
                        Text("\(timing.decennials.startLocal) - \(timing.decennials.endLocal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        if !timing.decennials.notes.isEmpty {
                            Text(timing.decennials.notes.joined(separator: "、"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let subPeriods = timing.decennials.subPeriods, !subPeriods.isEmpty {
                            Divider()
                            Text("子限")
                                .font(.headline)
                            ForEach(subPeriods) { sub in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(sub.ruler)
                                        .frame(width: 44, alignment: .leading)
                                    Text(sub.startLocal)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    Text("-")
                                        .foregroundStyle(.secondary)
                                    Text(sub.endLocal)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    Spacer()
                                    Text(String(format: "%.1f%%", sub.fraction * 100))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                TimingSectionBox(title: "Zodiacal Releasing") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(timing.zodiacalReleasing) { zr in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(zr.technique)
                                    .font(.headline)
                                Text("\(zr.ruler) \(zr.sign ?? "")")
                                Text("\(zr.startLocal) - \(zr.endLocal)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                if let next = zr.nextTransition {
                                    Text("下一次转换：\(next)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                if let score = zr.importanceScore {
                                    Text("重要性评分：\(score)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let method = zr.method {
                                    Text("\(method) / \(zr.sourceTradition ?? "")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                if let lob = zr.loosingOfBond, lob {
                                    Label(zr.loosingOfBondDetail ?? "Loosing of the Bond", systemImage: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }

                                if let l2 = zr.l2Periods, !l2.isEmpty {
                                    Divider()
                                    Text("L2 子周期")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    ForEach(l2) { period in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text(period.isActive == true ? "▶" : " ")
                                                .foregroundStyle(.blue)
                                            Text(period.ruler)
                                                .frame(width: 44, alignment: .leading)
                                            Text(period.sign)
                                                .frame(width: 44, alignment: .leading)
                                            Text("\(period.startLocal) - \(period.endLocal)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }

                                        if let l3 = period.subPeriods, !l3.isEmpty, period.isActive == true {
                                            ForEach(l3) { l3p in
                                                HStack(alignment: .top, spacing: 10) {
                                                    Text("   ")
                                                    Text(l3p.isActive == true ? "▶" : " ")
                                                        .foregroundStyle(.green)
                                                    Text(l3p.ruler)
                                                        .frame(width: 44, alignment: .leading)
                                                    Text(l3p.sign)
                                                        .frame(width: 44, alignment: .leading)
                                                    Text("\(l3p.startLocal) - \(l3p.endLocal)")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                        .monospacedDigit()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            if zr.id != timing.zodiacalReleasing.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                if let previousSR = previousSolarReturn {
                    TimingSectionBox(title: "Previous Solar Return（上一次）") {
                        ReturnSummaryView(snapshot: previousSR, showCrossAspects: true)
                    }
                }

                if let currentSR = currentSolarReturn {
                    TimingSectionBox(title: "Current Solar Return（当前生效）") {
                        ReturnSummaryView(snapshot: currentSR, showCrossAspects: true)
                    }
                }

                if let nextSR = nextSolarReturn {
                    TimingSectionBox(title: "Next Solar Return（下一次）") {
                        ReturnSummaryView(snapshot: nextSR, showCrossAspects: true)
                    }
                }

                TimingSectionBox(title: "Returns") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(planetaryReturns.filter { $0.bodyID != "SUN" }) { summary in
                            if let previous = summary.previousReturn {
                                TimingSectionBox(title: "Previous \(summary.title)（上一次）") {
                                    ReturnSummaryView(snapshot: previous, showCrossAspects: true)
                                }
                            }
                            if let current = summary.currentCycleReturn {
                                TimingSectionBox(title: "Current \(summary.title)（当前生效）") {
                                    ReturnSummaryView(snapshot: current, showCrossAspects: true)
                                }
                            }
                            if let next = summary.nextReturn {
                                TimingSectionBox(title: "Next \(summary.title)（下一次）") {
                                    ReturnSummaryView(snapshot: next, showCrossAspects: true)
                                }
                            }
                            if summary.previousReturn == nil && summary.currentCycleReturn == nil && summary.nextReturn == nil {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(summary.title)：\(summary.noHitInUserWindow == true ? "未在搜索窗口内找到" : "无数据")")
                                        .foregroundStyle(.secondary)
                                    if let window = summary.suggestedWindow {
                                        Text(window)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            if summary.id != planetaryReturns.filter({ $0.bodyID != "SUN" }).last?.id {
                                Divider()
                            }
                        }
                    }
                }

                TimingSectionBox(title: "统一时间线") {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                        GridRow {
                            Text("分层").fontWeight(.medium).frame(width: 60, alignment: .leading)
                            Text("技法").fontWeight(.medium).frame(width: 60, alignment: .leading)
                            Text("标题").fontWeight(.medium).frame(width: 120, alignment: .leading)
                            Text("开始").fontWeight(.medium).frame(width: 120, alignment: .leading)
                            Text("结束").fontWeight(.medium).frame(width: 120, alignment: .leading)
                            Text("类型").fontWeight(.medium).frame(width: 44, alignment: .leading)
                        }
                        Divider()
                            .gridCellUnsizedAxes(.horizontal)
                        ForEach(timing.timeline) { item in
                            GridRow {
                                let layerName: String = {
                                    switch item.layer {
                                    case "active_periods": return "活跃周期"
                                    case "active_returns": return "有效返照"
                                    case "events": return "事件"
                                    case "historical": return "历史参考"
                                    default: return item.layer ?? ""
                                    }
                                }()
                                Text(layerName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                Text(item.technique ?? "")
                                    .frame(width: 60, alignment: .leading)
                                Text(item.title)
                                    .frame(width: 120, alignment: .leading)
                                Text(item.startLocal)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 120, alignment: .leading)
                                    .monospacedDigit()
                                Text(item.startLocal == item.endLocal ? "" : item.endLocal)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 120, alignment: .leading)
                                    .monospacedDigit()
                                Text(item.kind == "event" ? "事件" : "周期")
                                    .frame(width: 44, alignment: .leading)
                                    .foregroundStyle(item.kind == "event" ? .orange : .secondary)
                            }
                        }
                    }
                }
            }
            .padding(.trailing, 8)
        }
    }
}

// MARK: - 当前激活技法总览
struct ActiveOverviewView: View {
    let timing: TimingSummary
    let planetaryReturns: [SolarReturnSummary]
    let circumambulations: [Circumambulation]?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("当前激活技法总览")
                    .font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    profectionRows
                    if let monthly = timing.profection.monthly {
                        monthlyRows(monthly)
                    }
                    firdariaRows
                    decennialsRows
                    zrRows
                    if let circs = circumambulations, !circs.isEmpty {
                        circumambulationRows(circs)
                    }
                    returnRows
                    nearbyEventRows
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var profectionRows: some View {
        GridRow {
            Text("年小限").foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text("\(timing.profection.age)岁 / \(timing.profection.house)宫 \(timing.profection.sign) / 年主 \(timing.profection.lord)")
        }
        GridRow {
            Text("").foregroundStyle(.secondary)
            Text("\(timing.profection.startLocal) - \(timing.profection.endLocal)")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    @ViewBuilder
    private func monthlyRows(_ monthly: MonthlyProfection) -> some View {
        GridRow {
            Text("月小限").foregroundStyle(.secondary)
            Text("第 \(monthly.month) 月 / \(monthly.sign) / 月主 \(monthly.lord)")
        }
    }

    @ViewBuilder
    private var firdariaRows: some View {
        GridRow {
            Text("Firdaria").foregroundStyle(.secondary)
            Text("主限 \(timing.firdaria.ruler) / \(timing.firdaria.startLocal) - \(timing.firdaria.endLocal)")
        }
        if let sub = timing.firdaria.currentSubPeriod {
            GridRow {
                Text("").foregroundStyle(.secondary)
                Text("当前次限 \(sub.ruler) \(sub.startLocal) - \(sub.endLocal)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var decennialsRows: some View {
        GridRow {
            Text("Decennials").foregroundStyle(.secondary)
            Text("主限 \(timing.decennials.ruler) / \(timing.decennials.startLocal) - \(timing.decennials.endLocal)")
        }
    }

    @ViewBuilder
    private var zrRows: some View {
        ForEach(timing.zodiacalReleasing) { zr in
            GridRow {
                Text(zr.technique).foregroundStyle(.secondary).lineLimit(1)
                Text("L\(zr.currentActiveLevel ?? "1") / \(zr.ruler) \(zr.sign ?? "")")
                if let lob = zr.loosingOfBond, lob {
                    Label("LoB", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange).font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private func circumambulationRows(_ circs: [Circumambulation]) -> some View {
        ForEach(circs) { circ in
            GridRow {
                Text("沿界推进").foregroundStyle(.secondary)
                Text("界主 \(circ.currentRuler)")
            }
        }
    }

    @ViewBuilder
    private var returnRows: some View {
        if let current = currentSolarReturn {
            GridRow {
                Text("当前返照").foregroundStyle(.secondary)
                Text("\(current.exactLocal) / ASC \(current.ascendant)")
            }
        }
        if let next = nextSolarReturn {
            GridRow {
                Text("下一返照").foregroundStyle(.secondary)
                Text("\(next.exactLocal) / ASC \(next.ascendant)")
            }
        }
    }

    private var currentSolarReturn: ReturnChartSnapshot? {
        solarReturn?.currentCycleReturn
    }

    private var nextSolarReturn: ReturnChartSnapshot? {
        solarReturn?.nextReturn
    }

    private var solarReturn: SolarReturnSummary? {
        planetaryReturns.first { $0.bodyID == "SUN" }
    }

    @ViewBuilder
    private var nearbyEventRows: some View {
        let events = timing.timeline.filter { $0.kind == "event" }
        if !events.isEmpty {
            GridRow {
                Text("近期事件").foregroundStyle(.secondary)
                Text(events.prefix(3).map { "\($0.title): \($0.startLocal)" }.joined(separator: "；"))
                    .font(.caption)
            }
        }
    }
}

struct ClassicalJudgementView: View {
    let planets: [ClassicalPlanetRow]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(planets) { planet in
                    TimingSectionBox(title: "\(planet.name) 评分 \(planet.score)\(planet.scoreLabel.map { " (\($0))" } ?? "")") {
                        VStack(alignment: .leading, spacing: 10) {
                            if !planet.scoreBreakdown.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("评分明细")
                                        .font(.headline)
                                    ForEach(planet.scoreBreakdown) { item in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text(item.label)
                                                .frame(width: 88, alignment: .leading)
                                                .foregroundStyle(.secondary)
                                            Text(item.value)
                                            Spacer(minLength: 0)
                                            Text(item.score >= 0 ? "+\(item.score)" : "\(item.score)")
                                                .monospacedDigit()
                                        }
                                    }
                                }
                            }

                            if let triplicityDetails = planet.triplicityDetails, !triplicityDetails.isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("三分主星评估")
                                        .font(.headline)
                                    ForEach(triplicityDetails) { detail in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text(detail.label)
                                                .frame(width: 44, alignment: .leading)
                                            Text(detail.ruler)
                                                .frame(width: 44, alignment: .leading)
                                            Text(detail.status)
                                                .frame(width: 24, alignment: .leading)
                                                .foregroundStyle(detail.status == "强" ? .green : detail.status == "中" ? .orange : .red)
                                            Text(detail.notes.joined(separator: "、"))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Spacer(minLength: 0)
                                            Text("\(detail.score)")
                                                .monospacedDigit()
                                        }
                                    }
                                }
                            }

                            if !planet.bonification.isEmpty {
                                Divider()
                                ModifierList(title: "Bonification", rows: planet.bonification)
                            }

                            if !planet.maltreatment.isEmpty {
                                Divider()
                                ModifierList(title: "Maltreatment", rows: planet.maltreatment)
                            }
                        }
                    }
                }
            }
            .padding(.trailing, 8)
        }
    }
}

struct TimingSectionBox<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TimingAngleList: View {
    let points: [ClassicalPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("返照角点")
                .font(.headline)
            ForEach(points) { point in
                HStack(alignment: .top, spacing: 10) {
                    Text(point.name)
                        .frame(width: 50, alignment: .leading)
                    Text(point.degreeText)
                        .frame(width: 108, alignment: .leading)
                        .monospacedDigit()
                    Text("第\(point.house)宫")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct TimingPlanetList: View {
    let planets: [ClassicalPlanetRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("返照七政")
                .font(.headline)
            ForEach(planets) { planet in
                HStack(alignment: .top, spacing: 10) {
                    Text(planet.name)
                        .frame(width: 44, alignment: .leading)
                    Text(planet.degreeText)
                        .frame(width: 108, alignment: .leading)
                        .monospacedDigit()
                    Text("第\(planet.house)宫")
                        .frame(width: 52, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(planet.motion)
                        .frame(width: 36, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text("评分 \(planet.score)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ReturnSummaryView: View {
    let snapshot: ReturnChartSnapshot
    let showCrossAspects: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("类型").foregroundStyle(.secondary)
                    Text(snapshot.label)
                }
                GridRow {
                    Text("精确时间").foregroundStyle(.secondary)
                    Text(snapshot.exactLocal.isEmpty ? "未找到" : snapshot.exactLocal)
                        .monospacedDigit()
                }
                GridRow {
                    Text("精确 UTC").foregroundStyle(.secondary)
                    Text(snapshot.exactUTC)
                        .monospacedDigit()
                }
                GridRow {
                    Text("返照角点").foregroundStyle(.secondary)
                    Text("ASC \(snapshot.ascendant)，MC \(snapshot.midheaven)")
                }
                GridRow {
                    Text("昼夜 / 宫制").foregroundStyle(.secondary)
                    Text("\(snapshot.sect) / \(snapshot.houseSystem)")
                }
                if let paSign = snapshot.profectedAscSign {
                    GridRow {
                        Text("Profected ASC").foregroundStyle(.secondary)
                        Text(paSign)
                    }
                }
                if let paHouse = snapshot.profectedAscHouse, paHouse > 0 {
                    GridRow {
                        Text("Profected ASC 宫位").foregroundStyle(.secondary)
                        Text("第 \(paHouse) 宫")
                    }
                }
                if let retHouse = snapshot.returnAscInNatalHouse, retHouse > 0 {
                    GridRow {
                        Text("返照 ASC 在本命").foregroundStyle(.secondary)
                        Text("第 \(retHouse) 宫")
                    }
                }
            }

            if let overlay = snapshot.houseOverlay, !overlay.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("宫位叠加")
                        .font(.headline)
                    ForEach(overlay) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Text(item.planet)
                                .frame(width: 44, alignment: .leading)
                            Text("返照第\(item.returnHouse)宫")
                                .foregroundStyle(.secondary)
                            Text("→")
                                .foregroundStyle(.secondary)
                            Text("本命第\(item.natalHouse)宫")
                        }
                    }
                }
            }

            if !snapshot.angles.isEmpty {
                Divider()
                TimingAngleList(points: snapshot.angles)
            }
            if !snapshot.planets.isEmpty {
                Divider()
                TimingPlanetList(planets: snapshot.planets)
            }
            if showCrossAspects && !snapshot.natalCrossAspects.isEmpty {
                Divider()
                ReturnCrossAspectList(aspects: snapshot.natalCrossAspects)
            }
        }
    }
}

struct ReturnCrossAspectList: View {
    let aspects: [ReturnCrossAspect]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("返照与本命交叉")
                .font(.headline)
            ForEach(aspects.prefix(12)) { aspect in
                HStack(alignment: .top, spacing: 10) {
                    Text(aspect.leftBodyName)
                        .frame(width: 44, alignment: .leading)
                    Text(aspect.aspect)
                        .frame(width: 56, alignment: .leading)
                    Text(aspect.rightBodyName)
                        .frame(width: 44, alignment: .leading)
                    Text(aspect.isCoPresence == true ? "同宫" : aspect.orb.map { String(format: "%.2f°", $0) } ?? "星座")
                        .foregroundStyle(.secondary)
                    Text(aspect.applying ?? "")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ModifierList: View {
    let title: String
    let rows: [ConditioningModifier]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: 10) {
                    Text(row.source)
                        .frame(width: 44, alignment: .leading)
                    Text(row.aspect)
                        .frame(width: 36, alignment: .leading)
                    Text(row.orb.map { String(format: "%.2f°", $0) } ?? "星座")
                        .frame(width: 56, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(row.applying ?? "")
                        .frame(width: 36, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(row.strengthLabel)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text("\(row.strengthScore)")
                        .monospacedDigit()
                }
            }
        }
    }
}

struct AntisciaView: View {
    let antiscia: [AntisciaRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("映点 / 反映点")
                .font(.headline)
            Table(antiscia) {
                TableColumn("行星") { Text($0.planet) }
                TableColumn("映点位置") { Text($0.antisciaDegree).monospacedDigit() }
                TableColumn("反映点位置") { Text($0.contraDegree).monospacedDigit() }
                TableColumn("本命命中") { row in
                    if row.natalHits.isEmpty {
                        Text("—").foregroundStyle(.secondary)
                    } else {
                        Text(row.natalHits.map { "\($0.via): \($0.hitPlanet) (\(String(format: "%.1f°", $0.orb)))" }.joined(separator: "; "))
                    }
                }
            }
        }
    }
}

struct CircumambulationsView: View {
    let circumambulations: [Circumambulation]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Circumambulations through the Bounds（沿界推进）")
                .font(.headline)
            if circumambulations.isEmpty {
                Text("无数据").foregroundStyle(.secondary)
            } else {
                ForEach(circumambulations) { circ in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("系统：\(circ.system)")
                            Text("当前界主：\(circ.currentRuler)")
                                .fontWeight(.bold)
                        }
                        Text("Naibod rate：\(String(format: "%.4f", circ.naibodRate))°/年")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let info = circ.currentBoundInfo {
                            Text("当前推运位置：\(info)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let lord = circ.boundLord, let sign = circ.boundSign,
                           let sDeg = circ.boundStartDegree, let eDeg = circ.boundEndDegree {
                            Text("当前宫限：\(sign) \(sDeg)°00 – \(eDeg)°00，主星 \(lord)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let start = circ.boundStartDate, let end = circ.boundEndDate, !start.isEmpty {
                            Text("区间：\(start) → \(end)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let pos = circ.currentDirectedPosition {
                            Text("Directed ASC：\(String(format: "%.4f", pos))°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                        Table(circ.boundaries.prefix(30)) {
                            TableColumn("星座") { Text($0.sign) }
                            TableColumn("度数") { row in
                                if let sDeg = row.startDegree {
                                    Text("\(sDeg)°–\(row.endDegree)°")
                                } else {
                                    Text("\(row.endDegree)°")
                                }
                            }
                            TableColumn("界主") { Text($0.ruler) }
                            TableColumn("Arc") { row in
                                Text(String(format: "%.2f°", row.arcValue))
                                    .monospacedDigit()
                            }
                            TableColumn("年龄") { row in
                                Text(String(format: "%.1f", row.ageAtBoundary))
                                    .monospacedDigit()
                            }
                            TableColumn("日期") { row in
                                Text(row.estimatedDate)
                                    .monospacedDigit()
                            }
                        }
                    }
                    if circ.id != circumambulations.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

struct PrimaryDirectionsView: View {
    let directions: [PrimaryDirection]

    private func isConverse(_ row: PrimaryDirection) -> Bool {
        row.directionType == "converse"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Primary Directions (主限法)")
                .font(.headline)
            Text("共 \(directions.count) 条方向")
                .font(.caption)
                .foregroundStyle(.secondary)
            if directions.isEmpty {
                Text("无数据").foregroundStyle(.secondary)
            } else {
                Table(directions) {
                    TableColumn("Promissor") { Text($0.promissor) }
                    TableColumn("Significator") { Text($0.significator) }
                    TableColumn("相位") { Text($0.aspectName) }
                    TableColumn("方向") { row in
                        Text(row.directionType == "converse" ? "逆" : "顺")
                            .foregroundStyle(isConverse(row) ? .secondary : .primary)
                    }
                    TableColumn("Arc") { row in
                        Text(String(format: "%+.2f°", row.arcSigned ?? 0))
                            .monospacedDigit()
                            .foregroundStyle(isConverse(row) ? .secondary : .primary)
                    }
                    TableColumn("年龄") { row in
                        Text(String(format: "%.1f", row.ageFromAbsArc))
                            .monospacedDigit()
                    }
                    TableColumn("日期") { row in
                        Text(row.eventDateAfterBirth ?? row.symbolicDateFromSignedArc ?? "")
                            .monospacedDigit()
                            .foregroundStyle(isConverse(row) ? .secondary : .primary)
                    }
                    TableColumn("备注") { row in
                        if let symbolic = row.symbolicDateFromSignedArc {
                            Text("出生前符号日: \(symbolic)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("")
                        }
                    }
                }
            }
        }
    }
}

struct ClassicalDiagnosticsView: View {
    let result: ClassicalResult

    var body: some View {
        ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("出生 UTC").foregroundStyle(.secondary)
                    Text(result.meta.birthUTC).textSelection(.enabled)
                }
                GridRow {
                    Text("参考 UTC").foregroundStyle(.secondary)
                    Text(result.meta.referenceUTC).textSelection(.enabled)
                }
                GridRow {
                    Text("昼夜").foregroundStyle(.secondary)
                    Text(result.meta.sect)
                }
                GridRow {
                    Text("设置").foregroundStyle(.secondary)
                    Text("\(result.meta.houseSystem), \(result.meta.zodiac), \(result.meta.boundsSystem), \(result.meta.triplicitySystem)")
                }
                GridRow {
                    Text("星历").foregroundStyle(.secondary)
                    Text(result.meta.ephemeris).textSelection(.enabled)
                }
                GridRow {
                    Text("统计").foregroundStyle(.secondary)
                    Text("行星 \(result.planets.count)，相位 \(result.aspects.count)，接纳 \(result.receptions.count)，返照 \(result.planetaryReturns.count)")
                }
            }

            if let asteroidWarning = result.warnings.first(where: { $0.localizedCaseInsensitiveContains("asteroid") || $0.contains("小行星") }) {
                GroupBox("小行星处理") {
                    Text(asteroidWarning)
                        .textSelection(.enabled)
                }
            }

            WarningList(warnings: result.warnings)

            if let errors = result.sectionErrors, !errors.isEmpty {
                SectionErrorList(errors: errors)
            }

            if let ambiguity = result.ambiguity {
                GroupBox("技法主星汇总") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("置信度").foregroundStyle(.secondary)
                            Text(ambiguity.confidence)
                        }
                        ForEach(ambiguity.techniqueRulers.keys.sorted(), id: \.self) { key in
                            if let value = ambiguity.techniqueRulers[key], !value.isEmpty {
                                HStack {
                                    Text(key)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 150, alignment: .leading)
                                    Text(value)
                                }
                            }
                        }
                        if !ambiguity.conflictingSignals.isEmpty {
                            Divider()
                            ForEach(ambiguity.conflictingSignals, id: \.self) { signal in
                                Text(signal)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let syzygy = result.prenatalSyzygy {
                GroupBox("产前朔望 (Prenatal Syzygy)") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                        GridRow {
                            Text("类型").foregroundStyle(.secondary)
                            Text(syzygy.syzygyType == "new_moon" ? "朔月 (New Moon)" : "望月 (Full Moon)")
                        }
                        if let utc = syzygy.exactUTC {
                            GridRow {
                                Text("精确 UTC").foregroundStyle(.secondary)
                                Text(utc).monospacedDigit()
                            }
                        }
                        if let sunPos = syzygy.sunPosition, let moonPos = syzygy.moonPosition {
                            GridRow {
                                Text("日月位置").foregroundStyle(.secondary)
                                Text("日 \(String(format: "%.2f", sunPos))° / 月 \(String(format: "%.2f", moonPos))°")
                            }
                        }
                        if let sign = syzygy.sign, let deg = syzygy.degree {
                            GridRow {
                                Text("朔望度数").foregroundStyle(.secondary)
                                Text("\(sign) \(String(format: "%.1f", deg))°")
                            }
                        }
                        if let note = syzygy.syzygyDegreeUsed {
                            GridRow {
                                Text("度数说明").foregroundStyle(.secondary)
                                Text(note).font(.caption)
                            }
                        }
                        if let ruler = syzygy.ruler {
                            GridRow {
                                Text("宫主").foregroundStyle(.secondary)
                                Text(ruler)
                            }
                        }
                        if let mv = syzygy.methodVariant {
                            GridRow {
                                Text("方法").foregroundStyle(.secondary)
                                Text(mv).font(.caption)
                            }
                        }
                    }
                }
            }

            if let almuten = result.almutenFiguris {
                GroupBox("Almuten Figuris (全盘最尊贵行星)") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let winner = almuten.winner {
                            HStack {
                                Text("最尊贵行星").foregroundStyle(.secondary)
                                Text(winner).fontWeight(.bold)
                            }
                        }
                        if let conf = almuten.confidence {
                            HStack {
                                Text("置信度").foregroundStyle(.secondary)
                                Text(conf)
                                    .foregroundStyle(conf == "high" ? .green : .red)
                            }
                        }
                        if let table = almuten.scoreTable {
                            Divider()
                            ForEach(table.prefix(7)) { entry in
                                HStack {
                                    Text(entry.planet)
                                        .frame(width: 44, alignment: .leading)
                                    Text("评分 \(entry.total)")
                                        .monospacedDigit()
                                    Spacer()
                                    Text(entry.contributions.map { "\($0.point)(\($0.dignity)+\($0.weight))" }.joined(separator: " "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if let hyleg = result.hylegAlcocoden {
                GroupBox("Hyleg / Alcocoden (生命主星)") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let h = hyleg.hyleg, let selected = h.selected, !selected.isEmpty {
                            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                                GridRow {
                                    Text("Hyleg").foregroundStyle(.secondary)
                                    Text(selected).fontWeight(.bold)
                                }
                                if let reason = h.reason {
                                    GridRow {
                                        Text("理由").foregroundStyle(.secondary)
                                        Text(reason)
                                    }
                                }
                            }
                            if let candidates = h.candidates, !candidates.isEmpty {
                                Divider()
                                Text("候选列表").font(.headline)
                                ForEach(candidates) { c in
                                    HStack {
                                        Text(c.eligible == true ? "✓" : "✗")
                                        Text(c.name).frame(width: 44, alignment: .leading)
                                        Text("H\(c.house ?? 0)").foregroundStyle(.secondary)
                                        Text(c.reason)
                                            .font(.caption)
                                            .foregroundStyle(c.eligible == true ? .green : .red)
                                        Spacer()
                                    }
                                }
                            }
                        } else {
                            Text("无合格 Hyleg 候选").foregroundStyle(.secondary)
                        }
                        if let a = hyleg.alcocoden, let selected = a.selected, !selected.isEmpty {
                            Divider()
                            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                                GridRow {
                                    Text("Alcocoden").foregroundStyle(.secondary)
                                    Text(selected).fontWeight(.bold)
                                }
                                if let dignity = a.dignity {
                                    GridRow {
                                        Text("尊贵").foregroundStyle(.secondary)
                                        Text(dignity)
                                    }
                                }
                            }
                            if let candidates = a.candidates, !candidates.isEmpty {
                                Divider()
                                Text("候选列表").font(.headline)
                                ForEach(candidates.prefix(7)) { c in
                                    HStack {
                                        Text("#\(c.rank ?? 0)").foregroundStyle(.secondary)
                                        Text(c.planet).frame(width: 44, alignment: .leading)
                                        Text(c.dignityAtHyleg).foregroundStyle(.secondary)
                                        Text(c.seesHyleg == true ? "✓view" : "✗view")
                                            .foregroundStyle(c.seesHyleg == true ? .green : .red)
                                        Text(c.ownConditionSummary ?? "").font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        if let warn = hyleg.warning {
                            Text(warn)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(4)
        }
    }
}
