import Foundation

extension MarkdownExportBuilder {
    static func kpHorary(_ result: KPHoraryResult) -> String {
        var lines: [String] = [
            "# KP 占卜数据包",
            "",
            "## 问题与起盘",
            "",
            "- Schema：\(result.schema.schemaID)",
            "- 问题：\(kpMarkdownCell(result.question.text))",
            "- 地点：\(kpMarkdownCell(result.question.placeName))（\(result.timeAndLocation.latitude), \(result.timeAndLocation.longitude)）",
            "- 提问本地时间：\(result.timeAndLocation.questionLocal)",
            "- 提问 UTC：\(result.timeAndLocation.questionUTC)",
            "- KP 数字：\(result.question.horaryNumber)",
            "- 焦点宫：第 \(result.question.focusHouse) 宫",
            "- 黄道 / Ayanamsha：\(result.calculationConfig.zodiac) / \(result.calculationConfig.ayanamsha)（\(kpNumber(result.calculationConfig.ayanamshaDegreesAtQuestion, digits: 9))°）",
            "- 宫制 / 交点：\(result.calculationConfig.houseSystem) / \(result.calculationConfig.nodeMode)",
            "- 自动裁决：\(result.calculationConfig.automaticJudgment ? "开启" : "关闭")",
            "",
            "## 数字上升区间",
            "",
            "- 区间：[\(kpNumber(result.horaryNumber.intervalStartLongitude, digits: 12))°, \(kpNumber(result.horaryNumber.intervalEndLongitude, digits: 12))°)",
            "- 代表黄经：\(kpNumber(result.horaryNumber.representativeLongitude, digits: 12))°（\(result.horaryNumber.degreeText)）",
            "- 星座主：\(result.horaryNumber.signLord.name)",
            "- Nakshatra：\(result.horaryNumber.nakshatra.name) / \(result.horaryNumber.nakshatra.nameZH)，第 \(result.horaryNumber.nakshatra.pada) 足，宿主 \(result.horaryNumber.nakshatra.lord.name)",
            "- 副星主 / 副副星主：\(result.horaryNumber.subLord.name) / \(result.horaryNumber.subSubLord.name)",
            "- 宫位求解 UTC：\(result.timeAndLocation.houseSolutionUTC)",
            "- 目标 / 实算上升：\(kpNumber(result.houseSolution.targetAscendant, digits: 12))° / \(kpNumber(result.houseSolution.solvedAscendant, digits: 12))°",
            "- 残差：\(kpNumber(result.houseSolution.residualDegrees, digits: 12))°（\(result.houseSolution.evaluations) 次求值）",
            "",
            "## Ruling Planets（原始来源）",
            "",
            "| 来源 | 行星 | ID |",
            "|---|---|---|",
        ]
        lines += result.rulingPlanets.map {
            "| \(kpMarkdownCell($0.source)) | \(kpMarkdownCell($0.planet.name)) | \($0.planet.id) |"
        }

        lines += [
            "",
            "## 四轴",
            "",
            kpPositionHeader(firstColumn: "轴点"),
            kpPositionSeparator,
        ]
        lines += result.angles.map {
            kpPositionRow(first: "\($0.name)（\($0.id)）", position: $0, house: "")
        }

        lines += [
            "",
            "## 行星层级",
            "",
            kpPositionHeader(firstColumn: "行星"),
            kpPositionSeparator,
        ]
        lines += result.planets.map {
            kpPositionRow(
                first: "\($0.name)（\($0.id)）\($0.retrograde ? " ℞" : "")",
                position: $0,
                house: String($0.house)
            )
        }

        lines += [
            "",
            "## 宫头层级",
            "",
            kpPositionHeader(firstColumn: "宫位"),
            kpPositionSeparator,
        ]
        lines += result.houses.map {
            kpPositionRow(first: "第 \($0.house) 宫", position: $0, house: String($0.house))
        }

        lines += [
            "",
            "## 行星征象来源",
            "",
            "| 行星 | 直接落/守宫 | 宿主落/守宫 | 副星主落/守宫 | 候选宫位 |",
            "|---|---|---|---|---|",
        ]
        lines += result.planetSignificators.map { row in
            "| \(row.planet.name) | \(kpScope(row.direct)) | \(kpScope(row.starLordScope)) | \(kpScope(row.subLordScope)) | \(row.candidateHouses.map(String.init).joined(separator: ", ")) |"
        }

        lines += ["", "## 宫位征象四级候选", ""]
        for house in result.houseSignificators {
            lines.append("### 第 \(house.house) 宫（宫头主 \(house.cuspSignLord.name)）")
            lines.append("")
            lines.append("| 层级 | 来源 | 候选行星 |")
            lines.append("|---|---|---|")
            lines += house.tiers.map { tier in
                "| T\(tier.tier) | \(kpMarkdownCell(tier.source)) | \(tier.planets.map(\.name).joined(separator: ", ").isEmpty ? "—" : tier.planets.map(\.name).joined(separator: ", ")) |"
            }
            lines.append("")
        }

        lines += [
            "## 焦点宫",
            "",
            "- 第 \(result.focusHouse.house) 宫，宫头主 \(result.focusHouse.cuspSignLord.name)",
        ]
        lines += result.focusHouse.tiers.map { tier in
            "- T\(tier.tier) · \(tier.source)：\(tier.planets.map(\.name).joined(separator: ", ").isEmpty ? "—" : tier.planets.map(\.name).joined(separator: ", "))"
        }

        lines += ["", "## 交点直接代表关系", ""]
        lines += result.nodeRepresentations.map { row in
            "- \(row.node.name)：第 \(row.occupiedHouse) 宫；星座主 \(row.signLord.name)，宿主 \(row.starLord.name)，副星主 \(row.subLord.name)"
        }

        lines += ["", "## 警告", ""]
        lines += result.warnings.isEmpty ? ["- 无"] : result.warnings.map { "- \($0)" }
        lines += [
            "",
            "> 方法边界：行星使用提问时刻；数字用于选择 KP 上升区间并求得相应 Placidus 宫头。所有征象字段都是透明候选来源，不是自动 yes/no、吉凶裁决或权重评分。",
        ]
        return lines.joined(separator: "\n")
    }

