import Foundation

extension MarkdownExportBuilder {
    static func timingSubsection(_ kind: String, _ timing: TimingSummary, _ returns: [SolarReturnSummary]) -> [String] {
        var lines: [String] = []
        switch kind {
        case "profections": lines += profectionSection(timing)
        case "firdaria": lines += firdariaSection(timing)
        case "decennials": lines += decennialsSection(timing)
        case "zr": lines += zrSection(timing)
        case "returns": lines += returnsSection(returns)
        default: break
        }
        return lines
    }

    static func profectionSection(_ timing: TimingSummary) -> [String] {
        var lines: [String] = ["", "### Annual Profection", ""]
        let p = timing.profection
        lines.append("- 年龄：\(p.age)")
        lines.append("- 宫位：\(p.house) (\(p.sign))")
        lines.append("- 主星：\(p.lord)")
        if !p.lordCondition.isEmpty { lines.append("- 主星状态：\(p.lordCondition)") }
        lines.append("- \(p.startLocal) → \(p.endLocal)")
        return lines
    }

    static func firdariaSection(_ timing: TimingSummary) -> [String] {
        let f = timing.firdaria
        return ["", "### Firdaria", "", "- 主限：\(f.ruler)", "- \(f.startLocal) → \(f.endLocal)"]
    }

    static func decennialsSection(_ timing: TimingSummary) -> [String] {
        let d = timing.decennials
        return ["", "### Decennials", "", "- 主限：\(d.ruler)", "- \(d.startLocal) → \(d.endLocal)"]
    }

    static func zrSection(_ timing: TimingSummary) -> [String] {
        guard !timing.zodiacalReleasing.isEmpty else { return [] }
        var lines = ["", "### Zodiacal Releasing", ""]
        for z in timing.zodiacalReleasing {
            lines.append("- \(z.technique) \(z.level): \(z.sign ?? "")")
        }
        return lines
    }

    static func returnsSection(_ returns: [SolarReturnSummary]) -> [String] {
        guard !returns.isEmpty else { return [] }
        var lines = ["", "### 返照", ""]
        for r in returns {
            let cur = r.currentCycleReturn
            lines.append("- \(r.title): \(cur?.exactLocal ?? "N/A")")
        }
        return lines
    }

