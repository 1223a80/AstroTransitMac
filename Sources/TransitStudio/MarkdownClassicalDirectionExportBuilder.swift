import Foundation

extension MarkdownExportBuilder {
    static func primaryDirectionSection(_ rows: [PrimaryDirection]) -> [String] {
        let converse = rows.filter { $0.directionType == "converse" }
        let direct = rows.filter { $0.directionType != "converse" }

        guard !direct.isEmpty || !converse.isEmpty else { return [] }

        var lines: [String] = [
            "---",
            "",
            "### Primary Directions",
            "",
        ]
        if !converse.isEmpty {
            lines.append("#### \(converse.count) 条逆推方向")
            lines.append("")
            lines.append("| Promissor | Significator | 相位 | Arc | 年龄 | 日期 | 备注 |")
            lines.append("| --- | --- | --- | ---: | ---: | --- | --- |")
            for d in converse {
                lines.append("| \(d.promissor) | \(d.significator) | \(d.aspectName) | \(String(format: "%+.2f°", d.arcSigned ?? 0)) | \(String(format: "%.1f", d.ageFromAbsArc)) | \(d.symbolicDateFromSignedArc ?? "") | 出生前符号日 |")
            }
            lines.append("")
        }
        if !direct.isEmpty {
            lines.append("#### \(direct.count) 条顺推方向")
            lines.append("")
            lines.append("| Promissor | Significator | 相位 | Arc | 年龄 | 日期 | 备注 |")
            lines.append("| --- | --- | --- | ---: | ---: | --- | --- |")
            for d in direct {
                lines.append("| \(d.promissor) | \(d.significator) | \(d.aspectName) | \(String(format: "%+.2f°", d.arcSigned ?? 0)) | \(String(format: "%.1f", d.ageFromAbsArc)) | \(d.eventDateAfterBirth ?? "") | 顺推 |")
            }
            lines.append("")
        }
        return lines
    }

    static func circumambulationSection(_ rows: [Circumambulation]) -> [String] {
        var lines = [
            "## Circumambulations through the Bounds（沿界推进）",
            ""
        ]
        for circ in rows {
            lines += [
                "- 系统：\(circ.system)",
                "- Naibod rate：\(String(format: "%.4f", circ.naibodRate))°/年",
                "- 当前界主：\(circ.currentRuler)",
                "- 当前界信息：\(circ.currentBoundInfo ?? "")",
                "",
                "| 星座 | 度数 | 界主 | Arc | 年龄 | 日期 |",
                "| --- | ---: | --- | ---: | ---: | --- |"
            ]
            lines += circ.boundaries.prefix(30).map {
                "| \($0.sign) | \($0.endDegree)° | \($0.ruler) | \(String(format: "%.2f°", $0.arcValue)) | \(String(format: "%.1f", $0.ageAtBoundary)) | \($0.estimatedDate) |"
            }
            lines.append("")
        }
        return lines
    }
}
