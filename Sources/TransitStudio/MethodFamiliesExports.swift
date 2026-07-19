import Foundation

extension MarkdownExportBuilder {
    static func methodFamilies(_ result: MethodFamiliesResult) -> String {
        var lines = [
            "# method_families",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Age years: \(result.meta.ageYears.map { String(format: "%.6f", $0) } ?? "—")",
            "- True solar arc°: \(result.meta.trueSolarArcDeg.map { String(format: "%.6f", $0) } ?? "—")",
            "",
            "## Progression profiles (ASC/MC)",
            "",
        ]
        for pack in result.progressionProfiles {
            lines += ["### \(pack.profileId)", "", pack.description ?? "", ""]
            lines += ["| Body | Natal | Progressed | Method |", "| --- | ---: | ---: | --- |"]
            for row in pack.rows where row.bodyId == "ASC" || row.bodyId == "MC" || row.component == "angle" {
                lines.append(
                    "| \(row.bodyId) | \(row.natalLongitude.map { String(format: "%.4f", $0) } ?? "") | \(row.progressedLongitude.map { String(format: "%.4f", $0) } ?? "") | \(row.methodKey ?? "") |"
                )
            }
            lines.append("")
        }
        lines += ["## Solar arc profiles", ""]
        for pack in result.solarArcProfiles {
            lines.append("- `\(pack.profileId)` arc_deg=\(pack.arcDeg.map { String(format: "%.6f", $0) } ?? "—") method_key present on rows")
        }
        if let a = result.calculationAssumptions, !a.isEmpty {
            lines += ["", "## 计算假设", ""] + a.map { "- \($0)" }
        }
        lines += ["", "> 事实输出，不含吉凶解释。"]
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func methodFamiliesJSON(_ result: MethodFamiliesResult) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(result), let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    static func csv(_ result: MethodFamiliesResult) -> String {
        var rows = ["row_type,profile_id,body_id,natal_longitude,progressed_or_sa_longitude,arc_deg,method_key"]
        for pack in result.progressionProfiles {
            for row in pack.rows {
                rows.append(
                    "progression,\(expansionCSVEscape(pack.profileId)),\(expansionCSVEscape(row.bodyId)),\(row.natalLongitude.map { String($0) } ?? ""),\(row.progressedLongitude.map { String($0) } ?? ""),,\(expansionCSVEscape(row.methodKey ?? ""))"
                )
            }
        }
        for pack in result.solarArcProfiles {
            for row in pack.rows {
                rows.append(
                    "solar_arc,\(expansionCSVEscape(pack.profileId)),\(expansionCSVEscape(row.bodyId)),\(row.natalLongitude.map { String($0) } ?? ""),\(row.solarArcLongitude.map { String($0) } ?? ""),\(row.arcDeg.map { String($0) } ?? ""),\(expansionCSVEscape(row.methodKey ?? ""))"
                )
            }
        }
        return rows.joined(separator: "\n")
    }
}
