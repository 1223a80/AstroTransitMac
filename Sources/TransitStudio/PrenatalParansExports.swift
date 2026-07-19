import Foundation

extension MarkdownExportBuilder {
    static func prenatalParans(_ result: PrenatalParansResult) -> String {
        var lines = [
            "# prenatal_parans",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Mode: \(result.meta.mode ?? "prenatal_parans")",
            "- Paran count: \(result.meta.paranCount ?? result.fixedStarParans.count)",
            "",
            "## Fixed-star parans (RA co-culmination proxy)",
            "",
            "| Planet | Star | Planet RA | Star RA | ΔRA | Class | Method |",
            "| --- | --- | ---: | ---: | ---: | --- | --- |",
        ]
        for p in result.fixedStarParans.prefix(80) {
            lines.append(
                "| \(p.planetName ?? p.planetId ?? "") | \(p.starName ?? "") | \(p.planetRa.map { String(format: "%.4f", $0) } ?? "") | \(p.starRa.map { String(format: "%.4f", $0) } ?? "") | \(p.raDeltaDeg.map { String(format: "%.4f", $0) } ?? "") | \(p.paranClass ?? "") | \(p.methodKey ?? "") |"
            )
        }
        if let packet = result.prenatalPacket {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? enc.encode(packet), let s = String(data: data, encoding: .utf8) {
                lines += ["", "## Prenatal packet", "", "```json", String(s.prefix(6000)), "```"]
            }
        }
        if let a = result.calculationAssumptions, !a.isEmpty {
            lines += ["", "## 计算假设", ""] + a.map { "- \($0)" }
        }
        if result.warnings.isEmpty {
            lines += ["", "## 警告", "", "无。"]
        } else {
            lines += ["", "## 警告", ""] + result.warnings.map { "- \($0)" }
        }
        lines += ["", "> Parans are RA co-culmination proxies, not full rise/set parans."]
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func prenatalParansJSON(_ result: PrenatalParansResult) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(result), let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    static func csv(_ result: PrenatalParansResult) -> String {
        var rows = ["row_type,planet_id,star_name,planet_ra,star_ra,ra_delta_deg,paran_class,method_key"]
        for p in result.fixedStarParans {
            rows.append(
                "paran,\(expansionCSVEscape(p.planetId ?? "")),\(expansionCSVEscape(p.starName ?? "")),\(p.planetRa.map { String($0) } ?? ""),\(p.starRa.map { String($0) } ?? ""),\(p.raDeltaDeg.map { String($0) } ?? ""),\(expansionCSVEscape(p.paranClass ?? "")),\(expansionCSVEscape(p.methodKey ?? ""))"
            )
        }
        return rows.joined(separator: "\n")
    }
}
