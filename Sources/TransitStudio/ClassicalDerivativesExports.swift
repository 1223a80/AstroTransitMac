import Foundation

extension MarkdownExportBuilder {
    static func classicalDerivatives(_ result: ClassicalDerivativesResult) -> String {
        var lines = [
            "# classical_derivatives",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Mode: \(result.meta.mode ?? "classical_derivatives")",
            "- Dodeka count: \(result.dodekatemoria.count)",
            "- Monomoiria count: \(result.monomoiria.count)",
            "- Topical almutens: \(result.topicalAlmutens.count)",
            "",
            "## Dodekatemoria",
            "",
            "| Source | Natal | Dodeka | Sign | Ruler | Method |",
            "| --- | ---: | ---: | --- | --- | --- |",
        ]
        for row in result.dodekatemoria.prefix(80) {
            lines.append(
                "| \(row.sourceName ?? row.sourceId ?? "") | \(fmt(row.natalLongitude)) | \(fmt(row.dodekatemorionLongitude)) | \(row.sign ?? "") | \(row.dodekatemorionRuler ?? "") | \(row.methodKey ?? "") |"
            )
        }
        lines += ["", "## Monomoiria", "", "| Source | Degree | Ruler | Method |", "| --- | ---: | --- | --- |"]
        for row in result.monomoiria.prefix(80) {
            lines.append("| \(row.sourceName ?? row.sourceId ?? "") | \(row.degreeIndex.map(String.init) ?? "") | \(row.monomoiriaRuler ?? "") | \(row.methodKey ?? "") |")
        }
        lines += ["", "## Topical Almutens", "", "| Topic | Winner | Score | Method |", "| --- | --- | ---: | --- |"]
        for row in result.topicalAlmutens {
            lines.append("| \(row.topicName ?? row.topicId ?? "") | \(row.winnerId ?? "") | \(row.winnerScore.map(String.init) ?? "") | \(row.methodKey ?? "") |")
        }
        appendDiagnostics(&lines, assumptions: result.calculationAssumptions, warnings: result.warnings, errors: result.sectionErrors)
        return lines.joined(separator: "\n")
    }

    fileprivate static func fmt(_ value: Double?) -> String {
        value.map { String(format: "%.4f", $0) } ?? ""
    }

    fileprivate static func appendDiagnostics(
        _ lines: inout [String],
        assumptions: [String]?,
        warnings: [String],
        errors: [String: String]?
    ) {
        if let a = assumptions, !a.isEmpty {
            lines += ["", "## 计算假设", ""] + a.map { "- \($0)" }
        }
        if warnings.isEmpty {
            lines += ["", "## 警告", "", "无。"]
        } else {
            lines += ["", "## 警告", ""] + warnings.map { "- \($0)" }
        }
        if let errors, !errors.isEmpty {
            lines += ["", "## section_errors", ""]
            for key in errors.keys.sorted() { lines.append("- `\(key)`: \(errors[key] ?? "")") }
        }
        lines += ["", "> 事实输出，不含吉凶解释。"]
    }
}

extension TextExportBuilder {
    static func classicalDerivativesJSON(_ result: ClassicalDerivativesResult) -> String {
        encodePretty(result)
    }

    static func csv(_ result: ClassicalDerivativesResult) -> String {
        var rows = ["row_type,source_id,source_name,longitude,extra,method_key"]
        for row in result.dodekatemoria {
            rows.append("dodeka,\(expansionCSVEscape(row.sourceId ?? "")),\(expansionCSVEscape(row.sourceName ?? "")),\(row.dodekatemorionLongitude.map { String($0) } ?? ""),\(expansionCSVEscape(row.sign ?? "")),\(expansionCSVEscape(row.methodKey ?? ""))")
        }
        for row in result.monomoiria {
            rows.append("monomoiria,\(expansionCSVEscape(row.sourceId ?? "")),\(expansionCSVEscape(row.sourceName ?? "")),\(row.longitude.map { String($0) } ?? ""),\(row.degreeIndex.map(String.init) ?? ""),\(expansionCSVEscape(row.methodKey ?? ""))")
        }
        for row in result.topicalAlmutens {
            rows.append("topical,\(expansionCSVEscape(row.topicId ?? "")),\(expansionCSVEscape(row.topicName ?? "")),\(row.longitude.map { String($0) } ?? ""),\(expansionCSVEscape(row.winnerId ?? "")),\(expansionCSVEscape(row.methodKey ?? ""))")
        }
        return rows.joined(separator: "\n")
    }

    fileprivate static func encodePretty<T: Encodable>(_ value: T) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(value), let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    static func expansionCSVEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
