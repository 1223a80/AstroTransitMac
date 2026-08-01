import Foundation

extension MarkdownExportBuilder {
    /// Human-readable Horary report for copying, saving, and manual LLM handoff.
    ///
    /// The backend v2.1 packet remains lossless through JSON export. Markdown is
    /// intentionally selective: it presents decision-relevant facts as tables
    /// instead of serializing the complete nested packet back into JSON lines.
    /// Passing no prompt produces a data-only report suitable for the AI client,
    /// which sends its selected prompt separately as the system message.
    static func horary(_ result: HoraryDataPacket, prompt: String? = nil) -> String {
        let displayOrb = result.displayOrbDeg ?? result.calculationConfig.aspectOrbDeg

        var lines: [String] = []
        if let prompt {
            let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPrompt.isEmpty {
                lines += [
                    "# Horary 分析提示词",
                    "",
                    trimmedPrompt,
                    "",
                    "---",
                    "",
                ]
            }
        }

        lines += [
            "# Horary 数据报告",
            "",
            "> 完整、无损的 v2.1 证据包请使用 JSON 导出；本 Markdown 仅保留适合阅读与分析的字段。",
            "",
            "## 问题与起盘信息",
            "",
            "- 问题：\(plain(result.questionMetadata.questionText, fallback: "（未填写）"))",
            "- 地点：\(plain(result.questionMetadata.placeName, fallback: "（未填写）"))",
            "- 本地时间：\(plain(result.timeAndLocation.localDatetime))",
            "- UTC：\(plain(result.timeAndLocation.utcDatetime))",
            "- 时区：\(plain(result.timeAndLocation.timezone))（UTC offset \(result.timeAndLocation.utcOffsetSeconds)s，DST \(yesNo(result.timeAndLocation.dstActive))）",
            "- 坐标：\(decimal(result.timeAndLocation.latitudeDeg, digits: 4)), \(decimal(result.timeAndLocation.locationLongitudeDeg, digits: 4))",
            "- 昼夜盘：\(result.timeAndLocation.sect.isDay ? "昼盘" : "夜盘")（\(plain(result.timeAndLocation.sect.ruleId))）",
            "- Schema：\(result.schema.schemaId)",
            "",
            "## 计算设置",
            "",
            "- 宫制：\(plain(result.calculationConfig.houseSystemLabel))（\(plain(result.calculationConfig.houseSystem))）",
            "- 黄道：\(plain(result.calculationConfig.zodiacLabel))（\(plain(result.calculationConfig.zodiac))）",
            "- 界：\(plain(result.calculationConfig.boundsSystem))；三分主星：\(plain(result.calculationConfig.triplicitySystem))",
            "- 显示容许度：\(decimal(displayOrb))°；事件窗口：过去 \(decimal(result.calculationConfig.eventWindow.pastDays)) 天 / 未来 \(decimal(result.calculationConfig.eventWindow.futureDays)) 天",
            "",
            "## 角点",
            "",
            "| 点 | 位置 | 黄经 |",
            "|---|---:|---:|",
        ]

        for angle in result.angles.points {
            lines.append("| \(cell(angle.id)) | \(cell(angle.sign.displayZh)) | \(decimal(angle.longitudeDeg, digits: 4))° |")
        }
        if let armc = result.angles.armc.longitudeDeg {
            lines.append("| ARMC | — | \(decimal(armc, digits: 4))° |")
        }

        lines += [
            "",
            "## 宫位",
            "",
            "| 宫 | 宫头 | 黄经 | 宫主星 |",
            "|---:|---:|---:|---|",
        ]
        for house in result.houses.cusps {
            lines.append(
                "| \(house.house) | \(cell(house.sign.displayZh)) | \(decimal(house.cuspLongitudeDeg, digits: 4))° | \(cell(house.domicileRulerId)) |"
            )
        }
        if result.houses.fallbackApplied {
            lines += ["", "- 宫制回退：是；原因：\(plain(result.houses.fallbackReason ?? "未提供"))"]
        }

        lines += [
            "",
            "## 天体位置与运动",
            "",
            "| 天体 | 位置 | 宫位 | 运动 | 速度（°/日） |",
            "|---|---:|---:|---|---:|",
        ]
        for body in result.bodies {
            lines.append(
                "| \(cell("\(body.nameZh)（\(body.bodyId)）")) | \(cell(body.displayZh)) | \(body.integerHouse) | \(cell(body.motionState)) | \(body.eclipticSpeed.map { decimal($0, digits: 5) } ?? "—") |"
            )
        }

        lines += [
            "",
            "## 本质尊贵事实",
            "",
            "| 天体 | 入庙主 | 旺主 | 界主 | 十度主 | 三分主 | 状态 |",
            "|---|---|---|---|---|---|---|",
        ]
        for dignity in result.dignities {
            let states = [
                dignity.bool("is_in_own_domicile") == true ? "入庙" : nil,
                dignity.bool("is_in_own_exaltation") == true ? "擢升" : nil,
                dignity.bool("is_in_detriment") == true ? "失势" : nil,
                dignity.bool("is_in_fall") == true ? "落陷" : nil,
                dignity.bool("is_peregrine") == true ? "游走" : nil,
            ].compactMap { $0 }
            lines.append(
                "| \(cell(dignity.bodyId)) | \(cell(dignity.string("domicile_ruler_id") ?? "—")) | \(cell(dignity.string("exaltation_ruler_id") ?? "—")) | \(cell(dignity.value("bounds")?.string("ruler_id") ?? "—")) | \(cell(dignity.value("decan")?.string("ruler_id") ?? "—")) | \(cell(dignity.value("triplicity")?.string("active_ruler_id") ?? "—")) | \(cell(states.isEmpty ? "—" : states.joined(separator: "、"))) |"
            )
        }

        appendAspects(result: result, displayOrb: displayOrb, to: &lines)
        appendReceptions(result.receptions, to: &lines)
        appendLots(result.lots, to: &lines)
        appendMoon(result.moon, to: &lines)
        appendEvents(result.events, to: &lines)
        appendVisibility(result.visibility, to: &lines)
        appendPlanetaryDayHour(result.planetaryDayHour, to: &lines)
        appendNodes(result.nodes, to: &lines)
        appendConsiderations(result.considerationsEvidence, to: &lines)
        appendOptionalModules(result.optionalModules, to: &lines)

        lines += [
            "",
            "## 数据校验",
            "",
            "- forbidden field scan：\(plain(result.validation.forbiddenFieldScan ?? "unknown"))",
            "- 数量：天体 \(result.bodies.count)，相位候选 \(result.aspectCandidates?.count ?? result.aspects.count)，事件 \(result.events.count)，Lots \(result.lots.count)",
            "- 宫制回退：\(yesNo(result.validation.houseFallbackApplied ?? false))",
        ]
        if !result.validation.warnings.isEmpty {
            lines += ["", "### 技术警告", ""]
            lines += result.validation.warnings.map { "- \(plain($0))" }
        }

        return lines.joined(separator: "\n")
    }

