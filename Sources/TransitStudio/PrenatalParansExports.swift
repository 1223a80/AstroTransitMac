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
            "- Schema: \(result.meta.schemaVersion ?? 0)",
            "- True event-pair count: \(result.meta.paranCount ?? result.fixedStarParans.count)",
            "- Legacy RA-proxy count: \(result.meta.legacyParanCount ?? result.legacyFixedStarParans.count)",
            "- Provider/function: \(result.methodTrace?.provider ?? "Swiss Ephemeris") / `\(result.methodTrace?.function ?? "swe.rise_trans")`",
            "- Pairing rule: \(result.methodTrace?.pairingRule ?? "absolute event time delta within event_orb_seconds")",
        ]
        if let start = result.methodTrace?.localDayStart, let end = result.methodTrace?.localDayEnd {
            lines.append("- Local civil day: \(start) → \(end)")
        }
        if let start = result.methodTrace?.utcDayStart, let end = result.methodTrace?.utcDayEnd {
            lines.append("- UTC search window: \(start) → \(end)")
        }
        if let polar = result.polarDegradation {
            lines.append(
                "- Polar degradation: \(polar.active ? "active" : "inactive")"
                    + " (affected objects: \(polar.affectedObjectCount ?? 0); strategy: \(polar.strategy ?? "—"))"
            )
        }

        lines += [
            "",
            "## Fixed-star parans (true local events)",
            "",
            "| Planet | Planet event | Planet UTC | Planet local | Star | Star event | Star UTC | Star local | Δt seconds | Method |",
            "| --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- |",
        ]
        for row in result.fixedStarParans {
            lines.append(
                "| \(row.planetName ?? row.planetId ?? "")"
                    + " | \(row.planetEventType ?? "")"
                    + " | \(row.planetEventUtc ?? "")"
                    + " | \(row.planetEventLocal ?? "")"
                    + " | \(row.starName ?? "")"
                    + " | \(row.starEventType ?? "")"
                    + " | \(row.starEventUtc ?? "")"
                    + " | \(row.starEventLocal ?? "")"
                    + " | \(row.eventDeltaSeconds.map { String(format: "%.3f", $0) } ?? "")"
                    + " | \(row.methodKey ?? "") |"
            )
        }

        lines += [
            "",
            "## Legacy compatibility (RA co-culmination proxy)",
            "",
            "> Migration only. These rows are not true local rise/set/meridian paran pairs.",
            "",
            "| Planet | Star | Planet RA | Star RA | ΔRA | Class | Legacy method |",
            "| --- | --- | ---: | ---: | ---: | --- | --- |",
        ]
        for row in result.legacyFixedStarParans {
            lines.append(
                "| \(row.planetName ?? row.planetId ?? "")"
                    + " | \(row.starName ?? "")"
                    + " | \(row.planetRa.map { String(format: "%.4f", $0) } ?? "")"
                    + " | \(row.starRa.map { String(format: "%.4f", $0) } ?? "")"
                    + " | \(row.raDeltaDeg.map { String(format: "%.4f", $0) } ?? "")"
                    + " | \(row.paranClass ?? "")"
                    + " | \(row.methodKeyLegacy ?? row.methodKey ?? "") |"
            )
        }
        if let packet = result.prenatalPacket {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(packet), let value = String(data: data, encoding: .utf8) {
                lines += ["", "## Prenatal packet", "", "```json", value, "```"]
            }
        }
        if let assumptions = result.calculationAssumptions, !assumptions.isEmpty {
            lines += ["", "## 计算假设", ""] + assumptions.map { "- \($0)" }
        }
        if result.warnings.isEmpty {
            lines += ["", "## 警告", "", "无。"]
        } else {
            lines += ["", "## 警告", ""] + result.warnings.map { "- \($0)" }
        }
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func prenatalParansJSON(_ result: PrenatalParansResult) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard
            let data = try? encoder.encode(result),
            let value = String(data: data, encoding: .utf8)
        else { return "{}" }
        return value
    }

    static func csv(_ result: PrenatalParansResult) -> String {
        var rows = [
            "row_type,planet_id,planet_name,planet_event_type,planet_event_utc,planet_event_local,star_id,star_name,star_event_type,star_event_utc,star_event_local,event_delta_seconds,event_orb_seconds,planet_ra,star_ra,ra_delta_deg,paran_class,method_key,method_key_legacy,proxy,full_paran"
        ]
        for row in result.fixedStarParans {
            rows.append(csvRow("event_paran", row))
        }
        for row in result.legacyFixedStarParans {
            rows.append(csvRow("legacy_ra_proxy", row))
        }
        return rows.joined(separator: "\n")
    }

    private static func csvRow(_ rowType: String, _ row: FixedStarParanRow) -> String {
        var fields: [String] = []
        fields.append(rowType)
        fields.append(row.planetId ?? "")
        fields.append(row.planetName ?? "")
        fields.append(row.planetEventType ?? "")
        fields.append(row.planetEventUtc ?? "")
        fields.append(row.planetEventLocal ?? "")
        fields.append(row.starId ?? "")
        fields.append(row.starName ?? "")
        fields.append(row.starEventType ?? "")
        fields.append(row.starEventUtc ?? "")
        fields.append(row.starEventLocal ?? "")
        fields.append(row.eventDeltaSeconds.map { String($0) } ?? "")
        fields.append(row.eventOrbSeconds.map { String($0) } ?? "")
        fields.append(row.planetRa.map { String($0) } ?? "")
        fields.append(row.starRa.map { String($0) } ?? "")
        fields.append(row.raDeltaDeg.map { String($0) } ?? "")
        fields.append(row.paranClass ?? "")
        fields.append(row.methodKey ?? "")
        fields.append(row.methodKeyLegacy ?? "")
        fields.append(row.proxy.map { String($0) } ?? "")
        fields.append(row.fullParan.map { String($0) } ?? "")
        return fields
            .map(expansionCSVEscape)
            .joined(separator: ",")
    }
}
