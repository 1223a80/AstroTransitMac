import Foundation

extension MarkdownExportBuilder {
    static func horary(_ result: HoraryResult) -> String {
        var lines: [String] = [
            "# Horary Data Packet",
            "",
            "## 1. Question & Metadata",
            "",
            "- Question: \(result.questionText.isEmpty ? "unknown" : result.questionText)",
            "- Asked: \(result.meta.askedLocal)",
            "- UTC: \(result.meta.askedUTC)",
            "- Place: \(result.meta.placeName) (\(String(format: "%.4f", result.meta.latitude)), \(String(format: "%.4f", result.meta.longitude)))",
            "- Chart: \(result.meta.houseSystem) / \(result.meta.sect)",
            "- Sun position: \(result.meta.sunHorizonStatus) / \(result.planets.first(where: { $0.id == "SUN" })?.degreeText ?? "") / H\(result.planets.first(where: { $0.id == "SUN" })?.house ?? 0)",
            ""
        ]

        lines += [
            "## 2. Machine Summary",
            ""
        ]
        lines += result.machineSummary.map { "- \($0)" }
        lines += [
            "",
            "## 3. Radicality Flags",
            ""
        ]
        lines += result.radicalityFlags.isEmpty ? ["- none"] : result.radicalityFlags.map { "- \($0.label) (\($0.severity))" }
        lines += [
            "",
            "## 4. Angles",
            ""
        ]
        lines += result.angles.map { "- \($0.name): \($0.degreeText)" }
        lines += [
            "",
            "## 5. House Rulers",
            ""
        ]
        lines += ["- " + result.houseRulers.map { "\($0.house): \($0.ruler)" }.joined(separator: ", ")]
        lines += [
            "",
            "## 6. Planet Conditions",
            ""
        ]
        lines += result.planets.map {
            "- \($0.name): \($0.degreeText), H\($0.house), \($0.motion), \($0.sectStatus), \($0.solarPhase), score \($0.score)"
        }
        lines += [
            "",
            "## 7. Planetary Speeds",
            ""
        ]
        lines += result.planetarySpeeds.map {
            "- \($0.planet): \(String(format: "%.4f", $0.speed))°/day, \($0.speedState)\($0.station ? ", station" : "")"
        }
        lines += [
            "",
            "## 8. Solar Condition",
            ""
        ]
        lines += result.solarCondition.map {
            "- \($0.planet): \($0.condition), \(degree($0.distanceFromSun, digits: 2)) from Sun"
        }
        lines += [
            "",
            "## 9. Significator Candidates",
            ""
        ]
        lines += result.significatorCandidates.map {
            let position = $0.position.isEmpty ? "-" : $0.position
            let house = $0.house > 0 ? "H\($0.house)" : "-"
            let condition = $0.condition.isEmpty ? "-" : $0.condition
            return "- \($0.role): \($0.planet) [\($0.source)] \(position) \(house) \(condition)"
        }
        lines += [
            "",
            "## 10. Moon Storyline",
            "",
            "- Moon current: \(result.moonStoryline.currentPosition) / H\(result.moonStoryline.currentHouse)",
            "- Moon VOC: \(result.moonStoryline.voc ? "yes" : "no")",
            "- Criterion: \(result.moonVocCriterion)",
            "- Moon next sign ingress: \(result.moonStoryline.nextSign) @ \(result.moonStoryline.nextSignIngressTime)"
        ]
        if let last = result.moonStoryline.lastAspect {
            lines.append("- Moon last exact aspect: \(last.aspectName) \(last.targetName) @ \(result.moonStoryline.lastAspectTime)")
        } else {
            lines.append("- Moon last exact aspect: unknown")
        }
        if let next = result.moonStoryline.nextAspect {
            lines.append("- Moon next exact aspect before sign exit: \(next.aspectName) \(next.targetName) @ \(result.moonStoryline.nextAspectTime)")
        } else {
            lines.append("- Moon next exact aspect before sign exit: none")
        }
        if let firstAfterIngress = result.moonStoryline.firstAfterIngress {
            lines.append("- First aspect after next sign ingress: \(firstAfterIngress.aspectName) \(firstAfterIngress.targetName) @ \(result.moonStoryline.firstAfterIngressTime)")
        } else {
            lines.append("- First aspect after next sign ingress: none")
        }
        if !result.moonStoryline.beforeSignExitAspects.isEmpty {
            lines += ["", "### Moon Before Sign Exit Aspects", ""]
            lines += result.moonStoryline.beforeSignExitAspects.map {
                "- \($0.aspectName) \($0.targetName) @ \($0.exactLocal)"
            }
        }
        lines += [
            "",
            "## 11. Key Significator Links",
            "",
        ]
        lines += result.keySignificatorLinks.isEmpty ? ["- none detected"] : result.keySignificatorLinks.map {
            "- \($0.pair): \($0.aspect.isEmpty ? "none" : $0.aspect) / \($0.type.isEmpty ? "-" : $0.type) / \($0.applying.isEmpty ? "-" : $0.applying) / perfects before sign exit: \($0.perfectsBeforeSignExit ? "yes" : "no") / next perfection: \($0.nextPerfection.isEmpty ? "none" : $0.nextPerfection) / reason: \($0.perfectionReason)\($0.reception.isEmpty ? "" : " / reception: \($0.reception)")"
        }
        lines += [
            "",
            "## 12. Degree-Based Key Aspects",
            "",
        ]
        lines += result.degreeBasedKeyAspects.isEmpty
            ? ["- none detected among selected significators"]
            : result.degreeBasedKeyAspects.map {
                "- \($0.bodyA) \($0.aspect) \($0.bodyB) / orb \($0.orb.map { degree($0, digits: 2) } ?? "-") / \($0.applying.isEmpty ? "-" : $0.applying) / exact time: \($0.exactTime.isEmpty ? "past / not computed" : $0.exactTime) / scope: selected significators"
            }
        lines += [
            "",
            "## 13. Key Receptions",
            "",
        ]
        let keyReceptions = result.receptions.filter { ($0.strengthLabel ?? "") != "弱" && $0.dignity != "decan" }
        lines += keyReceptions.isEmpty ? ["- none detected"] : keyReceptions.map {
            "- \($0.receiver) receives \($0.received) via \($0.viaAspect) (\($0.strengthLabel ?? ""))"
        }
        lines += [
            "",
            "## 14. Negative Receptions",
            "",
        ]
        lines += result.negativeReceptions.isEmpty ? ["- none detected"] : result.negativeReceptions.map {
            "- \($0.receiver) -> \($0.received) / \($0.debility) / \($0.viaAspect) / \($0.strength)"
        }
        lines += [
            "",
            "## 15. Lots Summary",
            "",
        ]
        lines += result.lotsSummary.map {
            "- \($0.lot): \($0.position) / H\($0.house) / \($0.ruler) / \($0.rulerCondition)\($0.keyNotes.isEmpty ? "" : " / \($0.keyNotes)")"
        }
        lines += [
            "",
            "## 16. Advanced Candidates",
            "",
        ]
        lines += result.advancedCandidates.map {
            "- \($0.type) [\($0.status)]: \($0.details)"
        }
        lines += [
            "",
            "## 17. Scoring Note",
            ""
        ]
        lines += ["- score / bonification / maltreatment are internal heuristic fields."]
        lines += warnings(result.warnings)
        return lines.joined(separator: "\n")
    }
}