    private static func appendAspects(
        result: HoraryDataPacket,
        displayOrb: Double,
        to lines: inout [String]
    ) {
        let candidates = result.aspectCandidates ?? result.aspects
        let inDisplayOrb = result.aspectsInDisplayOrb
            ?? candidates.filter { $0.withinDisplayOrb == true || ($0.absoluteOrbDeg ?? .infinity) <= displayOrb }

        var selected: [HoraryV2EvidenceRow] = []
        var seen = Set<String>()
        for aspect in inDisplayOrb + candidates.filter({ $0.willPerfectInWindow == true }) {
            if seen.insert(aspect.id).inserted {
                selected.append(aspect)
            }
        }

        lines += [
            "",
            "## 相位（显示容许度内及窗口内将精确）",
            "",
            "- 全部候选：\(candidates.count)；本节列出：\(selected.count)；显示容许度：\(decimal(displayOrb))°",
            "",
            "| A | 相位 | B | 绝对容许度 | 状态 | 窗口内精确 | 下次精确（UTC） |",
            "|---|---|---|---:|---|---|---|",
        ]
        if selected.isEmpty {
            lines.append("| — | — | — | — | — | — | — |")
        } else {
            for aspect in selected {
                lines.append(
                    "| \(cell(aspect.bodyAId ?? "—")) | \(cell(aspect.aspectId ?? "—")) | \(cell(aspect.bodyBId ?? "—")) | \(aspect.absoluteOrbDeg.map { decimal($0, digits: 4) + "°" } ?? "—") | \(cell(aspect.application ?? "—")) | \(aspect.willPerfectInWindow.map(yesNo) ?? "—") | \(cell(aspect.nextExact?.datetimeUtc ?? "—")) |"
                )
            }
        }
    }

