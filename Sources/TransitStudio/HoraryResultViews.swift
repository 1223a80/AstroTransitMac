import SwiftUI

struct HoraryOverviewView: View {
    let result: HoraryResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                HorarySectionCard(title: "问题文本") {
                    Text(result.questionText.isEmpty ? "未填写问题文本" : result.questionText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                HorarySectionCard(title: "Horary 元数据") {
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                        GridRow {
                            Text("提问时间").foregroundStyle(.secondary)
                            Text(result.meta.askedLocal).monospacedDigit()
                        }
                        GridRow {
                            Text("UTC").foregroundStyle(.secondary)
                            Text(result.meta.askedUTC).textSelection(.enabled)
                        }
                        GridRow {
                            Text("地点").foregroundStyle(.secondary)
                            Text(result.meta.placeName)
                        }
                        GridRow {
                            Text("坐标").foregroundStyle(.secondary)
                            Text("\(result.meta.latitude, specifier: "%.4f"), \(result.meta.longitude, specifier: "%.4f")")
                                .monospacedDigit()
                        }
                        GridRow {
                            Text("设置").foregroundStyle(.secondary)
                            Text("\(result.meta.houseSystem), \(result.meta.zodiac), \(result.meta.boundsSystem), \(result.meta.triplicitySystem)")
                        }
                        GridRow {
                            Text("Sect").foregroundStyle(.secondary)
                            Text(result.meta.sect)
                        }
                        GridRow {
                            Text("Sun position").foregroundStyle(.secondary)
                            Text("\(result.meta.sunHorizonStatus) / \(result.planets.first(where: { $0.id == "SUN" })?.degreeText ?? "") / H\(result.planets.first(where: { $0.id == "SUN" })?.house ?? 0)")
                        }
                    }
                }

                HorarySectionCard(title: "Machine Summary") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        ForEach(result.machineSummary, id: \.self) { line in
                            Text(line)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HorarySectionCard(title: "House Rulers") {
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                        ForEach(result.houseRulers) { row in
                            GridRow {
                                Text("\(row.house)宫").foregroundStyle(.secondary)
                                Text("\(row.sign) / \(row.ruler)")
                            }
                        }
                    }
                }

                HorarySectionCard(title: "Moon Storyline") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        HStack {
                            Text("Moon 当前位置").foregroundStyle(.secondary)
                            Text("\(result.moonStoryline.currentPosition) / 第\(result.moonStoryline.currentHouse)宫")
                        }
                        if let last = result.moonStoryline.lastAspect {
                            Text("上一精确相位：\(last.aspectName) \(last.targetName) @ \(result.moonStoryline.lastAspectTime)")
                                .monospacedDigit()
                        }
                        HStack {
                            Text("VOC").foregroundStyle(.secondary)
                            Text(result.moonStoryline.voc ? "是" : "否")
                        }
                        Text("Criterion: \(result.moonVocCriterion)")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("离开星座").foregroundStyle(.secondary)
                            Text(result.moonStoryline.signExitLocal).monospacedDigit()
                        }
                        HStack {
                            Text("下一次换座").foregroundStyle(.secondary)
                            Text("\(result.moonStoryline.nextSign) @ \(result.moonStoryline.nextSignIngressTime)")
                                .monospacedDigit()
                        }
                        if let next = result.moonStoryline.nextAspect {
                            Text("当前星座内下一精确相位：\(next.aspectName) \(next.targetName) @ \(result.moonStoryline.nextAspectTime)")
                                .monospacedDigit()
                        }
                        if let firstAfterIngress = result.moonStoryline.firstAfterIngress {
                            Text("下一次换座后首相位：\(firstAfterIngress.aspectName) \(firstAfterIngress.targetName) @ \(result.moonStoryline.firstAfterIngressTime)")
                                .monospacedDigit()
                        }
                        if !result.moonStoryline.beforeSignExitAspects.isEmpty {
                            Divider()
                            ForEach(result.moonStoryline.beforeSignExitAspects.prefix(6)) { item in
                                Text("\(item.aspectName) \(item.targetName) @ \(item.exactLocal)")
                                    .monospacedDigit()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HorarySectionCard(title: "Significator Candidates") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        ForEach(result.significatorCandidates) { row in
                            VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                                Text("\(row.role)：\(row.planet) [\(row.source)]")
                                Text("\(row.position.isEmpty ? "-" : row.position) / \(row.house > 0 ? "H\(row.house)" : "-") / \(row.condition.isEmpty ? "-" : row.condition)")
                                    .font(TS.Font.label)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                HorarySectionCard(title: "Key Significator Links") {
                    if result.keySignificatorLinks.isEmpty {
                        Text("无")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                            ForEach(result.keySignificatorLinks) { row in
                                VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                                    Text(row.pair)
                                    Text("\(row.aspect) \(row.type) / orb \(row.orb.map { String(format: "%.2f°", $0) } ?? "-") / \(row.applying)")
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                    Text("Perfects before sign exit? \(row.perfectsBeforeSignExit ? "yes" : "no")")
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                    Text("Next perfection: \(row.nextPerfection.isEmpty ? "none" : row.nextPerfection)")
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    Text("Reason: \(row.perfectionReason)")
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                    if !row.reception.isEmpty {
                                        Text(row.reception)
                                            .font(TS.Font.label)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                HorarySectionCard(title: "Degree-Based Key Aspects") {
                    if result.degreeBasedKeyAspects.isEmpty {
                        Text("无")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                            ForEach(result.degreeBasedKeyAspects) { row in
                                Text("\(row.bodyA) \(row.aspect) \(row.bodyB) / orb \(row.orb.map { String(format: "%.2f°", $0) } ?? "-") / \(row.applying)\(row.exactTime.isEmpty ? "" : " / \(row.exactTime)")")
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                HorarySectionCard(title: "Planetary Speeds") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        ForEach(result.planetarySpeeds) { row in
                            Text("\(row.planet)：\(row.speed, specifier: "%.4f")°/day / \(row.speedState)\(row.station ? " / station" : "")")
                                .monospacedDigit()
                        }
                    }
                }

                HorarySectionCard(title: "Solar Condition") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        ForEach(result.solarCondition) { row in
                            Text("\(row.planet)：\(row.condition) / \(row.distanceFromSun, specifier: "%.2f")° from Sun")
                                .monospacedDigit()
                        }
                    }
                }

                HorarySectionCard(title: "Negative Receptions") {
                    if result.negativeReceptions.isEmpty {
                        Text("无")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                            ForEach(result.negativeReceptions) { row in
                                Text("\(row.receiver) -> \(row.received) / \(row.debility) / \(row.viaAspect) / \(row.strength)")
                            }
                        }
                    }
                }

                HorarySectionCard(title: "Lots Summary") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        ForEach(result.lotsSummary) { row in
                            VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                                Text("\(row.lot)：\(row.position) / 第\(row.house)宫 / \(row.ruler)")
                                Text(row.rulerCondition)
                                    .font(TS.Font.label)
                                    .foregroundStyle(.secondary)
                                if !row.keyNotes.isEmpty {
                                    Text(row.keyNotes)
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                HorarySectionCard(title: "Advanced Candidates") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        ForEach(result.advancedCandidates) { row in
                            VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                                HStack {
                                    Text(row.type)
                                        .font(TS.Font.sectionTitle)
                                    Spacer()
                                    Text(row.status)
                                        .foregroundStyle(row.status == "detected" ? .orange : .secondary)
                                }
                                Text(row.details)
                                    .font(TS.Font.label)
                                    .foregroundStyle(.secondary)
                                if !row.planets.isEmpty {
                                    Text("涉及：\(row.planets.joined(separator: "、"))")
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                }
                                if let translator = row.translator {
                                    Text("翻译者：\(translator)")
                                        .font(TS.Font.label)
                                }
                                if let collector = row.collector {
                                    Text("收集者：\(collector)")
                                        .font(TS.Font.label)
                                }
                                if let prohibitor = row.prohibitor {
                                    Text("禁止者：\(prohibitor)")
                                        .font(TS.Font.label)
                                }
                                if let frustrated = row.frustratedPlanet {
                                    Text("受阻行星：\(frustrated)")
                                        .font(TS.Font.label)
                                }
                            }
                        }
                    }
                }

                HorarySectionCard(title: "Radicality Flags") {
                    if result.radicalityFlags.isEmpty {
                        Text("无")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                            ForEach(result.radicalityFlags) { flag in
                                Text("\(flag.label) (\(flag.severity))")
                            }
                        }
                    }
                }
            }
            .padding(.trailing, 8)
        }
    }
}

struct HoraryDiagnosticsView: View {
    let result: HoraryResult

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xl) {
            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                GridRow {
                    Text("提问时间").foregroundStyle(.secondary)
                    Text(result.meta.askedLocal).monospacedDigit()
                }
                GridRow {
                    Text("UTC").foregroundStyle(.secondary)
                    Text(result.meta.askedUTC).textSelection(.enabled)
                }
                GridRow {
                    Text("地点").foregroundStyle(.secondary)
                    Text(result.meta.placeName)
                }
                GridRow {
                    Text("星历").foregroundStyle(.secondary)
                    Text(result.meta.ephemeris).textSelection(.enabled)
                }
            }

            WarningList(warnings: result.warnings)
            Spacer()
        }
        .padding(TS.Padding.resultContent)
    }
}

// MARK: - Lightweight section card (replaces GroupBox)
private struct HorarySectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
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