    static func activeOverviewSection(_ result: ClassicalResult) -> [String] {
        let timing = result.timing
        var lines = [
            "## 当前激活技法总览",
            "",
            "### 年小限",
            "- 年龄：\(timing.profection.age)岁",
            "- 区间：\(timing.profection.startLocal) - \(timing.profection.endLocal)",
            "- 宫位：\(timing.profection.house)宫 \(timing.profection.sign)",
            "- 年主：\(timing.profection.lord)",
            "- 状态：\(timing.profection.lordCondition.isEmpty ? "未取得年主状态" : timing.profection.lordCondition)",
            "- 激活宫行星：\(timing.profection.activatedPlanets.isEmpty ? "无" : timing.profection.activatedPlanets.joined(separator: "、"))",
            "",
        ]

        if let monthly = timing.profection.monthly {
            lines += [
                "### 月小限",
                "- 月份：第 \(monthly.month) 月",
                "- 星座：\(monthly.sign)",
                "- 月主：\(monthly.lord)",
            ]
            if let cond = monthly.lordCondition, !cond.isEmpty {
                lines.append("- 月主状态：\(cond)")
            }
            lines.append("")
        }

        lines += [
            "### Firdaria",
            "- 主限：\(timing.firdaria.ruler)",
            "- 区间：\(timing.firdaria.startLocal) - \(timing.firdaria.endLocal)",
        ]
        if let next = timing.firdaria.nextTransition {
            lines.append("- 下次转换：\(next)")
        }
        if let currentSub = timing.firdaria.currentSubPeriod {
            lines.append("- 当前次限：\(currentSub.ruler)（\(currentSub.startLocal) - \(currentSub.endLocal)）")
        }
        lines.append("")

        lines += [
            "### Decennials",
            "- 主限：\(timing.decennials.ruler)",
            "- 区间：\(timing.decennials.startLocal) - \(timing.decennials.endLocal)",
            "",
        ]

        lines += ["### Zodiacal Releasing"]
        for zr in timing.zodiacalReleasing {
            lines += [
                "- \(zr.technique)：\(zr.ruler) \(zr.sign ?? "")（L\(zr.currentActiveLevel ?? "1")）",
                "  - 区间：\(zr.startLocal) - \(zr.endLocal)",
            ]
            if let lob = zr.loosingOfBond, lob, let detail = zr.loosingOfBondDetail {
                lines.append("  - ⚠ \(detail)")
            }
        }
        lines.append("")

        if let circs = result.circumambulations, !circs.isEmpty {
            lines += ["### 沿界推进"]
            for circ in circs {
                lines.append("- 当前界主：\(circ.currentRuler)")
                if let info = circ.currentBoundInfo {
                    lines.append("  - \(info)")
                }
            }
            lines.append("")
        }

        if let solarReturn = result.planetaryReturns.first(where: { $0.bodyID == "SUN" }) {
            if let current = solarReturn.currentCycleReturn {
                lines += [
                    "### 当前 Solar Return",
                    "- 精确时间：\(current.exactLocal)",
                    "- UTC：\(current.exactUTC)",
                    "- ASC：\(current.ascendant)",
                    "- MC：\(current.midheaven)",
                    "",
                ]
            }
            if let next = solarReturn.nextReturn {
                lines += [
                    "### 下一 Solar Return",
                    "- 精确时间：\(next.exactLocal)",
                    "- UTC：\(next.exactUTC)",
                    "- ASC：\(next.ascendant)",
                    "- MC：\(next.midheaven)",
                    "",
                ]
            }
        }

        let nearby = timing.timeline.filter { $0.kind == "event" }
        if !nearby.isEmpty {
            lines += ["### 近期事件"]
            for event in nearby {
                lines.append("- \(event.title)：\(event.startLocal)")
            }
            lines.append("")
        }

        if let ambiguity = result.ambiguity {
            lines += [
                "### 技法主星汇总",
                "- 置信度：\(ambiguity.confidence)",
            ]
            for key in ambiguity.techniqueRulers.keys.sorted() {
                if let value = ambiguity.techniqueRulers[key], !value.isEmpty {
                    lines.append("- \(key)：\(value)")
                }
            }
            if !ambiguity.conflictingSignals.isEmpty {
                lines.append("- 冲突信号：")
                for signal in ambiguity.conflictingSignals {
                    lines.append("  - \(signal)")
                }
            }
            lines.append("")
        }

        if let assumptions = result.calculationAssumptions {
            let items: [(String, String?)] = [
                ("cazimi_orb_arcmin", assumptions.cazimiOrbArcmin.map { String($0) }),
                ("combust_orb_deg", assumptions.combustOrbDeg.map { String($0) }),
                ("under_beams_orb_deg", assumptions.underBeamsOrbDeg.map { String($0) }),
                ("naibod_rate", assumptions.naibodRate.map { String($0) }),
                ("primary_directions_method", assumptions.primaryDirectionsMethod),
                ("modern_planets_excluded_from_scoring", assumptions.modernPlanetsExcludedFromScoring.map { $0 ? "true" : "false" }),
                ("scoring_includes_conditioning", assumptions.scoringIncludesConditioning.map { $0 ? "true" : "false" }),
                ("sign_based_receptions_downgraded", assumptions.signBasedReceptionsDowngraded.map { $0 ? "true" : "false" }),
                ("lunar_return_is_next_after_reference", assumptions.lunarReturnIsNextAfterReference.map { $0 ? "true" : "false" }),
                ("return_schema", assumptions.returnSchema),
            ]
            let rows = items.compactMap { label, value in
                value.map { "- \(label)：\($0)" }
            }
            if !rows.isEmpty {
                lines += ["### 计算假设"]
                lines += rows
                lines.append("")
            }
        }

        return lines
    }