    private static func appendReceptions(_ receptions: [HoraryV2EvidenceRow], to lines: inout [String]) {
        lines += [
            "",
            "## 接纳",
            "",
            "| 主体 | 关系 / 尊贵 | 对象 | 相关相位 | 精确时关系状态 |",
            "|---|---|---|---|---|",
        ]
        if receptions.isEmpty {
            lines.append("| — | — | — | — | — |")
            return
        }
        for reception in receptions {
            let source = reception.receiverId ?? reception.bodyAId ?? "—"
            let target = reception.receivedBodyId ?? reception.bodyBId ?? "—"
            let relation = reception.dignityType ?? reception.relationKind ?? "—"
            let relatedAspects = reception.value("related_aspect_candidate_ids").map(scalar)
                ?? reception.relatedAspectId
                ?? "—"
            let exactStatus = reception.relationAtNextAspectExact?.string("status") ?? "—"
            let exactHolds = reception.relationAtNextAspectExact?.bool("holds")
                .map { "holds=\(yesNo($0))" }
            let exactSummary = exactHolds.map { "\(exactStatus)；\($0)" } ?? exactStatus
            lines.append(
                "| \(cell(source)) | \(cell(relation)) | \(cell(target)) | \(cell(relatedAspects)) | \(cell(exactSummary)) |"
            )
        }
    }

    private static func appendLots(_ lots: [HoraryV2EvidenceRow], to lines: inout [String]) {
        lines += [
            "",
            "## Lots",
            "",
            "| Lot | 位置 | 宫位 | 宫主星 | 公式 | 昼夜 |",
            "|---|---:|---:|---|---|---|",
        ]
        if lots.isEmpty {
            lines.append("| — | — | — | — | — | — |")
            return
        }
        for lot in lots {
            lines.append(
                "| \(cell("\(lot.names.zh)（\(lot.names.en)）")) | \(cell(lot.sign.displayZh)) | \(lot.house.integerHouse) | \(cell(lot.domicileRulerId ?? "—")) | \(cell(lot.formulaUsed ?? lot.formulaId ?? "—")) | \(cell(lot.sectUsed ?? "—")) |"
            )
        }
    }

    private static func appendMoon(_ moon: HoraryV2JSONValue?, to lines: inout [String]) {
        lines += ["", "## 月亮进程与 VOC", ""]
        guard let moon else {
            lines.append("- 无数据")
            return
        }

        lines += [
            "- 当前位置：\(plain(moon["current_sign"]?.string("display_zh") ?? "—"))",
            "- 月相角：\(moon.number("phase_angle_deg").map { decimal($0, digits: 4) + "°" } ?? "—")；照明：\(moon.number("illumination_fraction").map { decimal($0, digits: 4) } ?? "—")",
            "- 离开当前星座：\(plain(moon["sign_exit"]?.string("datetime_utc") ?? "—"))（剩余 \(moon["sign_exit"]?.number("remaining_arc_deg").map { decimal($0, digits: 4) + "°" } ?? "—")）",
        ]

        appendMoonAspect(label: "当前星座内最后精确相位", value: moon["last_exact_aspect_in_current_sign"], to: &lines)
        appendMoonAspect(label: "当前星座内下个精确相位", value: moon["next_exact_aspect_in_current_sign"], to: &lines)

        if case .array(let rules) = moon["void_of_course_rules"] {
            lines += ["", "### VOC 规则", "", "| 规则 | 结果 | 区间结束（UTC） |", "|---|---|---|"]
            for rule in rules {
                lines.append(
                    "| \(cell(rule.string("rule_id") ?? "—")) | \(rule.bool("value").map(yesNo) ?? "—") | \(cell(rule["interval"]?.string("end_datetime_utc") ?? "—")) |"
                )
            }
        }
    }

    private static func appendMoonAspect(label: String, value: HoraryV2JSONValue?, to lines: inout [String]) {
        guard let value, value.objectValue != nil else {
            lines.append("- \(label)：无")
            return
        }
        lines.append(
            "- \(label)：\(plain(value.string("aspect_id") ?? "—")) \(plain(value.string("target_id") ?? "—")) @ \(plain(value.string("datetime_utc") ?? "—"))"
        )
    }

