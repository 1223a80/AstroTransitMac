import Foundation

extension MarkdownExportBuilder {
    static func distributionsPd(_ result: DistributionsPdResult) -> String {
        var lines = [
            "# distributions_pd",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Mode: \(result.meta.mode ?? "distributions_pd")",
        ]
        if let a = result.calculationAssumptions, !a.isEmpty {
            lines += ["", "## 计算假设", ""] + a.map { "- \($0)" }
        }
        if result.warnings.isEmpty {
            lines += ["", "## 警告", "", "无。"]
        } else {
            lines += ["", "## 警告", ""] + result.warnings.map { "- \($0)" }
        }
        if let errors = result.sectionErrors, !errors.isEmpty {
            lines += ["", "## 未计算 / section_errors", ""]
            for key in errors.keys.sorted() { lines.append("- `\(key)`: \(errors[key] ?? "")") }
        } else {
            lines += ["", "## 未计算 / section_errors", "", "无。"]
        }
        lines += ["", "> 事实输出，不含吉凶解释。"]
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func distributionsPdJSON(_ result: DistributionsPdResult) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(result), let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }
    static func csv(_ result: DistributionsPdResult) -> String {
        var rows = ["row_type,field,value"]
        rows.append("meta,method,\(result.meta.method)")
        for (i, a) in (result.calculationAssumptions ?? []).enumerated() {
            rows.append("assumption,\(i),\(a.replacingOccurrences(of: ",", with: ";"))")
        }
        return rows.joined(separator: "\n")
    }
}