    private static func kpPositionHeader(firstColumn: String) -> String {
        "| \(firstColumn) | 位置 | 宫 | 星座主 | Nakshatra | 宿主 | 副星主 | 副副星主 |"
    }

    private static let kpPositionSeparator = "|---|---|---:|---|---|---|---|---|"

    private static func kpPositionRow(
        first: String,
        position: any KPPositionRepresentable,
        house: String
    ) -> String {
        "| \(kpMarkdownCell(first)) | \(kpMarkdownCell(position.degreeText)) | \(house) | \(position.signLord.name) | \(position.nakshatra.name) \(position.nakshatra.pada) | \(position.nakshatra.lord.name) | \(position.subLord.name) | \(position.subSubLord.name) |"
    }

    private static func kpScope(_ scope: KPSignificatorScope) -> String {
        let occupied = scope.occupiedHouse.map { "落 \($0)" } ?? "无落宫"
        let owned = scope.ownedHouses.isEmpty ? "无守护宫" : "守 \(scope.ownedHouses.map(String.init).joined(separator: ","))"
        return "\(scope.planet.name)：\(occupied)；\(owned)"
    }

    private static func kpMarkdownCell(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
    }

    private static func kpNumber(_ value: Double, digits: Int) -> String {
        String(format: "%.*f", digits, value)
    }
}