    private static func appendEvents(_ events: [HoraryV2EvidenceRow], to lines: inout [String]) {
        lines += [
            "",
            "## 事件时间线",
            "",
            "| UTC | 类型 | 天体 | 相位 | 相对提问时刻 |",
            "|---|---|---|---|---:|",
        ]
        if events.isEmpty {
            lines.append("| — | — | — | — | — |")
            return
        }
        for event in events {
            lines.append(
                "| \(cell(event.datetimeUtc ?? "—")) | \(cell(event.eventType ?? "—")) | \(cell(event.bodyIds.joined(separator: " / "))) | \(cell(event.aspectId ?? "—")) | \(event.offsetSecondsFromQuery.map { "\($0)s" } ?? "—") |"
            )
        }
    }

    private static func appendVisibility(_ rows: [HoraryV2EvidenceRow], to lines: inout [String]) {
        lines += [
            "",
            "## 可见性与太阳几何",
            "",
            "| 天体 | 晨/昏 | 可见 | 原因 | 日距 | 视星等 |",
            "|---|---|---|---|---:|---:|",
        ]
        if rows.isEmpty {
            lines.append("| — | — | — | — | — | — |")
            return
        }
        for row in rows {
            lines.append(
                "| \(cell(row.bodyId)) | \(cell(row.string("morning_evening") ?? "—")) | \(row.bool("visible").map(yesNo) ?? "—") | \(cell(row.string("visible_reason_code") ?? "—")) | \(row.number("solar_elongation_deg").map { decimal($0, digits: 3) + "°" } ?? "—") | \(row.number("apparent_magnitude").map { decimal($0, digits: 2) } ?? "—") |"
            )
        }
    }

    private static func appendPlanetaryDayHour(
        _ value: HoraryV2JSONValue?,
        to lines: inout [String]
    ) {
        lines += ["", "## 行星日与行星时", ""]
        guard let value else {
            lines.append("- 无数据")
            return
        }
        lines += [
            "- 状态：\(plain(value.string("status") ?? "—"))；方法：\(plain(value.string("method_key") ?? "—"))",
            "- 行星日主星：\(plain(value.string("day_ruler_name") ?? value.string("day_ruler_id") ?? "—"))",
        ]
        if let current = value["current_hour"] {
            lines.append(
                "- 当前行星时：\(plain(current.string("ruler_name") ?? current.string("ruler_id") ?? "—"))；\(plain(current.string("period") ?? "—")) 第 \(current.number("hour_index").map { decimal($0, digits: 0) } ?? "—") 时；\(plain(current.string("start_local") ?? "—")) — \(plain(current.string("end_local") ?? "—"))"
            )
        }
        lines.append(
            "- 日出 / 日落：\(plain(value.string("sunrise_local") ?? "—")) / \(plain(value.string("sunset_local") ?? "—"))"
        )
    }

    private static func appendNodes(_ value: HoraryV2JSONValue?, to lines: inout [String]) {
        lines += [
            "",
            "## 月交点",
            "",
            "| 模式 | 交点 | 位置 | 宫位 | 运动 |",
            "|---|---|---:|---:|---|",
        ]
        guard let value, case .array(let bodies) = value["bodies"], !bodies.isEmpty else {
            lines.append("| — | — | — | — | — |")
            return
        }
        let mode = value.string("mode") ?? "—"
        for body in bodies {
            lines.append(
                "| \(cell(mode)) | \(cell(body.string("body_id") ?? "—")) | \(cell(body["sign"]?.string("display_zh") ?? "—")) | \(body["house"]?.number("integer_house").map { decimal($0, digits: 0) } ?? "—") | \(cell(body["motion"]?.string("state") ?? "—")) |"
            )
        }
    }

    private static func appendConsiderations(
        _ considerations: [HoraryV2JSONValue]?,
        to lines: inout [String]
    ) {
        lines += [
            "",
            "## 判断前事实（不含结论）",
            "",
            "| 事实 | 值 | 规则 |",
            "|---|---|---|",
        ]
        guard let considerations, !considerations.isEmpty else {
            lines.append("| — | — | — |")
            return
        }
        for item in considerations {
            let value = item["value"].map(scalar)
                ?? item["in_interval"].map(scalar)
                ?? item["same_planet"].map(scalar)
                ?? item["integer_house"].map(scalar)
                ?? item["sign_exit"]?.string("datetime_utc")
                ?? item["longitude_deg"].map(scalar)
                ?? "—"
            lines.append(
                "| \(cell(item.string("fact_type") ?? item.string("id") ?? "—")) | \(cell(value)) | \(cell(item.string("rule_id") ?? "—")) |"
            )
        }
    }

