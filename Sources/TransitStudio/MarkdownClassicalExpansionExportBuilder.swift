import Foundation

extension MarkdownExportBuilder {
    static func classicalBodyNameLookup(_ rows: [ClassicalPlanetRow]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.name) })
    }

    static func transitBodyNameLookup(_ rows: [PositionRow]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: rows.map { ($0.bodyID, $0.name) })
    }

    static func prefixedBodyLabel(_ bodyID: String, names: [String: String]) -> String {
        let prefix: String
        let rawID: String
        if bodyID.hasPrefix("natal_") {
            prefix = "本命 "
            rawID = String(bodyID.dropFirst("natal_".count))
        } else if bodyID.hasPrefix("transit_") {
            prefix = "行运 "
            rawID = String(bodyID.dropFirst("transit_".count))
        } else {
            prefix = ""
            rawID = bodyID
        }
        return "\(prefix)\(names[rawID] ?? rawID)"
    }

    static func optionalDegree(_ value: Double?, digits: Int) -> String {
        value.map { degree($0, digits: digits) } ?? ""
    }

    static func yesNo(_ value: Bool) -> String {
        value ? "是" : "否"
    }

    static func declinationAspectSection(_ rows: [DeclinationAspect], names: [String: String]) -> [String] {
        var lines = [
            "## 赤纬相位（平行 / 反平行）",
            "",
            "| A | 类型 | B | A 赤纬 | B 赤纬 | 差值 |",
            "| --- | --- | --- | ---: | ---: | ---: |",
        ]
        if rows.isEmpty {
            lines.append("| - | 无赤纬相位 | - | - | - | - |")
        } else {
            for row in rows {
                let type = row.type == "contraparallel" ? "反平行" : "平行"
                lines.append("| \(prefixedBodyLabel(row.body1, names: names)) | \(type) | \(prefixedBodyLabel(row.body2, names: names)) | \(optionalDegree(row.declination1, digits: 4)) | \(optionalDegree(row.declination2, digits: 4)) | \(degree(row.diff, digits: 2)) |")
            }
        }
        lines.append("")
        return lines
    }

    static func fixedStarSection(_ title: String, _ rows: [FixedStarConjunction], names: [String: String]) -> [String] {
        var lines = [
            "## \(title)",
            "",
            "| 行星 | 恒星 | 容许度 | 星等 | 性质 | 关键词 |",
            "| --- | --- | ---: | ---: | --- | --- |",
        ]
        if rows.isEmpty {
            lines.append("| - | 无合相命中 | - | - | - | - |")
        } else {
            for row in rows {
                let planet = names[row.planet] ?? row.planet
                lines.append("| \(planet) | \(row.star) | \(degree(row.orb, digits: 2)) | \(String(format: "%.2f", row.starMag)) | \(row.starNature) | \(row.starKeyword) |")
            }
        }
        lines.append("")
        return lines
    }

    static func medievalSection(_ medieval: MedievalData) -> [String] {
        var body: [String] = []
        if let triplicity = medieval.sectLightTriplicity {
            body += sectLightTriplicitySection(triplicity)
        }
        if let kurios = medieval.kurios {
            body += kuriosSection(kurios)
        }
        if let synthesis = medieval.profectionSRSynthesis {
            body += profectionSRSynthesisSection(synthesis)
        }
        guard !body.isEmpty else { return [] }
        return ["## 中世纪深化", ""] + body
    }

    static func sectLightTriplicitySection(_ triplicity: SectLightTriplicity) -> [String] {
        var lines = [
            "### Sect Light 三分主",
            "",
            "- Sect Light：\(triplicity.sectLightName)（\(triplicity.lightSign) \(degree(triplicity.lightLongitude, digits: 2))）",
            "- 三分主系统：\(triplicity.triplicitySystem)",
            "",
            "| 排序 | 角色 | 主星 | 宫位 | 评分 | 状态 | 角宫 |",
            "| ---: | --- | --- | ---: | ---: | --- | --- |",
        ]
        for ruler in triplicity.rulers {
            lines.append("| \(ruler.rank) | \(ruler.label) | \(ruler.planetName) | \(ruler.house) | \(ruler.score) | \(ruler.scoreLabel) | \(yesNo(ruler.angular)) |")
        }
        lines.append("")
        return lines
    }

    static func kuriosSection(_ kurios: KuriosResult) -> [String] {
        var lines = [
            "### Kurios / Oikodespotes",
            "",
            "- 方法：\(kurios.method)",
        ]
        if let primary = kurios.primary {
            lines.append("- 主选：**\(primary.planetName)**（\(primary.role)，\(primary.score) 分，第 \(primary.natalHouse) 宫，\(primary.natalScoreLabel)）")
        }
        if !kurios.candidates.isEmpty {
            lines += [
                "",
                "| 候选 | 角色 | 基础 | 修正 | 总分 | 宫位 | 本命状态 | 修正说明 |",
                "| --- | --- | ---: | ---: | ---: | ---: | --- | --- |",
            ]
            for candidate in kurios.candidates {
                lines.append("| \(candidate.planetName) | \(candidate.role) | \(candidate.baseWeight) | \(candidate.modifier) | \(candidate.score) | \(candidate.natalHouse) | \(candidate.natalScoreLabel) | \(candidate.modifiers.joined(separator: "、")) |")
            }
        }
        lines.append("")
        return lines
    }

    static func profectionSRSynthesisSection(_ synthesis: ProfectionSRSynthesis) -> [String] {
        let lord = synthesis.lordOfYearInSR
        var lines = [
            "### 年主与 Solar Return 综合",
            "",
            "- 小限 ASC：\(synthesis.profectionAscSign)",
            "- Solar Return ASC：\(synthesis.solarReturnAscSign)",
            "- ASC 星座一致：\(yesNo(synthesis.ascSignsMatch))",
        ]
        if lord.present {
            var lordText = lord.planetName ?? lord.planet ?? "年主"
            if let houseLabel = lord.houseLabel {
                lordText += "，\(houseLabel)"
            } else if let house = lord.house {
                lordText += "，第 \(house) 宫"
            }
            if let sign = lord.sign {
                lordText += "，\(sign)"
            }
            if let score = lord.score {
                lordText += "，评分 \(score)"
            }
            if let scoreLabel = lord.scoreLabel {
                lordText += "（\(scoreLabel)）"
            }
            if lord.retrograde == true {
                lordText += "，逆行"
            }
            if lord.angular == true {
                lordText += "，角宫"
            }
            lines.append("- 年主在返照盘：\(lordText)")
        } else {
            lines.append("- 年主在返照盘：未定位")
        }
        lines += [
            "- 返照 ASC 主星：\(synthesis.srHighlights.ascRuler)，第 \(synthesis.srHighlights.ascRulerHouse) 宫",
            "- 返照 MC 主星：\(synthesis.srHighlights.mcRuler)，第 \(synthesis.srHighlights.mcRulerHouse) 宫",
        ]
        if let stellium = synthesis.srHighlights.stelliumSign {
            lines.append("- 返照群星星座：\(stellium)")
        }
        lines.append("- 摘要：\(synthesis.summaryText)")
        lines.append("")
        return lines
    }
}
