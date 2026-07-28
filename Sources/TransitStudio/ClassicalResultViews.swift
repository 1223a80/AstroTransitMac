import SwiftUI

struct ClassicalPlanetTableView: View {
    let planets: [ClassicalPlanetRow]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("七政古典状态")
                .font(TS.Font.sectionTitle)
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
            .tsTableStyle()
        }
    }
}

struct ClassicalPointsView: View {
    let angles: [ClassicalPoint]
    let lots: [ClassicalPoint]
    let experimentalLots: [ClassicalPoint]?

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xl) {
            Text("角点")
                .font(TS.Font.sectionTitle)
            PointTable(points: angles)
            Text("Hermetic Lots")
                .font(TS.Font.sectionTitle)
            PointTable(points: lots)
            if let expLots = experimentalLots, !expLots.isEmpty {
                Text("实验性 Lots（来源未确认）")
                    .font(TS.Font.sectionTitle)
                    .foregroundStyle(.orange)
                Text("以下 Lots 公式来源不确定，仅供参考")
                    .font(TS.Font.label)
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
            .tsTableStyle()
        } else {
            Table(points) {
                TableColumn("点") { Text($0.name) }
                TableColumn("位置") { Text($0.degreeText).monospacedDigit() }
                TableColumn("宫") { Text("\($0.house)") }
                TableColumn("主星") { Text($0.ruler) }
                TableColumn("公式") { Text($0.formula ?? "") }
            }
            .tsTableStyle()
        }
    }
}

struct ClassicalHouseTableView: View {
    let houses: [HouseRow]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("宫位")
                .font(TS.Font.sectionTitle)
            Table(houses) {
                TableColumn("宫") { Text("\($0.house)") }
                TableColumn("宫头") { Text($0.cuspText).monospacedDigit() }
                TableColumn("星座") { Text($0.sign) }
                TableColumn("主星") { Text($0.ruler) }
            }
            .tsTableStyle()
        }
    }
}

struct ClassicalAspectReceptionView: View {
    let aspects: [ClassicalAspectRow]
    let receptions: [ReceptionRow]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xl) {
            Text("古典相位")
                .font(TS.Font.sectionTitle)
            Table(aspects) {
                TableColumn("A") { Text($0.bodyA) }
                TableColumn("相位") { Text($0.aspect) }
                TableColumn("B") { Text($0.bodyB) }
                TableColumn("类型") { Text($0.aspectType) }
                TableColumn("容许") { Text(degree($0.orb)) }
                TableColumn("入离") { Text($0.applying ?? "") }
            }
            .tsTableStyle()

            Text("接纳")
                .font(TS.Font.sectionTitle)
            Table(receptions) {
                TableColumn("接纳者") { Text($0.receiver) }
                TableColumn("被接纳") { Text($0.received) }
                TableColumn("尊贵") { Text($0.dignity) }
                TableColumn("经由相位") { Text($0.viaAspect) }
                TableColumn("强度") { Text($0.strengthLabel ?? "") }
            }
            .tsTableStyle()
        }
    }

    private func degree(_ value: Double?) -> String {
        guard let value else {
            return ""
        }
        return String(format: "%.2f°", value)
    }
}
struct AntisciaView: View {
    let antiscia: [AntisciaRow]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("映点 / 反映点")
                .font(TS.Font.sectionTitle)
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
            .tsTableStyle()
        }
    }
}