    private static func appendOptionalModules(_ modules: HoraryV2JSONValue?, to lines: inout [String]) {
        lines += ["", "## 可选模块重点", ""]
        guard let modules, let object = modules.objectValue else {
            lines.append("- 无数据")
            return
        }

        let orderedKeys = [
            "antiscia", "via_combusta", "dodecatemoria", "antiscia_contacts",
            "declination_contacts", "declination_moon_sequence", "fixed_stars",
            "planetary_hour", "declination_parallels", "nodes",
        ]
        for key in orderedKeys where object[key] != nil {
            lines.append("- \(key)：\(collectionSummary(object[key]))")
        }

        appendContactHighlights(
            title: "Antiscia 命中",
            rows: filteredRows(object["antiscia_contacts"], requiringTrue: "within_orb"),
            columns: ["point_a_id", "kind", "point_b_id", "distance_deg", "orb_limit_deg"],
            to: &lines
        )
        appendContactHighlights(
            title: "赤纬命中",
            rows: filteredRows(object["declination_contacts"], requiringTrue: "within_orb"),
            columns: ["body_a_id", "kind", "body_b_id", "delta_deg", "application"],
            to: &lines
        )

        if let fixedStars = object["fixed_stars"],
           case .array(let contacts) = fixedStars["contacts"],
           !contacts.isEmpty {
            appendContactHighlights(
                title: "固定星合相",
                rows: contacts,
                columns: ["star_name", "point_id", "distance_deg", "orb_deg", "catalog_nature"],
                to: &lines
            )
        }
    }

    private static func appendContactHighlights(
        title: String,
        rows: [HoraryV2JSONValue],
        columns: [String],
        to lines: inout [String]
    ) {
        guard !rows.isEmpty else { return }
        lines += [
            "",
            "### \(title)",
            "",
            "| \(columns.map(headerLabel).joined(separator: " | ")) |",
            "|\(columns.map { _ in "---" }.joined(separator: "|"))|",
        ]
        for row in rows {
            let values = columns.map { key in cell(row[key].map(scalar) ?? "—") }
            lines.append("| \(values.joined(separator: " | ")) |")
        }
    }

    private static func filteredRows(
        _ value: HoraryV2JSONValue?,
        requiringTrue key: String
    ) -> [HoraryV2JSONValue] {
        guard case .array(let rows) = value else { return [] }
        return rows.filter { $0.bool(key) == true }
    }

    private static func collectionSummary(_ value: HoraryV2JSONValue?) -> String {
        guard let value else { return "无" }
        switch value {
        case .array(let rows):
            return "\(rows.count) 条"
        case .object(let object):
            if case .array(let contacts) = object["contacts"] {
                return "\(contacts.count) 个命中"
            }
            if let status = object["status"].map(scalar) {
                return status
            }
            return "\(object.count) 个字段"
        default:
            return scalar(value)
        }
    }

    private static func scalar(_ value: HoraryV2JSONValue) -> String {
        switch value {
        case .string(let string):
            return string
        case .number(let number):
            return decimal(number, digits: 5)
        case .bool(let bool):
            return yesNo(bool)
        case .null:
            return "—"
        case .array(let values):
            let rendered = values.prefix(6).map(scalar).joined(separator: " / ")
            return values.count > 6 ? "\(rendered) / …（共 \(values.count)）" : rendered
        case .object:
            return "见结构化字段"
        }
    }

    private static func headerLabel(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
    }

    private static func plain(_ value: String, fallback: String = "—") -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func cell(_ value: String) -> String {
        plain(value)
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private static func decimal(_ value: Double, digits: Int = 2) -> String {
        guard value.isFinite else { return "—" }
        var rendered = String(format: "%.\(digits)f", value)
        while rendered.contains("."), rendered.last == "0" {
            rendered.removeLast()
        }
        if rendered.last == "." {
            rendered.removeLast()
        }
        return rendered
    }
}
