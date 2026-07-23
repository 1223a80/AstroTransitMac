import Foundation

extension MarkdownExportBuilder {
    static func primaryDirectionsAudit(_ result: PrimaryDirectionsAuditResult) -> String {
        var lines = [
            "# primary_directions_audit",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Algorithm: \(result.meta.algorithmName ?? "—")",
            "- Directions: \(result.directions.count)",
            "",
            "## Directions",
            "",
            "| Promissor | Significator | Dir | Arc | Age | Method |",
            "| --- | --- | --- | ---: | ---: | --- |",
        ]
        for d in result.directions {
            lines.append(
                "| \(d.promissor ?? d.promissorId ?? "") | \(d.significator ?? d.significatorId ?? "") | \(d.directionType ?? "") | \(d.arcSigned.map { String(format: "%.4f", $0) } ?? "") | \(d.ageFromAbsArc.map { String(format: "%.3f", $0) } ?? "") | \(d.methodKey ?? d.algorithmName ?? "") |"
            )
        }
        lines += ["", "## 算法说明", ""]
        if let algorithm = result.algorithmDescriptionPayload {
            lines.append("- 名称：\(algorithm.name ?? "—")")
            lines.append("- Key：`\(algorithm.key ?? "—")`")
            lines.append("- 外部核对状态：\(algorithm.externalCrosscheckStatus ?? "—")")
            if let note = algorithm.externalCrosscheckNote, !note.isEmpty {
                lines.append("- 核对说明：\(note)")
            }
            if let limits = algorithm.knownLimits, !limits.isEmpty {
                lines.append("- 已知限制：")
                lines.append(contentsOf: limits.map { "  - \($0)" })
            }
        } else {
            lines.append("无结构化算法说明。")
        }
        if let a = result.calculationAssumptions, !a.isEmpty {
            lines += ["", "## 计算假设", ""] + a.map { "- \($0)" }
        }
        if let errors = result.sectionErrors, !errors.isEmpty {
            lines += ["", "## 未计算 / section_errors", ""]
            for key in errors.keys.sorted() {
                lines.append("- `\(key)`: \(errors[key] ?? "")")
            }
        }
        lines += ["", "## 警告", ""]
        if result.warnings.isEmpty {
            lines.append("无。")
        } else {
            lines.append(contentsOf: result.warnings.map { "- \($0)" })
        }
        lines += ["", "> AUDIT of simplified PD proxy — not complete traditional primary directions."]
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func primaryDirectionsAuditJSON(_ result: PrimaryDirectionsAuditResult) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(result), let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    static func csv(_ result: PrimaryDirectionsAuditResult) -> String {
        var rows = ["row_type,id,promissor_id,significator_id,direction_type,arc_signed,age_from_abs_arc,method_key"]
        for d in result.directions {
            rows.append(
                "direction,\(expansionCSVEscape(d.id)),\(expansionCSVEscape(d.promissorId ?? "")),\(expansionCSVEscape(d.significatorId ?? "")),\(expansionCSVEscape(d.directionType ?? "")),\(d.arcSigned.map { String($0) } ?? ""),\(d.ageFromAbsArc.map { String($0) } ?? ""),\(expansionCSVEscape(d.methodKey ?? d.algorithmName ?? ""))"
            )
        }
        return rows.joined(separator: "\n")
    }
}
