import Foundation

extension MarkdownExportBuilder {
    static func mundaneElectional(_ result: MundaneElectionalResult) -> String {
        var lines = [
            "# mundane_electional",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Display TZ: \(result.meta.displayTimezone ?? "—")",
            "- Ingresses: \(result.mundaneIngresses.count)",
            "- Candidates: \(result.electionalCandidates.count)",
            "",
            "## Mundane ingresses",
            "",
            "| Ingress | Exact UTC | Exact local | Orb | House system | Method |",
            "| --- | --- | --- | ---: | --- | --- |",
        ]
        for i in result.mundaneIngresses {
            lines.append(
                "| \(i.ingress ?? "") | \(i.exactUtc ?? "") | \(i.exactLocal ?? "") | \(i.exactOrb.map { String(format: "%.6f", $0) } ?? "") | \(i.houseSystem ?? "") | \(i.methodKey ?? "") |"
            )
        }
        lines += [
            "",
            "## Electional candidates (facts only)",
            "",
            "| UTC | Moon° | Speed | Sun-Moon sep | ASC | PH status | Method |",
            "| --- | ---: | ---: | ---: | ---: | --- | --- |",
        ]
        for c in result.electionalCandidates.prefix(60) {
            lines.append(
                "| \(c.candidateUtc ?? "") | \(c.moonLongitude.map { String(format: "%.3f", $0) } ?? "") | \(c.moonSpeed.map { String(format: "%.4f", $0) } ?? "") | \(c.sunMoonSeparation.map { String(format: "%.3f", $0) } ?? "") | \(c.ascLongitude.map { String(format: "%.3f", $0) } ?? "") | \(c.planetaryHoursStatus ?? "") | \(c.methodKey ?? "") |"
            )
        }
        if let a = result.calculationAssumptions, !a.isEmpty {
            lines += ["", "## 计算假设", ""] + a.map { "- \($0)" }
        }
        lines += ["", "> Facts only — no lucky_score / rank."]
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func mundaneElectionalJSON(_ result: MundaneElectionalResult) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(result), let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    static func csv(_ result: MundaneElectionalResult) -> String {
        var rows = ["row_type,name,exact_utc,moon_longitude,asc_longitude,method_key"]
        for i in result.mundaneIngresses {
            rows.append(
                "ingress,\(expansionCSVEscape(i.ingress ?? "")),\(expansionCSVEscape(i.exactUtc ?? "")),,,\(expansionCSVEscape(i.methodKey ?? ""))"
            )
        }
        for c in result.electionalCandidates {
            rows.append(
                "candidate,,\(expansionCSVEscape(c.candidateUtc ?? "")),\(c.moonLongitude.map { String($0) } ?? ""),\(c.ascLongitude.map { String($0) } ?? ""),\(expansionCSVEscape(c.methodKey ?? ""))"
            )
        }
        return rows.joined(separator: "\n")
    }
}
