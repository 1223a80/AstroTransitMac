import Foundation

extension MarkdownExportBuilder {
    static func hellenisticConditionAudit(_ result: HellenisticConditionAuditResult) -> String {
        var lines = [
            "# Hellenistic 行星状态审计",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Source profile: \(result.meta.sourceProfile ?? "")",
            "- Birth UTC: \(result.meta.birthUTC ?? "")",
            "- Day chart: \(result.meta.isDay.map { $0 ? "yes" : "no" } ?? "")",
            "- Condition count: \(result.meta.conditionCount.map(String.init) ?? "\(result.conditions.count)")",
            "",
            "## 条件证据表",
            "",
        ]
        if result.conditions.isEmpty {
            lines.append("无条件行。")
        } else {
            lines += [
                "| Subject | Condition | Geometry | Actors | Orb | Evidence |",
                "| --- | --- | --- | --- | ---: | --- |",
            ]
            for row in result.conditions {
                let evidence = (row.evidence ?? []).joined(separator: "; ").replacingOccurrences(of: "|", with: "/")
                lines.append(
                    "| \(row.subject) | \(row.conditionID) | \(row.geometry ?? "") | \((row.actors ?? []).joined(separator: ",")) | \(row.orb.map { String(format: "%.3f", $0) } ?? "—") | \(evidence) |"
                )
            }
        }
        if let assumptions = result.calculationAssumptions, !assumptions.isEmpty {
            lines += ["", "## 计算假设", ""]
            for item in assumptions { lines.append("- \(item)") }
        }
        if let errors = result.sectionErrors, !errors.isEmpty {
            lines += ["", "## 未计算 / section_errors", ""]
            for key in errors.keys.sorted() { lines.append("- `\(key)`: \(errors[key] ?? "")") }
        } else {
            lines += ["", "## 未计算 / section_errors", "", "无。"]
        }
        if result.warnings.isEmpty {
            lines += ["", "## 警告", "", "无。"]
        } else {
            lines += ["", "## 警告", ""]
            for w in result.warnings { lines.append("- \(w)") }
        }
        lines += ["", "> 本文输出证据事实，不合成吉凶分数。"]
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func hellenisticConditionAuditJSON(_ result: HellenisticConditionAuditResult) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(result), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    static func csv(_ result: HellenisticConditionAuditResult) -> String {
        var rows = ["row_type,condition_id,subject,actors,geometry,applying_separating,orb,evidence"]
        for row in result.conditions {
            let evidence = (row.evidence ?? []).joined(separator: " | ")
            rows.append(
                [
                    "condition",
                    csvEscape(row.conditionID),
                    csvEscape(row.subject),
                    csvEscape((row.actors ?? []).joined(separator: ";")),
                    csvEscape(row.geometry ?? ""),
                    csvEscape(row.applyingSeparating ?? ""),
                    row.orb.map { String(format: "%.6f", $0) } ?? "",
                    csvEscape(evidence),
                ].joined(separator: ",")
            )
        }
        return rows.joined(separator: "\n")
    }

    fileprivate static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