extension TextExportBuilder {
    static func csv(_ result: KPHoraryResult) -> String {
        var rows: [[String]] = [[
            "section", "id", "name", "longitude", "degree_text", "house",
            "sign_lord", "nakshatra", "nakshatra_lord", "sub_lord",
            "sub_sub_lord", "source", "candidates", "details",
        ]]

        rows.append(["meta", "schema", "", "", "", "", "", "", "", "", "", "schema_id", "", result.schema.schemaID])
        rows.append(["meta", "question", "", "", "", String(result.question.focusHouse), "", "", "", "", "", "question", "", result.question.text])
        rows.append(["meta", "question_utc", "", "", "", "", "", "", "", "", "", "question_time", "", result.timeAndLocation.questionUTC])
        rows.append(["meta", "house_solution_utc", "", "", "", "", "", "", "", "", "", "house_time", "", result.timeAndLocation.houseSolutionUTC])
        rows.append(["meta", "solve_residual", "", kpNumberCSV(result.houseSolution.residualDegrees), "", "", "", "", "", "", "", "residual_degrees", "", String(result.houseSolution.evaluations)])

        rows.append(kpPositionCSVRow(
            section: "horary_number",
            id: String(result.horaryNumber.number),
            name: "KP \(result.horaryNumber.number)",
            position: result.horaryNumber,
            house: "1",
            details: "[\(kpNumberCSV(result.horaryNumber.intervalStartLongitude)), \(kpNumberCSV(result.horaryNumber.intervalEndLongitude)))"
        ))
        rows += result.angles.map {
            kpPositionCSVRow(section: "angle", id: $0.id, name: $0.name, position: $0, house: "", details: "")
        }
        rows += result.planets.map {
            kpPositionCSVRow(
                section: "planet", id: $0.id, name: $0.name, position: $0,
                house: String($0.house), details: $0.retrograde ? "retrograde" : "direct"
            )
        }
        rows += result.houses.map {
            kpPositionCSVRow(section: "house", id: String($0.house), name: "第 \($0.house) 宫", position: $0, house: String($0.house), details: "")
        }
        rows += result.rulingPlanets.map {
            ["ruling_planet", $0.planet.id, $0.planet.name, "", "", "", "", "", "", "", "", $0.source, "", ""]
        }
        rows += result.planetSignificators.map { row in
            [
                "planet_significator", row.planet.id, row.planet.name, "", "",
                row.direct.occupiedHouse.map(String.init) ?? "", "", "", row.starLordScope.planet.name,
                row.subLordScope.planet.name, "", "transparent_sources",
                row.candidateHouses.map(String.init).joined(separator: ";"),
                "direct=\(kpScopeCSV(row.direct));star=\(kpScopeCSV(row.starLordScope));sub=\(kpScopeCSV(row.subLordScope))",
            ]
        }
        for house in result.houseSignificators {
            rows += house.tiers.map { tier in
                [
                    "house_significator", String(house.house), "第 \(house.house) 宫", "", "",
                    String(house.house), house.cuspSignLord.name, "", "", "", "",
                    "T\(tier.tier):\(tier.source)", tier.planets.map(\.name).joined(separator: ";"), "",
                ]
            }
        }
        rows += result.nodeRepresentations.map { row in
            [
                "node_representation", row.node.id, row.node.name, "", "", String(row.occupiedHouse),
                row.signLord.name, "", row.starLord.name, row.subLord.name, "", "direct_connections_only", "", "",
            ]
        }
        rows += result.warnings.map { ["warning", "", "", "", "", "", "", "", "", "", "", "", "", $0] }

        return rows.map { $0.map(kpCSVEscape).joined(separator: ",") }.joined(separator: "\n")
    }

    private static func kpPositionCSVRow(
        section: String,
        id: String,
        name: String,
        position: any KPPositionRepresentable,
        house: String,
        details: String
    ) -> [String] {
        [
            section, id, name, kpNumberCSV(position.longitude), position.degreeText, house,
            position.signLord.name, position.nakshatra.name, position.nakshatra.lord.name,
            position.subLord.name, position.subSubLord.name, "", "", details,
        ]
    }

    private static func kpScopeCSV(_ scope: KPSignificatorScope) -> String {
        "\(scope.planet.id):occupied=\(scope.occupiedHouse.map(String.init) ?? "");owned=\(scope.ownedHouses.map(String.init).joined(separator: "/"))"
    }

    private static func kpNumberCSV(_ value: Double) -> String {
        String(format: "%.12f", value)
    }

    private static func kpCSVEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
