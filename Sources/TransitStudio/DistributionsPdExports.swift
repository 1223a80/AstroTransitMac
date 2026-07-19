import Foundation

extension MarkdownExportBuilder {
    static func distributionsPd(_ result: DistributionsPdResult) -> String {
        var lines = [
            "# distributions_pd",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Baseline: \(result.meta.baselineAlgorithm ?? "—")",
            "- Distributions: \(result.distributions.count)",
            "- PD by profile: \(result.primaryDirectionsByProfile.count)",
            "",
            "## Distributions",
            "",
            "| Significator | Lon | Bounds | Method |",
            "| --- | ---: | --- | --- |",
        ]
        for d in result.distributions {
            lines.append("| \(d.significator ?? "") | \(d.significatorLongitude.map { String(format: "%.4f", $0) } ?? "") | \(d.boundsSystem ?? "") | \(d.methodKey ?? "") |")
        }
        lines += [
            "",
            "## Primary directions by profile",
            "",
            "| Profile | ID | Dir | Arc | Age | Key rate |",
            "| --- | --- | --- | ---: | ---: | ---: |",
        ]
        for d in result.primaryDirectionsByProfile {
            lines.append(
                "| \(d.methodProfile ?? d.methodKey ?? "") | \(d.directionId) | \(d.directionType ?? "") | \(d.arcSigned.map { String(format: "%.4f", $0) } ?? "") | \(d.ageFromAbsArc.map { String(format: "%.4f", $0) } ?? "") | \(d.keyRateDegPerYear.map { String(format: "%.6f", $0) } ?? "") |"
            )
        }
        if let a = result.calculationAssumptions, !a.isEmpty {
            lines += ["", "## 计算假设", ""] + a.map { "- \($0)" }
        }
        lines += ["", "> Simplified PD multi-profile proxy; see B16 audit limits."]
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
        var rows = ["row_type,profile_or_bounds,id,direction_type,arc_signed,age_from_abs_arc,method_key"]
        for d in result.distributions {
            rows.append(
                "distribution,\(expansionCSVEscape(d.boundsSystem ?? "")),\(expansionCSVEscape(d.significator ?? "")),,,,\(expansionCSVEscape(d.methodKey ?? ""))"
            )
        }
        for d in result.primaryDirectionsByProfile {
            rows.append(
                "pd_profile,\(expansionCSVEscape(d.methodProfile ?? "")),\(expansionCSVEscape(d.directionId)),\(expansionCSVEscape(d.directionType ?? "")),\(d.arcSigned.map { String($0) } ?? ""),\(d.ageFromAbsArc.map { String($0) } ?? ""),\(expansionCSVEscape(d.methodKey ?? ""))"
            )
        }
        return rows.joined(separator: "\n")
    }
}
