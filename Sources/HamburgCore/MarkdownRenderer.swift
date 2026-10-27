import Foundation

public enum HamburgMarkdownRenderer {
    public static func render(_ report: HamburgReport) -> String {
        var lines: [String] = []
        lines.append("# 汉堡占星 / 乌拉尼亚计算报告")
        lines.append("")
        lines.append("- 引擎：\(report.meta.engine) \(report.meta.version)（\(report.meta.method)）")
        lines.append("- UTC：\(report.meta.momentUTC ?? "—")")
        if let reference = report.meta.referenceUTC {
            lines.append("- 参考时刻 UTC：\(reference)")
        }
        if let location = report.meta.location {
            lines.append(
                "- 地点：纬度 \(format(location.latitude, 4))，经度 \(format(location.longitude, 4))，时区 \(location.timezone ?? "—")"
            )
        }
        lines.append("- Dial：\(format(report.meta.dialModulus, 1))°；orb 单位：\(report.meta.orbUnit)；中点 orb：\(format(report.meta.midpointOrb, 2))；图像 orb：\(format(report.meta.pictureOrb, 2))")
        lines.append("- 点数：\(report.meta.pointCount)；TNP 模型：\(report.meta.tnpModel)")
        lines.append("- 星历：\(report.meta.ephemeris)")
        lines.append("")

        lines.append("## 星体位置")
        lines.append("")
        lines.append("| 点 | 黄经 | 星座度数 | 宫 | \(format(report.meta.dialModulus, 1))° dial | 来源 |")
        lines.append("| --- | ---: | --- | ---: | ---: | --- |")
        for position in report.positions {
            let dial = dialValue(position.dials, modulus: report.meta.dialModulus)
            lines.append(
                "| \(cell(position.name)) (`\(cell(position.id))`) | \(format(position.longitude, 6))° | \(cell(position.degreeText)) | \(position.house.map(String.init) ?? "—") | \(format(dial, 4))° | \(cell(position.source)) |"
            )
        }
        lines.append("")

        let tnps = report.positions.filter { $0.kind == ChartPoint.Kind.transneptunian.rawValue }
        if !tnps.isEmpty {
            lines.append("## 八颗 TNP")
            lines.append("")
            lines.append("| TNP | 黄经 | 星座度数 | 关键词 |")
            lines.append("| --- | ---: | --- | --- |")
            for tnp in tnps {
                let keywords = (tnp.keywordsZh.isEmpty ? tnp.keywords : tnp.keywordsZh).joined(separator: "、")
                lines.append(
                    "| \(cell(tnp.name)) (`\(cell(tnp.id))`) | \(format(tnp.longitude, 6))° | \(cell(tnp.degreeText)) | \(cell(keywords)) |"
                )
            }
            lines.append("")
        }

        lines.append("## 宫位（\(report.houses.system)）")
        lines.append("")
        lines.append("| 宫 | 宫头 | 星座度数 |")
        lines.append("| ---: | ---: | --- |")
        for cusp in report.houses.cusps {
            lines.append("| \(cusp.house) | \(format(cusp.longitude, 6))° | \(cell(cusp.degreeText)) |")
        }
        lines.append("")

        lines.append("## 中点树")
        lines.append("")
        if report.trees.isEmpty {
            lines.append("没有请求焦点，或焦点不在盘中。")
            lines.append("")
        } else {
            for tree in report.trees {
                lines.append("### \(cell(tree.focusName)) (`\(cell(tree.focus))`)")
                lines.append("")
                if tree.hits.isEmpty {
                    lines.append("当前 orb 内没有中点命中。")
                    lines.append("")
                    continue
                }
                lines.append("| 公式 | 轴黄经 | 分支 | 谐波 | orb(360°等价) | orb(dial) |")
                lines.append("| --- | ---: | --- | ---: | ---: | ---: |")
                for hit in tree.hits {
                    lines.append(
                        "| \(cell(hit.formula)) | \(format(hit.axisLongitude, 6))° | \(cell(hit.branch)) | \(hit.harmonic) | \(format(hit.orb, 4))° | \(format(hit.orbDial, 4))° |"
                    )
                }
                lines.append("")
            }
        }

        lines.append("## 行星图像（A + B = C + D）")
        lines.append("")
        if report.pictures.isEmpty {
            lines.append("当前 orb 内没有四因子和等式命中。")
            lines.append("")
        } else {
            lines.append("| 公式 | dial 位置 | orb(360°等价) | orb(dial) |")
            lines.append("| --- | ---: | ---: | ---: |")
            for picture in report.pictures {
                lines.append(
                    "| \(cell(picture.formula)) | \(format(picture.dialLongitude, 4))° | \(format(picture.orb, 4))° | \(format(picture.orbDial, 4))° |"
                )
            }
            lines.append("")
        }

        if let solarArc = report.solarArc {
            lines.append("## 太阳弧")
            lines.append("")
            lines.append("- 方法：\(solarArc.method)；年龄：\(format(solarArc.ageYears, 4)) 年；弧：\(format(solarArc.arcDegrees, 6))°")
            if let converse = solarArc.converseArcDegrees {
                lines.append("- 逆向弧：\(format(converse, 6))°")
            }
            lines.append("")
            lines.append("### SA → 本命点")
            lines.append("")
            if solarArc.pointHits.isEmpty {
                lines.append("没有 orb 内的点命中。")
                lines.append("")
            } else {
                lines.append("| 公式 | SA 黄经 | 本命黄经 | orb(360°等价) | orb(dial) | 方向 |")
                lines.append("| --- | ---: | ---: | ---: | ---: | --- |")
                for hit in solarArc.pointHits {
                    lines.append(
                        "| \(cell(hit.formula)) | \(format(hit.directedLongitude, 6))° | \(format(hit.natalLongitude, 6))° | \(format(hit.orb, 4))° | \(format(hit.orbDial, 4))° | \(cell(hit.direction)) |"
                    )
                }
                lines.append("")
            }
            lines.append("### SA → 本命中点")
            lines.append("")
            if solarArc.midpointHits.isEmpty {
                lines.append("没有 orb 内的中点命中。")
                lines.append("")
            } else {
                lines.append("| 公式 | 轴黄经 | orb(360°等价) | orb(dial) | 方向 |")
                lines.append("| --- | ---: | ---: | ---: | --- |")
                for hit in solarArc.midpointHits {
                    lines.append(
                        "| \(cell(hit.formula)) | \(format(hit.axisLongitude, 6))° | \(format(hit.orb, 4))° | \(format(hit.orbDial, 4))° | \(cell(hit.direction)) |"
                    )
                }
                lines.append("")
            }
        }

        if let antiscia = report.antiscia {
            lines.append("## 映点")
            lines.append("")
            lines.append("### 映点 → 本命点")
            lines.append("")
            if antiscia.pointContacts.isEmpty {
                lines.append("没有 orb 内的点命中。")
                lines.append("")
            } else {
                lines.append("| 公式 | 投影黄经 | 目标黄经 | orb(360°等价) | orb(dial) |")
                lines.append("| --- | ---: | ---: | ---: | ---: |")
                for hit in antiscia.pointContacts {
                    lines.append(
                        "| \(cell(hit.formula)) | \(format(hit.projectedLongitude, 6))° | \(format(hit.targetLongitude, 6))° | \(format(hit.orb, 4))° | \(format(hit.orbDial, 4))° |"
                    )
                }
                lines.append("")
            }
            lines.append("### 映点 → 本命中点")
            lines.append("")
            if antiscia.midpointContacts.isEmpty {
                lines.append("没有 orb 内的中点命中。")
                lines.append("")
            } else {
                lines.append("| 公式 | 轴黄经 | orb(360°等价) | orb(dial) |")
                lines.append("| --- | ---: | ---: | ---: |")
                for hit in antiscia.midpointContacts {
                    lines.append(
                        "| \(cell(hit.formula)) | \(format(hit.axisLongitude, 6))° | \(format(hit.orb, 4))° | \(format(hit.orbDial, 4))° |"
                    )
                }
                lines.append("")
            }
        }

        if !report.warnings.isEmpty {
            lines.append("## 警告")
            lines.append("")
            for warning in report.warnings {
                lines.append("- \(warning)")
            }
            lines.append("")
        }

        lines.append("## 方法与来源")
        lines.append("")
        lines.append("- 标准点来源：\(report.meta.ephemeris)；8 颗 TNP 在 Swift 内用 Neely 1980 J1900 根数与 Kepler 传播计算。")
        lines.append("- TNP 地心位置采用 J1900→date 的 IAU 1976 岁差、光行时迭代与太阳地心矢量；与 Swiss Ephemeris 的对照误差通常小于 0.02°。")
        lines.append("- 汉堡宫制为等宫，0° 天秤 = I 宫；这是 Witte 的传统设定，不是 Placidus 宫头。")
        lines.append("- orb 同时给出 360° 黄经等价值与 dial 度数；两者不是同一个量，阅读时请先确认 `orb_unit`。")
        lines.append("- TNP 是汉堡学派的数学假想点，不是已确认的天文实体。")
        return lines.joined(separator: "\n")
    }

    private static func dialValue(_ dials: [DialValue], modulus: Double) -> Double {
        dials.first(where: { abs($0.modulus - modulus) < 1e-9 })?.longitude
            ?? dials.first?.longitude
            ?? 0
    }

    private static func format(_ value: Double, _ digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }

    private static func cell(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
    }
}
