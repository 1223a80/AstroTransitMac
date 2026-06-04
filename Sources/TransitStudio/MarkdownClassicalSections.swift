import Foundation

extension MarkdownExportBuilder {
    static func pointSection(_ title: String, _ rows: [ClassicalPoint]) -> [String] {
        var lines = [
            "## \(title)",
            "",
            "| 名称 | 位置 | 宫位 | 主星 | 公式 |",
            "| --- | --- | ---: | --- | --- |"
        ]
        lines += rows.map {
            "| \($0.name) | \($0.degreeText) | \($0.house) | \($0.ruler) | \($0.formula ?? "") |"
        }
        lines.append("")
        return lines
    }

    static func houseSection(_ rows: [HouseRow]) -> [String] {
        var lines = [
            "## 宫位",
            "",
            "| 宫位 | 宫头 | 主星 |",
            "| ---: | --- | --- |"
        ]
        lines += rows.map { "| \($0.house) | \($0.cuspText) | \($0.ruler) |" }
        lines.append("")
        return lines
    }

    static func planetSection(_ rows: [ClassicalPlanetRow]) -> [String] {
        var lines = [
            "## 七政状态",
            "",
            "| 星体 | 位置 | 宫 | 运动 | Sect | 庙旺 | 三分 | 界 | 面 | 太阳状态 | Hayz/Joy | 行星年 | 评分 | 善待 | 虐待 | 备注 |",
            "| --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- |"
        ]
        lines += rows.map {
            let dignity = [$0.domicile, $0.exaltation].filter { !$0.isEmpty }.joined(separator: " ")
            let hayzJoy = [$0.hayz, $0.joy].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "/")
            let py = $0.planetaryYears.map { "\($0)y" } ?? ""
            return "| \($0.name) | \($0.degreeText) | \($0.house) | \($0.motion) | \($0.sectStatus) | \(dignity) | \($0.triplicity) | \($0.bound) | \($0.decan) | \($0.solarPhase) | \(hayzJoy) | \(py) | \($0.score) | \($0.bonification.count) | \($0.maltreatment.count) | \(($0.notes ?? []).joined(separator: "、")) |"
        }
        lines.append("")
        return lines
    }

    static func classicalAspectSection(_ rows: [ClassicalAspectRow]) -> [String] {
        var lines = [
            "## 相位",
            "",
            "| A | 相位 | B | 类型 | 容许度 | 入离 |",
            "| --- | --- | --- | --- | ---: | --- |"
        ]
        lines += rows.map {
            "| \($0.bodyA) | \($0.aspect) | \($0.bodyB) | \($0.aspectType) | \($0.orb.map { degree($0, digits: 2) } ?? "") | \($0.applying ?? "") |"
        }
        lines.append("")
        return lines
    }

    static func receptionSection(_ rows: [ReceptionRow]) -> [String] {
        var lines = [
            "## 接纳",
            "",
            "| 接纳者 | 被接纳 | 尊贵 | 经由相位 | 强度 |",
            "| --- | --- | --- | --- | --- |"
        ]
        lines += rows.map { "| \($0.receiver) | \($0.received) | \($0.dignity) | \($0.viaAspect) | \($0.strengthLabel ?? "") |" }
        lines.append("")
        return lines
    }

    static func antisciaSection(_ rows: [AntisciaRow]) -> [String] {
        var lines = [
            "## 映点 / 反映点",
            "",
            "| 行星 | 映点位置 | 反映点位置 | 本命命中 |",
            "| --- | --- | --- | --- |"
        ]
        for row in rows {
            let hits = row.natalHits.isEmpty ? "—" : row.natalHits.map { "\($0.via): \($0.hitPlanet) (\(String(format: "%.1f°", $0.orb)))" }.joined(separator: "; ")
            lines.append("| \(row.planet) | \(row.antisciaDegree) | \(row.contraDegree) | \(hits) |")
        }
        lines.append("")
        return lines
    }

    static func scoreSummarySection(_ rows: [ClassicalPlanetRow]) -> [String] {
        guard !rows.isEmpty else { return [] }
        var lines = [
            "## 评分总表",
            "",
            "| 星体 | 总分 | 状态标签 |",
            "| --- | ---: | --- |"
        ]
        for planet in rows {
            let label = planet.scoreLabel ?? ""
            lines.append("| \(planet.name) | \(planet.score) | \(label) |")
        }
        lines.append("")
        lines += [
            "",
            "### 详细评分明细",
            "",
            "| 星体 | 评分项 | 值 | 分值 |",
            "| --- | --- | --- | ---: |"
        ]
        for planet in rows {
            for item in planet.scoreBreakdown {
                let sign = item.score >= 0 ? "+" : ""
                lines.append("| \(planet.name) | \(item.label) | \(item.value) | \(sign)\(item.score) |")
            }
        }
        lines.append("")
        return lines
    }

    static func triplicitySummarySection(_ rows: [ClassicalPlanetRow]) -> [String] {
        guard !rows.isEmpty else { return [] }
        var lines = [
            "## 三分主评估总表",
            "",
            "| 星体 | 角色 | 主星 | 评分 | 状态 | 备注 |",
            "| --- | --- | --- | ---: | --- | --- |"
        ]
        for planet in rows {
            guard let details = planet.triplicityDetails, !details.isEmpty else { continue }
            for detail in details {
                lines.append("| \(planet.name) | \(detail.label) | \(detail.ruler) | \(detail.score) | \(detail.status) | \(detail.notes.joined(separator: "、")) |")
            }
        }
        lines.append("")
        return lines
    }
}
