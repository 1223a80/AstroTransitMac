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
            "| UTC | Moon° | Speed | Exit dist | Sun-Moon sep | ASC | Nearest aspects | PH status | Method |",
            "| --- | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |",
        ]
        for c in result.electionalCandidates {
            let aspects = (c.nearestMoonAspects ?? []).map { row in
                "\(row.bodyId ?? "?"):\(row.separationDeg.map { String(format: "%.2f", $0) } ?? "?")"
            }.joined(separator: "; ")
            lines.append(
                "| \(c.candidateUtc ?? "") | \(c.moonLongitude.map { String(format: "%.3f", $0) } ?? "") | \(c.moonSpeed.map { String(format: "%.4f", $0) } ?? "") | \(c.moonSignExitDistance.map { String(format: "%.3f", $0) } ?? "") | \(c.sunMoonSeparation.map { String(format: "%.3f", $0) } ?? "") | \(c.ascLongitude.map { String(format: "%.3f", $0) } ?? "") | \(aspects) | \(c.planetaryHoursStatus ?? "") | \(c.methodKey ?? "") |"
            )
        }
        if let a = result.calculationAssumptions, !a.isEmpty {
            lines += ["", "## 计算假设", ""] + a.map { "- \($0)" }
        }
        lines += ["", "> Facts only — no ranking scores."]
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
        var rows = [
            "row_type,name,exact_utc,moon_longitude,moon_sign_exit_distance,sun_moon_separation,asc_longitude,nearest_moon_aspects,planetary_hours_status,method_key"
        ]
        for i in result.mundaneIngresses {
            rows.append(
                "ingress,\(expansionCSVEscape(i.ingress ?? "")),\(expansionCSVEscape(i.exactUtc ?? "")),,,,,,,\(expansionCSVEscape(i.methodKey ?? ""))"
            )
        }
        for c in result.electionalCandidates {
            let aspects = (c.nearestMoonAspects ?? []).map { row in
                "\(row.bodyId ?? ""):\(row.separationDeg.map { String($0) } ?? "")"
            }.joined(separator: ";")
            rows.append(
                [
                    "candidate",
                    "",
                    expansionCSVEscape(c.candidateUtc ?? ""),
                    c.moonLongitude.map { String($0) } ?? "",
                    c.moonSignExitDistance.map { String($0) } ?? "",
                    c.sunMoonSeparation.map { String($0) } ?? "",
                    c.ascLongitude.map { String($0) } ?? "",
                    expansionCSVEscape(aspects),
                    expansionCSVEscape(c.planetaryHoursStatus ?? ""),
                    expansionCSVEscape(c.methodKey ?? ""),
                ].joined(separator: ",")
            )
        }
        return rows.joined(separator: "\n")
    }
}
