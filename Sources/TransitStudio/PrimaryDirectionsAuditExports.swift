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
        for d in result.directions.prefix(100) {
            lines.append(
                "| \(d.promissor ?? d.promissorId ?? "") | \(d.significator ?? d.significatorId ?? "") | \(d.directionType ?? "") | \(d.arcSigned.map { String(format: "%.4f", $0) } ?? "") | \(d.ageFromAbsArc.map { String(format: "%.3f", $0) } ?? "") | \(d.methodKey ?? d.algorithmName ?? "") |"
            )
        }
        if let a = result.calculationAssumptions, !a.isEmpty {
            lines += ["", "## 计算假设 / known limits", ""] + a.map { "- \($0)" }
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