    static func timingSection(_ timing: TimingSummary, planetaryReturns: [SolarReturnSummary]) -> [String] {
        var lines = [
            "## 时间技法",
            "",
            "### 年小限",
            "",
            "- 年龄：\(timing.profection.age)",
            "- 年限区间：\(timing.profection.startLocal) - \(timing.profection.endLocal)",
            "- 宫位：\(timing.profection.house)",
            "- 星座：\(timing.profection.sign)",
            "- 年主：\(timing.profection.lord)",
            "- 年主状态：\(timing.profection.lordCondition)",
            "- 激活宫内行星：\(timing.profection.activatedPlanets.isEmpty ? "无" : timing.profection.activatedPlanets.joined(separator: "、"))",
            "- 逻辑链：",
            ""
        ]
        lines += timing.profection.logicSteps.map { "  \($0)" }

        lines += [
            "",
            "### Firdaria",
            "",
            periodLine(timing.firdaria),
        ]
        if let subs = timing.firdaria.subPeriods, !subs.isEmpty {
            lines += [
                "",
                "#### 次限列表",
                "",
                "| 主星 | 开始 | 结束 | 占比 |",
                "| --- | --- | --- | ---: |",
            ]
            for sub in subs {
                let isCurrent = timing.firdaria.currentSubPeriod?.id == sub.id
                lines.append("| \(sub.ruler)\(isCurrent ? " ◀" : "") | \(sub.startLocal) | \(sub.endLocal) | \(String(format: "%.1f%%", sub.fraction * 100)) |")
            }
        }
        lines.append("")

        lines += [
            "### Decennials",
            "",
            periodLine(timing.decennials),
        ]
        if let subs = timing.decennials.subPeriods, !subs.isEmpty {
            lines += [
                "",
                "#### 子限列表",
                "",
                "| 主星 | 开始 | 结束 | 占比 |",
                "| --- | --- | --- | ---: |",
            ]
            for sub in subs {
                lines.append("| \(sub.ruler) | \(sub.startLocal) | \(sub.endLocal) | \(String(format: "%.1f%%", sub.fraction * 100)) |")
            }
        }
        lines.append("")

        lines += [
            "### Zodiacal Releasing",
            "",
        ]
        for zr in timing.zodiacalReleasing {
            lines.append(zrLine(zr))
            if let lob = zr.loosingOfBond, lob {
                lines.append("  - ⚠ \(zr.loosingOfBondDetail ?? "Loosing of the Bond")（\(zr.loosingOfBondLevel ?? "L1")）")
            }
            if let l2 = zr.l2Periods, !l2.isEmpty {
                lines.append("")
                lines.append("  **L2 子周期**")
                lines.append("")
                lines.append("  | 主星 | 星座 | 开始 | 结束 | 状态 |")
                lines.append("  | --- | --- | --- | --- | --- |")
                for p in l2 {
                    let status = p.isActive == true ? "当前" : ""
                    lines.append("  | \(p.ruler) | \(p.sign) | \(p.startLocal) | \(p.endLocal) | \(status) |")
                }
                if let activeL2 = l2.first(where: { $0.isActive == true }), let l3 = activeL2.subPeriods, !l3.isEmpty {
                    lines.append("")
                    lines.append("  **L3 子周期**")
                    lines.append("")
                    lines.append("  | 主星 | 星座 | 开始 | 结束 | 状态 |")
                    lines.append("  | --- | --- | --- | --- | --- |")
                    for p in l3 {
                        let status = p.isActive == true ? "当前" : ""
                        lines.append("  | \(p.ruler) | \(p.sign) | \(p.startLocal) | \(p.endLocal) | \(status) |")
                    }
                }
            }
            lines.append("")
        }

        lines += ["### 返照", ""]
        for summary in planetaryReturns {
            let snapshots = returnSnapshotVariants(summary)
            if snapshots.isEmpty {
                lines.append("- \(summary.title)：未在搜索窗口内找到")
            } else {
                for item in snapshots {
                    lines += returnSnapshotSection(item.title, item.snapshot)
                }
            }
        }
        lines.append("")
        return lines
    }

