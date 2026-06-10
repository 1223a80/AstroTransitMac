import SwiftUI

struct ClassicalTimingView: View {
    let timing: TimingSummary
    let planetaryReturns: [SolarReturnSummary]
    let circumambulations: [Circumambulation]?
    let birthdayTransition: BirthdayTransition?
    let activatedLordFocus: ActivatedLordFocus?

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
            LazyVStack(alignment: .leading, spacing: TS.Spacing.xl) {
                // Birthday Transition card
                if let transition = birthdayTransition, transition.detected {
                    birthdayTransitionCard(transition)
                }

                // Activated Lord Focus card
                if let lordFocus = activatedLordFocus {
                    activatedLordCard(lordFocus)
                }

                ActiveOverviewView(
                    timing: timing,
                    planetaryReturns: planetaryReturns,
                    circumambulations: circumambulations
                )

                TimingSectionBox(title: "Annual Profection") {
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: 8) {
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
                            .font(TS.Font.sectionTitle)
                        Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: 8) {
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
                    VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                        Text("逻辑链")
                            .font(TS.Font.sectionTitle)
                        ForEach(timing.profection.logicSteps, id: \.self) { step in
                            Text(step)
                        }
                    }
                }

                TimingSectionBox(title: "Firdaria") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        Text("\(timing.firdaria.ruler) \(timing.firdaria.level)")
                            .font(TS.Font.sectionTitle)
                        Text("\(timing.firdaria.startLocal) - \(timing.firdaria.endLocal)")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        if !timing.firdaria.notes.isEmpty {
                            Text(timing.firdaria.notes.joined(separator: "、"))
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                        }
                        if let next = timing.firdaria.nextTransition {
                            Text("下一次转换：\(next)")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        if let houses = timing.firdaria.activatedHouses, !houses.isEmpty {
                            Text("激活宫位：\(houses.map { "第\($0)宫" }.joined(separator: "、"))")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                        }
                        if let currentSub = timing.firdaria.currentSubPeriod {
                            Text("当前次限：\(currentSub.ruler) \(currentSub.startLocal) - \(currentSub.endLocal)")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        if let method = timing.firdaria.method {
                            Text("\(method) / \(timing.firdaria.sourceTradition ?? "")")
                                .font(TS.Font.detail)
                                .foregroundStyle(.secondary)
                        }

                        if let subPeriods = timing.firdaria.subPeriods, !subPeriods.isEmpty {
                            Divider()
                            Text("次限")
                                .font(TS.Font.sectionTitle)
                            ForEach(subPeriods) { sub in
                                HStack(alignment: .top, spacing: TS.Spacing.lg) {
                                    Text(sub.ruler)
                                        .frame(width: 44, alignment: .leading)
                                    Text(sub.startLocal)
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    Text("-")
                                        .foregroundStyle(.secondary)
                                    Text(sub.endLocal)
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    Spacer()
                                    Text(String(format: "%.1f%%", sub.fraction * 100))
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                TimingSectionBox(title: "Decennials") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        Text("\(timing.decennials.ruler) \(timing.decennials.level)")
                            .font(TS.Font.sectionTitle)
                        Text("\(timing.decennials.startLocal) - \(timing.decennials.endLocal)")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        if !timing.decennials.notes.isEmpty {
                            Text(timing.decennials.notes.joined(separator: "、"))
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                        }

                        if let subPeriods = timing.decennials.subPeriods, !subPeriods.isEmpty {
                            Divider()
                            Text("子限")
                                .font(TS.Font.sectionTitle)
                            ForEach(subPeriods) { sub in
                                HStack(alignment: .top, spacing: TS.Spacing.lg) {
                                    Text(sub.ruler)
                                        .frame(width: 44, alignment: .leading)
                                    Text(sub.startLocal)
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    Text("-")
                                        .foregroundStyle(.secondary)
                                    Text(sub.endLocal)
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    Spacer()
                                    Text(String(format: "%.1f%%", sub.fraction * 100))
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                TimingSectionBox(title: "Zodiacal Releasing") {
                    VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                        ForEach(timing.zodiacalReleasing) { zr in
                            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                                Text(zr.technique)
                                    .font(TS.Font.sectionTitle)
                                Text("\(zr.ruler) \(zr.sign ?? "")")
                                Text("\(zr.startLocal) - \(zr.endLocal)")
                                    .font(TS.Font.label)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                if let next = zr.nextTransition {
                                    Text("下一次转换：\(next)")
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                if let score = zr.importanceScore {
                                    Text("重要性评分：\(score)")
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                }
                                if let method = zr.method {
                                    Text("\(method) / \(zr.sourceTradition ?? "")")
                                        .font(TS.Font.detail)
                                        .foregroundStyle(.secondary)
                                }

                                if let lob = zr.loosingOfBond, lob {
                                    Label(zr.loosingOfBondDetail ?? "Loosing of the Bond", systemImage: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                        .font(TS.Font.label)
                                }

                                if let l2 = zr.l2Periods, !l2.isEmpty {
                                    Divider()
                                    Text("L2 子周期")
                                        .font(TS.Font.body)
                                        .foregroundStyle(.secondary)
                                    ForEach(l2) { period in
                                        HStack(alignment: .top, spacing: TS.Spacing.lg) {
                                            Text(period.isActive == true ? "▶" : " ")
                                                .foregroundStyle(.blue)
                                            Text(period.ruler)
                                                .frame(width: 44, alignment: .leading)
                                            Text(period.sign)
                                                .frame(width: 44, alignment: .leading)
                                            Text("\(period.startLocal) - \(period.endLocal)")
                                                .font(TS.Font.label)
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }

                                        if let l3 = period.subPeriods, !l3.isEmpty, period.isActive == true {
                                            ForEach(l3) { l3p in
                                                HStack(alignment: .top, spacing: TS.Spacing.lg) {
                                                    Text("   ")
                                                    Text(l3p.isActive == true ? "▶" : " ")
                                                        .foregroundStyle(.green)
                                                    Text(l3p.ruler)
                                                        .frame(width: 44, alignment: .leading)
                                                    Text(l3p.sign)
                                                        .frame(width: 44, alignment: .leading)
                                                    Text("\(l3p.startLocal) - \(l3p.endLocal)")
                                                        .font(TS.Font.detail)
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
                    VStack(alignment: .leading, spacing: TS.Spacing.lg) {
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
                                VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                                    Text("\(summary.title)：\(summary.noHitInUserWindow == true ? "未在搜索窗口内找到" : "无数据")")
                                        .foregroundStyle(.secondary)
                                    if let window = summary.suggestedWindow {
                                        Text(window)
                                            .font(TS.Font.label)
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
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.xl, verticalSpacing: 6) {
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
                                    .font(TS.Font.detail)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                Text(item.technique ?? "")
                                    .frame(width: 60, alignment: .leading)
                                Text(item.title)
                                    .frame(width: 120, alignment: .leading)
                                Text(item.startLocal)
                                    .font(TS.Font.label)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 120, alignment: .leading)
                                    .monospacedDigit()
                                Text(item.startLocal == item.endLocal ? "" : item.endLocal)
                                    .font(TS.Font.label)
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

    // MARK: - Birthday Transition Card

    @ViewBuilder
    private func birthdayTransitionCard(_ transition: BirthdayTransition) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Label("生日过渡期", systemImage: "calendar.badge.exclamationmark")
                .font(TS.Font.sectionTitle)
                .foregroundStyle(TS.SemanticColor.warning)

            Text(transition.note)
                .font(TS.Font.body)
                .textSelection(.enabled)

            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.xl, verticalSpacing: TS.Spacing.md) {
                if let age = transition.profectionAge {
                    GridRow {
                        Text("小限年龄").font(TS.Font.label).foregroundStyle(.secondary)
                        Text("\(age)").font(TS.Font.mono).monospacedDigit()
                    }
                }
                if let start = transition.profectionStart {
                    GridRow {
                        Text("小限起始").font(TS.Font.label).foregroundStyle(.secondary)
                        Text(start).font(TS.Font.mono).textSelection(.enabled)
                    }
                }

                if let current = transition.currentSolarReturn {
                    GridRow {
                        Text("当前太阳回归").font(TS.Font.label).foregroundStyle(.secondary)
                        Text(current).font(TS.Font.mono).textSelection(.enabled)
                    }
                }
                if let next = transition.nextSolarReturn {
                    GridRow {
                        Text("下次太阳回归").font(TS.Font.label).foregroundStyle(.secondary)
                        Text(next).font(TS.Font.mono).textSelection(.enabled)
                    }
                }
            }
        }
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.warning.opacity(TS.Opacity.muted))
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
    }

    // MARK: - Activated Lord Focus Card

    @ViewBuilder
    private func activatedLordCard(_ lord: ActivatedLordFocus) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack {
                Label("年主聚焦: \(lord.lordName)", systemImage: "star.circle")
                    .font(TS.Font.sectionTitle)
                Spacer()
                if let score = lord.natalScore {
                    Text("评分 \(score)")
                        .font(TS.Font.label)
                        .padding(.horizontal, TS.Padding.chipHorizontal)
                        .padding(.vertical, TS.Spacing.xs)
                        .background(TS.SemanticColor.accentSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.chip))
                }
            }

            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.xl, verticalSpacing: TS.Spacing.md) {
                if let condition = lord.natalCondition {
                    GridRow {
                        Text("本命状态").font(TS.Font.label).foregroundStyle(.secondary)
                        Text(condition).font(TS.Font.body).textSelection(.enabled)
                    }
                }
                if let house = lord.natalHouse {
                    GridRow {
                        Text("本命宫位").font(TS.Font.label).foregroundStyle(.secondary)
                        Text("第 \(house) 宫").font(TS.Font.body).textSelection(.enabled)
                    }
                }
            }

            if let returnTitle = lord.returnTitle {
                VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                    Text(returnTitle).font(TS.Font.body).textSelection(.enabled)
                    if let exact = lord.returnExactLocal {
                        Text(exact).font(TS.Font.mono).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            }

            if let keywords = lord.keywords, !keywords.isEmpty {
                Text(keywords)
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
    }
}

// MARK: - Timing 卡片与列表组件
struct TimingSectionBox<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text(title)
                .font(TS.Font.sectionTitle)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TS.Padding.sectionGap)
        .background(TS.SemanticColor.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
    }
}

struct TimingAngleList: View {
    let points: [ClassicalPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text("返照角点")
                .font(TS.Font.sectionTitle)
            ForEach(points) { point in
                HStack(alignment: .top, spacing: TS.Spacing.lg) {
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
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text("返照七政")
                .font(TS.Font.sectionTitle)
            ForEach(planets) { planet in
                HStack(alignment: .top, spacing: TS.Spacing.lg) {
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
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: 8) {
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
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    Text("宫位叠加")
                        .font(TS.Font.sectionTitle)
                    ForEach(overlay) { item in
                        HStack(alignment: .top, spacing: TS.Spacing.lg) {
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
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text("返照与本命交叉")
                .font(TS.Font.sectionTitle)
            ForEach(aspects.prefix(12)) { aspect in
                HStack(alignment: .top, spacing: TS.Spacing.lg) {
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
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text(title)
                .font(TS.Font.sectionTitle)
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: TS.Spacing.lg) {
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

