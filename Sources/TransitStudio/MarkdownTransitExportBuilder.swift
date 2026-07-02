import Foundation

extension MarkdownExportBuilder {
    static func natal(_ result: TransitResult) -> String {
        var lines: [String] = [
            "# 本命盘",
            "",
            "## 元数据",
            "",
            "- 出生 UTC：\(result.meta.natalUTC)",
            "- 星历：\(result.meta.ephemeris)",
            ""
        ]

        lines += positionSection("本命位置", result.natalPositions)

        let aspects = natalAspects(from: result)
        lines += [
            "## 本命相位",
            "",
            "| 天体 A | 相位 | 天体 B | 角距 | 容许度 |",
            "| --- | --- | --- | ---: | ---: |"
        ]
        if aspects.isEmpty {
            lines.append("| - | - | - | - | - |")
        } else {
            lines += aspects.map {
                "| \($0.transitBodyName) | \($0.aspectName) | \($0.natalBodyName) | \(degree($0.separation, digits: 2)) | \(degree($0.orb, digits: 2)) |"
            }
        }

        let bodyNames = transitBodyNameLookup(result.natalPositions)
        if let declinationAspects = result.declinationAspects {
            lines += declinationAspectSection(declinationAspects, names: bodyNames)
        }
        if let starConjunctions = result.natalStarConjunctions {
            lines += fixedStarSection("本命固定星合相", starConjunctions, names: bodyNames)
        }

        lines += warnings(result.warnings)
        return lines.joined(separator: "\n")
    }

    static func moment(_ result: TransitResult) -> String {
        var lines: [String] = [
            "# 时间点行运计算",
            "",
            "## 元数据",
            "",
            "- 本命 UTC：\(result.meta.natalUTC)",
            "- 行运 UTC：\(result.meta.transitUTC)",
            "- 星历：\(result.meta.ephemeris)",
            ""
        ]

        lines += positionSection("本命位置", result.natalPositions)
        lines += positionSection("行运位置", result.transitPositions)

        lines += [
            "## 行运对本命相位",
            "",
            "| 行运 | 相位 | 本命 | 角距 | 容许度 |",
            "| --- | --- | --- | ---: | ---: |"
        ]
        if result.aspects.isEmpty {
            lines.append("| - | - | - | - | - |")
        } else {
            lines += result.aspects.map {
                "| \($0.transitBodyName) | \($0.aspectName) | \($0.natalBodyName) | \(degree($0.separation, digits: 2)) | \(degree($0.orb, digits: 2)) |"
            }
        }

        let bodyNames = transitBodyNameLookup(result.natalPositions)
            .merging(transitBodyNameLookup(result.transitPositions)) { current, _ in current }
        if let declinationAspects = result.declinationAspects {
            lines += declinationAspectSection(declinationAspects, names: bodyNames)
        }
        if let starConjunctions = result.natalStarConjunctions {
            lines += fixedStarSection("本命固定星合相", starConjunctions, names: bodyNames)
        }
        if let starConjunctions = result.transitStarConjunctions {
            lines += fixedStarSection("行运固定星合相", starConjunctions, names: bodyNames)
        }

        lines += warnings(result.warnings)
        return lines.joined(separator: "\n")
    }

    static func positionSection(_ title: String, _ rows: [PositionRow]) -> [String] {
        var lines = [
            "## \(title)",
            "",
            "| 天体 | 黄经 | 宫 | 黄纬 | 赤纬 | 出界 | 速度 |",
            "| --- | --- | ---: | ---: | ---: | --- | ---: |"
        ]
        lines += rows.map {
            let dec = $0.declination.map { degree($0, digits: 4) } ?? ""
            let oob = $0.outOfBounds == true ? "是" : ""
            return "| \($0.name) | \($0.degreeText) | \($0.house.map(String.init) ?? "") | \(degree($0.latitude, digits: 4)) | \(dec) | \(oob) | \(degree($0.speed, digits: 4))/日 |"
        }
        lines.append("")
        return lines
    }

    static func natalAspects(from result: TransitResult) -> [AspectHit] {
        var seen = Set<String>()
        return result.aspects.filter { aspect in
            guard aspect.transitBodyID != aspect.natalBodyID else {
                return false
            }
            let pair = [aspect.transitBodyID, aspect.natalBodyID].sorted().joined(separator: "::")
            let key = "\(pair)::\(aspect.aspectID)"
            guard !seen.contains(key) else {
                return false
            }
            seen.insert(key)
            return true
        }
    }
}
