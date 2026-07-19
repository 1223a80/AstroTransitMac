import Foundation

extension MarkdownExportBuilder {
    static func timeLordsExtended(_ result: TimeLordsExtendedResult) -> String {
        var lines = [
            "# time_lords_extended",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Fortune λ: \(result.meta.fortuneLongitude.map { String(format: "%.6f", $0) } ?? "—")",
            "- Spirit λ: \(result.meta.spiritLongitude.map { String(format: "%.6f", $0) } ?? "—")",
            "",
            "## Daily profection",
            "",
            "- Sign: \(result.dailyProfection?.activatedSign ?? "—")",
            "- Lord id: \(result.dailyProfection?.lordId ?? result.dailyProfection?.lord ?? "—")",
            "- Method: \(result.dailyProfection?.methodKey ?? "—")",
            "",
            "## Revolutions concordance",
            "",
            "| Body | Name | Count | Techniques |",
            "| --- | --- | ---: | --- |",
        ]
        for row in result.revolutionsConcordance {
            lines.append("| \(row.bodyId) | \(row.bodyName ?? "") | \(row.count.map(String.init) ?? "") | \(row.techniques.joined(separator: "; ")) |")
        }
        if let zr = result.zodiacalReleasing {
            lines += ["", "## Zodiacal Releasing (raw)", "", "```json", nestedJSONString(zr), "```"]
        }
        if let a = result.calculationAssumptions, !a.isEmpty {
            lines += ["", "## 计算假设", ""] + a.map { "- \($0)" }
        }
        if result.warnings.isEmpty {
            lines += ["", "## 警告", "", "无。"]
        } else {
            lines += ["", "## 警告", ""] + result.warnings.map { "- \($0)" }
        }
        if let errors = result.sectionErrors, !errors.isEmpty {
            lines += ["", "## section_errors", ""]
            for key in errors.keys.sorted() { lines.append("- `\(key)`: \(errors[key] ?? "")") }
        }
        lines += ["", "> 事实输出，不含吉凶解释。"]
        return lines.joined(separator: "\n")
    }

    fileprivate static func nestedJSONString(_ value: NestedJSON) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(value), let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }
}

extension TextExportBuilder {
    static func timeLordsExtendedJSON(_ result: TimeLordsExtendedResult) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(result), let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    static func csv(_ result: TimeLordsExtendedResult) -> String {
        var rows = ["row_type,body_id,body_name,count,techniques,method_key"]
        for row in result.revolutionsConcordance {
            rows.append(
                "concordance,\(expansionCSVEscape(row.bodyId)),\(expansionCSVEscape(row.bodyName ?? "")),\(row.count.map(String.init) ?? ""),\(expansionCSVEscape(row.techniques.joined(separator: ";"))),,"
            )
        }
        if let d = result.dailyProfection {
            rows.append(
                "daily_profection,\(expansionCSVEscape(d.lordId ?? d.lord ?? "")),\(expansionCSVEscape(d.activatedSign ?? "")),,,\(expansionCSVEscape(d.methodKey ?? ""))"
            )
        }
        rows.append("meta,fortune_longitude,,\(result.meta.fortuneLongitude.map { String($0) } ?? ""),,")
        rows.append("meta,spirit_longitude,,\(result.meta.spiritLongitude.map { String($0) } ?? ""),,")
        return rows.joined(separator: "\n")
    }
}