struct CircumambulationsView: View {
    let circumambulations: [Circumambulation]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("Circumambulations through the Bounds（沿界推进）")
                .font(TS.Font.sectionTitle)
            if circumambulations.isEmpty {
                Text("无数据").foregroundStyle(.secondary)
            } else {
                ForEach(circumambulations) { circ in
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        HStack {
                            Text("系统：\(circ.system)")
                            Text("当前界主：\(circ.currentRuler)")
                                .fontWeight(.bold)
                        }
                        Text("Naibod rate：\(String(format: "%.4f", circ.naibodRate))°/年")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                        if let info = circ.currentBoundInfo {
                            Text("当前推运位置：\(info)")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                        }
                        if let lord = circ.boundLord, let sign = circ.boundSign,
                           let sDeg = circ.boundStartDegree, let eDeg = circ.boundEndDegree {
                            Text(
                                "当前宫限：\(sign) \(classicalBoundDegreeText(sDeg))°"
                                + " – \(classicalBoundDegreeText(eDeg))°，主星 \(lord)"
                            )
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                        }
                        if let start = circ.boundStartDate, let end = circ.boundEndDate, !start.isEmpty {
                            Text("区间：\(start) → \(end)")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                        }
                        if let pos = circ.currentDirectedPosition {
                            Text("Directed ASC：\(String(format: "%.4f", pos))°")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                        Table(circ.boundaries.prefix(30)) {
                            TableColumn("星座") { Text($0.sign) }
                            TableColumn("度数") { row in
                                if let sDeg = row.startDegree {
                                    Text(
                                        "\(classicalBoundDegreeText(sDeg))°"
                                        + "–\(classicalBoundDegreeText(row.endDegree))°"
                                    )
                                } else {
                                    Text("\(classicalBoundDegreeText(row.endDegree))°")
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
                        .tsTableStyle()
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
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("Primary Directions (主限法)")
                .font(TS.Font.sectionTitle)
            Text("共 \(directions.count) 条方向")
                .font(TS.Font.label)
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
                                .font(TS.Font.detail)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("")
                        }
                    }
                }
                .tsTableStyle()
            }
        }
    }
}

struct ClassicalDiagnosticsView: View {
    let result: ClassicalResult

    var body: some View {
        ScrollView {
        LazyVStack(alignment: .leading, spacing: TS.Spacing.xl) {
            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: 8) {
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
                TimingSectionBox(title: "小行星处理") {
                    Text(asteroidWarning)
                        .textSelection(.enabled)
                }
            }

            WarningList(warnings: result.warnings)

            if let errors = result.sectionErrors, !errors.isEmpty {
                SectionErrorList(errors: errors)
            }

            if let ambiguity = result.ambiguity {
                TimingSectionBox(title: "技法主星汇总") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
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
                                    .font(TS.Font.label)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let syzygy = result.prenatalSyzygy {
                TimingSectionBox(title: "产前朔望 (Prenatal Syzygy)") {
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: 6) {
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
                                Text(note).font(TS.Font.label)
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
                                Text(mv).font(TS.Font.label)
                            }
                        }
                    }
                }
            }

            if let almuten = result.almutenFiguris {
                TimingSectionBox(title: "Almuten Figuris (全盘最尊贵行星)") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
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
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if let hyleg = result.hylegAlcocoden {
                TimingSectionBox(title: "Hyleg / Alcocoden (生命主星)") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        if let h = hyleg.hyleg, let selected = h.selected, !selected.isEmpty {
                            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: 6) {
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
                                Text("候选列表").font(TS.Font.sectionTitle)
                                ForEach(candidates) { c in
                                    HStack {
                                        Text(c.eligible == true ? "✓" : "✗")
                                        Text(c.name).frame(width: 44, alignment: .leading)
                                        Text("H\(c.house ?? 0)").foregroundStyle(.secondary)
                                        Text(c.reason)
                                            .font(TS.Font.label)
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
                            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: 6) {
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
                                Text("候选列表").font(TS.Font.sectionTitle)
                                ForEach(candidates.prefix(7)) { c in
                                    HStack {
                                        Text("#\(c.rank ?? 0)").foregroundStyle(.secondary)
                                        Text(c.planet).frame(width: 44, alignment: .leading)
                                        Text(c.dignityAtHyleg).foregroundStyle(.secondary)
                                        Text(c.seesHyleg == true ? "✓view" : "✗view")
                                            .foregroundStyle(c.seesHyleg == true ? .green : .red)
                                        Text(c.ownConditionSummary ?? "").font(TS.Font.label).foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        if let warn = hyleg.warning {
                            Text(warn)
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(TS.Padding.resultContent)
        }
    }
}
