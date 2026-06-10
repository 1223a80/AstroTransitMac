import SwiftUI

// MARK: - 当前激活技法总览
struct ActiveOverviewView: View {
    let timing: TimingSummary
    let planetaryReturns: [SolarReturnSummary]
    let circumambulations: [Circumambulation]?

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("当前激活技法总览")
                .font(TS.Font.sectionTitle)

                Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
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
        .padding(TS.Padding.sectionGap)
        .background(TS.SemanticColor.accentSubtle)
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
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
                .font(TS.Font.label).foregroundStyle(.secondary).monospacedDigit()
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
                    .font(TS.Font.label).foregroundStyle(.secondary).monospacedDigit()
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
                        .foregroundStyle(.orange).font(TS.Font.label)
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
                    .font(TS.Font.label)
            }
        }
    }
}

struct ClassicalJudgementView: View {
    let planets: [ClassicalPlanetRow]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TS.Spacing.xl) {
                ForEach(planets) { planet in
                    TimingSectionBox(title: "\(planet.name) 评分 \(planet.score)\(planet.scoreLabel.map { " (\($0))" } ?? "")") {
                        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                            if !planet.scoreBreakdown.isEmpty {
                                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                                    Text("评分明细")
                                        .font(TS.Font.sectionTitle)
                                    ForEach(planet.scoreBreakdown) { item in
                                        HStack(alignment: .top, spacing: TS.Spacing.lg) {
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
                                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                                    Text("三分主星评估")
                                        .font(TS.Font.sectionTitle)
                                    ForEach(triplicityDetails) { detail in
                                        HStack(alignment: .top, spacing: TS.Spacing.lg) {
                                            Text(detail.label)
                                                .frame(width: 44, alignment: .leading)
                                            Text(detail.ruler)
                                                .frame(width: 44, alignment: .leading)
                                            Text(detail.status)
                                                .frame(width: 24, alignment: .leading)
                                                .foregroundStyle(detail.status == "强" ? .green : detail.status == "中" ? .orange : .red)
                                            Text(detail.notes.joined(separator: "、"))
                                                .font(TS.Font.label)
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

