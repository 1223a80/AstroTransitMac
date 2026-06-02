import Foundation

extension MarkdownExportBuilder {
    static func almutenSection(_ almuten: AlmutenFiguris) -> [String] {
        var lines = [
            "## Almuten Figuris（全盘最尊贵行星）",
            "",
        ]
        if let winner = almuten.winner {
            lines.append("- 最尊贵行星：**\(winner)**")
        }
        if let table = almuten.scoreTable {
            lines += [
                "",
                "| 行星 | 总分 | 明细 |",
                "| --- | ---: | --- |",
            ]
            for entry in table.prefix(7) {
                let contribs = entry.contributions.map { "\($0.point)(\($0.dignity)+\($0.weight))" }.joined(separator: " ")
                lines.append("| \(entry.planet) | \(entry.total) | \(contribs) |")
            }
        }
        lines.append("")
        return lines
    }

    static func hylegSection(_ hyleg: HylegAlcocoden) -> [String] {
        var lines = [
            "## Hyleg / Alcocoden（生命主星）",
            "",
        ]
        if let h = hyleg.hyleg {
            if let selected = h.selected, !selected.isEmpty {
                lines += [
                    "- **Hyleg**：\(selected)",
                ]
                if let reason = h.reason {
                    lines.append("- 理由：\(reason)")
                }
            } else {
                lines.append("- Hyleg：无合格候选")
            }
            if let candidates = h.candidates, !candidates.isEmpty {
                lines += [
                    "",
                    "| Hyleg 候选 | 宫位 | 状态 | 理由 |",
                    "| --- | ---: | --- | --- |",
                ]
                for c in candidates {
                    lines.append("| \(c.name) | \(c.house ?? 0) | \(c.eligible == true ? "selected/eligible" : "rejected") | \(c.reason) |")
                }
            }
        }
        if let a = hyleg.alcocoden {
            if let selected = a.selected, !selected.isEmpty {
                lines += [
                    "- **Alcocoden**：\(selected)",
                ]
                if let dignity = a.dignity {
                    lines.append("- 尊贵：\(dignity)")
                }
            }
            if let candidates = a.candidates, !candidates.isEmpty {
                lines += [
                    "",
                    "| Alcocoden 候选 | 尊贵 | 权重 | 见 Hyleg | 自身状态 | 理由 |",
                    "| --- | --- | ---: | --- | --- | --- |",
                ]
                for c in candidates {
                    lines.append("| \(c.planet) | \(c.dignityAtHyleg) | \(c.weight) | \(c.seesHyleg == true ? "yes" : "no") | \(c.ownConditionSummary ?? "") | \(c.reason ?? "") |")
                }
            }
        }
        if let warn = hyleg.warning {
            lines.append("- 备注：\(warn)")
        }
        lines.append("")
        return lines
    }

    static func prenatalSyzygySection(_ syzygy: PrenatalSyzygy) -> [String] {
        var lines = [
            "## 产前朔望（Prenatal Syzygy）",
            "",
        ]
        let type = syzygy.syzygyType == "new_moon" ? "朔月（New Moon）" : "望月（Full Moon）"
        lines.append("- 类型：\(type)")
        if let utc = syzygy.exactUTC {
            lines.append("- 精确 UTC：\(utc)")
        }
        if let sun = syzygy.sunPosition, let moon = syzygy.moonPosition {
            lines.append("- 日月黄经：Sun \(String(format: "%.4f", sun))° / Moon \(String(format: "%.4f", moon))°")
        }
        if let sign = syzygy.sign, let deg = syzygy.degree {
            lines.append("- 位置：\(sign) \(String(format: "%.1f", deg))°")
        }
        if let source = syzygy.syzygyDegreeUsed {
            lines.append("- syzygy_degree_used：\(source)")
        }
        if let ruler = syzygy.ruler {
            lines.append("- 主星：\(ruler)")
        }
        lines.append("")
        return lines
    }
}
