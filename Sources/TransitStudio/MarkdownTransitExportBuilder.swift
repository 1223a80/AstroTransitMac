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

        if let angles = result.angles {
            lines += [
                "## 轴点",
                "",
                "| 轴点 | 位置 | 宫 |",
                "| --- | --- | ---: |"
            ]
            lines += angles.map { "| \($0.name) | \($0.degreeText) | \($0.house) |" }
            lines.append("")
        }
        if let houses = result.houses {
            lines += [
                "## 宫头",
                "",
                "| 宫 | 宫头 | 主星 |",
                "| ---: | --- | --- |"
            ]
            lines += houses.map { "| \($0.house) | \($0.cuspText) | \($0.ruler) |" }
            lines.append("")
        }

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
        if let profile = result.chartProfile {
            lines += chartProfileSection(profile)
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

    private static func chartProfileSection(_ profile: ChartProfile) -> [String] {
        var lines = [
            "## 结构统计",
            "",
            "- 统计点集：\(profile.pointIDs.joined(separator: ", "))",
            "- 元素：\(profile.elements.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))",
            "- 模式：\(profile.modalities.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))",
            "- 阴阳：\(profile.polarities.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))",
            "- 半球：\(profile.hemispheres.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))",
            "- 象限：\(profile.quadrants.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))",
        ]
        if !profile.omittedSections.isEmpty {
            lines.append("- 未计算：\(profile.omittedSections.joined(separator: ", "))")
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