    static func timelineTableSection(_ items: [TimingTimelineItem]) -> [String] {
        guard !items.isEmpty else { return [] }
        var lines = [
            "## 统一时间线",
            "",
            "| 分层 | 技法 | 标题 | 开始 | 结束 | 类型 |",
            "| --- | --- | --- | --- | --- | --- |"
        ]
        for item in items {
            let tech = item.technique ?? ""
            let kind = item.kind == "event" ? "事件" : "周期"
            let end = item.startLocal == item.endLocal ? "" : item.endLocal
            let layer = item.layer ?? ""
            let layerName: String
            switch layer {
            case "active_periods": layerName = "活跃周期"
            case "active_returns": layerName = "有效返照"
            case "events": layerName = "事件"
            case "historical": layerName = "历史参考"
            default: layerName = layer
            }
            lines.append("| \(layerName) | \(tech) | \(item.title) | \(item.startLocal) | \(end) | \(kind) |")
        }
        lines.append("")
        return lines
    }

    static func returnSnapshotSection(_ title: String, _ snap: ReturnChartSnapshot) -> [String] {
        var lines = [
            "",
            "### \(title)",
            "",
            "- 精确时间：\(snap.exactLocal)",
            "- 精确 UTC：\(snap.exactUTC)",
            "- 上升：\(snap.ascendant)",
            "- 中天：\(snap.midheaven)",
            "- 昼夜：\(snap.sect)",
            "- 宫制：\(snap.houseSystem)",
        ]
        if let ruler = snap.returnChartRuler {
            lines.append("- 返照盘主星：\(ruler)")
        }
        if let retHouse = snap.returnAscInNatalHouse, retHouse > 0 {
            lines.append("- 返照 ASC 在本命：第 \(retHouse) 宫")
        }
        if let overlay = snap.houseOverlay, !overlay.isEmpty {
            lines += [
                "",
                "#### 宫位叠加",
                "",
                "| 行星 | 返照宫位 | 本命宫位 |",
                "| --- | ---: | ---: |",
            ]
            for item in overlay {
                lines.append("| \(item.planet) | \(item.returnHouse) | \(item.natalHouse) |")
            }
        }
        if !snap.planets.isEmpty {
            lines += [
                "",
                "#### 返照七政",
                "",
                "| 星体 | 位置 | 宫位 | 运动 | 评分 |",
                "| --- | --- | ---: | --- | ---: |",
            ]
            lines += snap.planets.map {
                let label = $0.scoreLabel.map { " (\($0))" } ?? ""
                return "| \($0.name) | \($0.degreeText) | \($0.house) | \($0.motion) | \($0.score)\(label) |"
            }
        }
        if !snap.natalCrossAspects.isEmpty {
            lines += [
                "",
                "#### 返照与本命交叉",
                "",
                "| 返照行星 | 相位 | 本命行星 | 容许度 | 入离 |",
                "| --- | --- | --- | ---: | --- |",
            ]
            for a in snap.natalCrossAspects {
                lines.append("| \(a.leftBodyName) | \(a.aspect) | \(a.rightBodyName) | \(a.orb.map { degree($0, digits: 2) } ?? "星座") | \(a.applying ?? "") |")
            }
        }
        lines.append("")
        return lines
    }

    static func returnSnapshotVariants(_ summary: SolarReturnSummary) -> [(title: String, snapshot: ReturnChartSnapshot)] {
        var rows: [(title: String, snapshot: ReturnChartSnapshot)] = []
        if let previous = summary.previousReturn {
            rows.append((title: "Previous \(summary.title)（上一次）", snapshot: previous))
        }
        if let current = summary.currentCycleReturn {
            rows.append((title: "Current \(summary.title)（当前生效）", snapshot: current))
        }
        if let next = summary.nextReturn {
            rows.append((title: "Next \(summary.title)（下一次）", snapshot: next))
        }
        return rows
    }

    static func periodLine(_ period: PeriodSummary) -> String {
        "- \(period.technique) \(period.level)：\(period.ruler)\(period.sign.map { " \($0)" } ?? "")，\(period.startLocal) - \(period.endLocal)；\(period.notes.joined(separator: "、"))"
    }

    static func zrLine(_ zr: ZRSummary) -> String {
        var line = "- \(zr.technique)：\(zr.ruler) \(zr.sign ?? "")，\(zr.startLocal) - \(zr.endLocal)"
        if let lob = zr.loosingOfBond, lob {
            line += " ⚠ Loosing of the Bond"
        }
        return line
    }
}
