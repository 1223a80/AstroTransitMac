import Foundation

extension MarkdownExportBuilder {
    /// Lossless Markdown formatter for Horary Data Packet v2.
    /// Does not invent conclusions, scores, or significator judgments.
    static func horary(_ result: HoraryDataPacket) -> String {
        let schemaBag = stringifyJSON(result.rawValue("schema"))
        let provenanceBag = stringifyJSON(result.provenance.raw)
        let timeBag = stringifyJSON(result.timeAndLocation.raw)
        let configBag = stringifyJSON(result.calculationConfig.raw)
        var lines: [String] = [
            "# Horary Data Packet \(result.schema.schemaId)",
            "",
            "## 1. Schema & Provenance (full evidence)",
            "",
            "- schema: \(schemaBag)",
            "- provenance: \(provenanceBag)",
            "",
            "## 2. Question Metadata",
            "",
            "- question_text: \(result.questionMetadata.questionText.isEmpty ? "(empty)" : result.questionMetadata.questionText)",
            "- place_name: \(result.questionMetadata.placeName.isEmpty ? "(empty)" : result.questionMetadata.placeName)",
            "- full: \(stringifyJSON(result.rawValue("question_metadata")))",
            "",
            "## 3. Time & Location (full evidence)",
            "",
            "- \(timeBag)",
            "",
            "## 4. Calculation Config (full evidence)",
            "",
            "- \(configBag)",
            "",
            "## 5. Angles",
            ""
        ]
        for p in result.angles.points {
            lines.append("- \(p.id): \(p.longitudeDeg) (\(p.sign.displayEn))")
        }
        lines += [
            "- ARMC: \(result.angles.armc.longitudeDeg.map { String($0) } ?? "null")",
            "- full: \(stringifyJSON(result.rawValue("angles")))",
            "",
            "## 6. Houses",
            ""
        ]
        for h in result.houses.cusps {
            lines.append(
                "- H\(h.house): cusp \(h.cuspLongitudeDeg) (\(h.sign.displayEn)), span \(h.spanDeg.map { String($0) } ?? "-")°, ruler \(h.domicileRulerId)"
            )
        }
        lines.append("- full: \(stringifyJSON(result.rawValue("houses")))")
        lines += ["", "## 7. Bodies (full evidence)", ""]
        for b in result.bodies {
            lines.append("- \(stringifyJSON(b.raw))")
        }
        lines += ["", "## 8. Dignities (full evidence)", ""]
        for d in result.dignities {
            lines.append("- \(stringifyJSON(d.raw))")
        }
        lines += ["", "## 9. Pairwise Geometry (full evidence)", ""]
        for p in result.pairwiseGeometry {
            lines.append("- \(stringifyJSON(p.raw))")
        }
        let displayOrb = result.displayOrbDeg ?? result.calculationConfig.aspectOrbDeg
        lines += ["", "## 10. Aspect Candidates (full; display_orb=\(displayOrb)°)", ""]
        let candidates = result.aspectCandidates ?? result.aspects
        if candidates.isEmpty {
            lines.append("- none")
        } else {
            // Full evidence dump for AI — no curated field loss
            for a in candidates {
                lines.append("- \(stringifyJSON(a.raw))")
            }
        }
        lines += ["", "### Aspects within display orb", ""]
        let inOrb = result.aspectsInDisplayOrb ?? result.aspects.filter { $0.withinDisplayOrb == true || $0.withinOrb == true }
        if inOrb.isEmpty {
            lines.append("- none")
        } else {
            for a in inOrb {
                lines.append("- \(a.id)")
            }
        }
        lines += ["", "## 11. Receptions (full evidence)", ""]
        if result.receptions.isEmpty {
            lines.append("- none")
        } else {
            // AI path: dump entire reception object — no curated field loss.
            for r in result.receptions {
                lines.append("- \(stringifyJSON(r.raw))")
            }
        }
        lines += ["", "## 12. Lots (full evidence)", ""]
        for lot in result.lots {
            lines.append("- \(stringifyJSON(lot.raw))")
        }
        lines += ["", "## 13. Events (full evidence)", ""]
        if result.events.isEmpty {
            lines.append("- none")
        } else {
            for ev in result.events {
                lines.append("- \(stringifyJSON(ev.raw))")
            }
        }
        lines += ["", "## 14. Moon Index (full evidence)", ""]
        lines.append("- \(stringifyJSON(result.moon))")
        lines += ["", "## 15. Visibility / Solar Geometry / Pheno (full evidence)", ""]
        for v in result.visibility {
            lines.append("- \(stringifyJSON(v.raw))")
        }
        lines += ["", "## 16. Nodes", ""]
        lines.append("- \(stringifyJSON(result.nodes))")
        lines += ["", "## 17. Event Graph", ""]
        lines.append("- \(stringifyJSON(result.eventGraph))")
        lines += ["", "## 18. Planetary Day / Hour", ""]
        lines.append("- \(stringifyJSON(result.planetaryDayHour))")
        lines += ["", "## 19. Considerations Evidence", ""]
        if let cons = result.considerationsEvidence {
            lines.append("- \(stringifyJSON(.array(cons)))")
        } else {
            lines.append("- null")
        }
        lines += ["", "## 20-23. Optional Modules (full evidence)", ""]
        lines.append("- \(stringifyJSON(result.optionalModules))")
        lines += ["", "## 24. Validation (full evidence)", ""]
        lines += [
            "- forbidden_field_scan: \(result.validation.forbiddenFieldScan ?? "unknown")",
            "- body_count: \(result.validation.bodyCount.map { String($0) } ?? "-")",
            "- aspect_count: \(result.validation.aspectCount.map { String($0) } ?? "-")",
            "- event_count: \(result.validation.eventCount.map { String($0) } ?? "-")",
            "- lot_count: \(result.validation.lotCount.map { String($0) } ?? "-")",
            "- house_fallback_applied: \(result.validation.houseFallbackApplied.map { String($0) } ?? "-")",
            "- full: \(stringifyJSON(result.rawValue("validation")))",
        ]
        if !result.validation.warnings.isEmpty {
            lines += ["", "### Technical Warnings", ""]
            lines += result.validation.warnings.map { "- \($0)" }
        }
        lines += [
            "",
            "## 25. Display Metadata (full evidence)",
            "",
            "- \(stringifyJSON(result.rawValue("display")))",
        ]
        return lines.joined(separator: "\n")
    }

    private static func stringifyJSON(_ value: HoraryV2JSONValue?) -> String {
        guard let value else { return "null" }
        // Full AI Markdown must not drop evidence blocks (event_graph, antiscia, declination).
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let s = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return s
    }

}
