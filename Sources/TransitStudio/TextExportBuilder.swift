import Foundation

enum TextExportBuilder {
    static func json<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func natalJSON(_ result: TransitResult) -> String {
        let payload = NatalChartExport(
            meta: NatalChartExport.Meta(
                birthUTC: result.meta.natalUTC,
                ephemeris: result.meta.ephemeris
            ),
            positions: result.natalPositions,
            aspects: natalAspects(from: result),
            warnings: result.warnings
        )
        return json(payload)
    }

    static func natalCSV(_ result: TransitResult) -> String {
        var rows: [[String]] = [
            ["section", "name", "longitude", "degree_text", "latitude", "speed", "aspect", "other", "separation", "orb"]
        ]

        rows += result.natalPositions.map {
            ["natal_position", $0.name, number($0.longitude), $0.degreeText, number($0.latitude), number($0.speed), $0.house.map(String.init) ?? "", "", "", ""]
        }
        rows += natalAspects(from: result).map {
            ["natal_aspect", $0.transitBodyName, "", "", "", "", $0.aspectName, $0.natalBodyName, number($0.separation), number($0.orb)]
        }

        return csv(rows)
    }

    static func csv(_ result: TransitResult) -> String {
        var rows: [[String]] = [
            ["section", "name", "longitude", "degree_text", "latitude", "speed", "aspect", "other", "separation", "orb"]
        ]

        rows += result.natalPositions.map {
            ["natal_position", $0.name, number($0.longitude), $0.degreeText, number($0.latitude), number($0.speed), $0.house.map(String.init) ?? "", "", "", ""]
        }
        rows += result.transitPositions.map {
            ["transit_position", $0.name, number($0.longitude), $0.degreeText, number($0.latitude), number($0.speed), $0.house.map(String.init) ?? "", "", "", ""]
        }
        rows += result.aspects.map {
            ["aspect", $0.transitBodyName, "", "", "", "", $0.aspectName, $0.natalBodyName, number($0.separation), number($0.orb)]
        }

        return csv(rows)
    }

    static func csv(_ result: ScanResult) -> String {
        let rows: [[String]] = [
            ["priority_grade", "window", "date_time_local", "transit_body", "aspect", "aspect_angle", "target", "target_position", "exact_transit_position", "orb", "phase", "scan_step", "exact_method"]
        ] + result.hits.map {
            [
                $0.priorityGrade ?? "",
                $0.window,
                $0.dateTimeLocal,
                $0.transitBodyName,
                $0.aspectName,
                $0.aspectAngle.map(number) ?? "",
                $0.targetName,
                $0.targetPosition ?? "",
                $0.exactTransitPosition ?? $0.transitPosition,
                $0.orb.map(number) ?? "",
                $0.phase ?? "",
                $0.scanStep ?? "",
                $0.exactMethod ?? ""
            ]
        }
        return csv(rows)
    }

    private static let sectionErrorLabels: [String: String] = [
        "primary_directions": "主限法",
        "circumambulations": "沿界推进",
        "prenatal_syzygy": "产前朔望",
        "almuten_figuris": "Almuten Figuris",
        "hyleg_alcocoden": "Hyleg/Alcocoden",
    ]

    static func csv(_ result: ClassicalResult) -> String {
        var rows: [[String]] = [
            ["section", "name", "position", "longitude", "house", "ruler_or_aspect", "extra_1", "extra_2", "extra_3"]
        ]

        rows += result.angles.map {
            ["angle", $0.name, $0.degreeText, number($0.longitude), "\($0.house)", $0.ruler, "", "", ""]
        }
        rows += result.houses.map {
            ["house", "\($0.house)", $0.cuspText, number($0.cuspLongitude), "\($0.house)", $0.ruler, $0.sign, "", ""]
        }
        rows += result.planets.map {
            ["planet", $0.name, $0.degreeText, number($0.longitude), "\($0.house)", $0.motion, $0.sectStatus, [$0.domicile, $0.exaltation, $0.triplicity].filter { !$0.isEmpty }.joined(separator: " "), ($0.notes ?? []).joined(separator: "、")]
        }
        rows += result.lots.map {
            ["lot", $0.name, $0.degreeText, number($0.longitude), "\($0.house)", $0.ruler, $0.formula ?? "", "", ""]
        }
        rows += result.aspects.map {
            ["aspect", $0.bodyA, "", "", "", $0.aspect, $0.bodyB, $0.orb.map(number) ?? "", $0.applying ?? ""]
        }
        rows += result.receptions.map {
            ["reception", $0.receiver, "", "", "", $0.received, $0.dignity, $0.viaAspect, $0.strengthLabel ?? ""]
        }
        if let antiscia = result.antiscia {
            for row in antiscia {
                let hits = row.natalHits.isEmpty ? "" : row.natalHits.map { "\($0.via):\($0.hitPlanet)(\(String(format: "%.1f", $0.orb)))" }.joined(separator: ";")
                rows.append(["antiscia", row.planet, row.antisciaDegree, row.contraDegree, "", hits, "", "", ""])
            }
        }
        if let pd = result.primaryDirections {
            for d in pd {
                let tag = d.directionType == "converse" ? "converse" : "direct"
                rows.append(["primary_direction", d.promissor, d.significator, d.aspectName, String(format: "%+.2f", d.arcSigned ?? 0), String(format: "%.1f", d.ageFromAbsArc), d.eventDateAfterBirth ?? "", tag, d.symbolicDateFromSignedArc ?? ""])
            }
        }
        if let circ = result.circumambulations {
            for c in circ {
                rows.append(["circumambulation_system", c.system, String(format: "%.4f", c.startLon), "Naibod \(String(format: "%.4f", c.naibodRate))", c.currentRuler, c.currentBoundInfo ?? "", "", "", ""])
                for b in c.boundaries {
                    rows.append(["circumambulation_boundary", b.sign, "\(b.endDegree)°", b.ruler, String(format: "%.2f", b.arcValue), String(format: "%.1f", b.ageAtBoundary), b.estimatedDate, "", ""])
                }
            }
        }
        rows.append([
            "timing_profection",
            "\(result.timing.profection.age)岁",
            result.timing.profection.sign,
            "",
            "\(result.timing.profection.house)",
            result.timing.profection.lord,
            result.timing.profection.startLocal,
            result.timing.profection.endLocal,
            result.timing.profection.activatedPlanets.joined(separator: "、")
        ])
        if let previousSR = result.planetaryReturns.first(where: { $0.bodyID == "SUN" })?.previousReturn {
            rows.append([
                "timing_solar_return_previous",
                "Previous Solar Return",
                previousSR.exactLocal,
                previousSR.exactUTC,
                "",
                previousSR.sect,
                previousSR.ascendant,
                previousSR.midheaven,
            ])
        }
        if let currentSR = result.planetaryReturns.first(where: { $0.bodyID == "SUN" })?.currentCycleReturn {
            rows.append([
                "timing_solar_return_current",
                "Current Solar Return",
                currentSR.exactLocal,
                currentSR.exactUTC,
                "",
                currentSR.sect,
                currentSR.ascendant,
                currentSR.midheaven,
            ])
        }
        if let nextSR = result.planetaryReturns.first(where: { $0.bodyID == "SUN" })?.nextReturn {
            rows.append([
                "timing_solar_return",
                "Next Solar Return",
                nextSR.exactLocal,
                nextSR.exactUTC,
                "",
                nextSR.sect,
                nextSR.ascendant,
                nextSR.midheaven,
                nextSR.houseSystem,
            ])
            rows += nextSR.planets.map {
                ["solar_return_planet", $0.name, $0.degreeText, number($0.longitude), "\($0.house)", $0.motion, $0.sectStatus, "\($0.score)", ($0.notes ?? []).joined(separator: "、")]
            }
        }
        rows += result.planetaryReturns.filter { $0.bodyID != "SUN" }.flatMap { entry in
            var returnRows: [[String]] = []
            if let previous = entry.previousReturn {
                returnRows.append(["planetary_return_previous", "Previous \(entry.title)", previous.exactLocal, previous.exactUTC, "", previous.sect, previous.ascendant, previous.midheaven, previous.houseSystem])
            }
            if let current = entry.currentCycleReturn {
                returnRows.append(["planetary_return_current", "Current \(entry.title)", current.exactLocal, current.exactUTC, "", current.sect, current.ascendant, current.midheaven, current.houseSystem])
            }
            if let next = entry.nextReturn {
                returnRows.append(["planetary_return_next", "Next \(entry.title)", next.exactLocal, next.exactUTC, "", next.sect, next.ascendant, next.midheaven, next.houseSystem])
            }
            return returnRows
        }
        for planet in result.planets {
            rows += planet.scoreBreakdown.map { item in
                [
                    "score_breakdown",
                    planet.name,
                    item.value,
                    "",
                    "",
                    item.label,
                    "\(item.score)",
                    "",
                    ""
                ]
            }
            rows += planet.bonification.map { modifier in
                [
                    "bonification",
                    planet.name,
                    modifier.source,
                    "",
                    "",
                    modifier.aspect,
                    modifier.orb.map(number) ?? "",
                    modifier.applying ?? "",
                    modifier.strengthLabel
                ]
            }
            rows += planet.maltreatment.map { modifier in
                [
                    "maltreatment",
                    planet.name,
                    modifier.source,
                    "",
                    "",
                    modifier.aspect,
                    modifier.orb.map(number) ?? "",
                    modifier.applying ?? "",
                    modifier.strengthLabel
                ]
            }
        }

        if let errors = result.sectionErrors {
            for (key, message) in errors.sorted(by: { $0.key < $1.key }) {
                let label = Self.sectionErrorLabels[key] ?? key
                rows.append(["section_error", label, message, "", "", "", "", "", ""])
            }
        }

        return csv(rows)
    }

    static func csv(_ result: HoraryResult) -> String {
        var rows: [[String]] = [
            ["section", "name", "position", "longitude", "house", "ruler_or_aspect", "extra_1", "extra_2", "extra_3"]
        ]

        rows.append(["question", result.questionText, "", "", "", "", "", "", ""])
        rows.append(["sun_horizon_status", result.meta.sunHorizonStatus, "", "", "", "", "", "", ""])
        rows += result.houseRulers.map {
            ["house_ruler", "\($0.house)", $0.sign, "", "\($0.house)", $0.ruler, "", "", ""]
        }
        rows += result.machineSummary.map {
            ["machine_summary", $0, "", "", "", "", "", "", ""]
        }
        rows += result.radicalityFlags.map {
            ["radicality_flag", $0.label, "", "", "", "", $0.severity, "", ""]
        }
        rows.append(["moon_voc_criterion", result.moonVocCriterion, "", "", "", "", "", "", ""])
        rows += result.significatorCandidates.map {
            ["significator_candidate", $0.role, $0.position, "", "\($0.house)", $0.planet, $0.source, $0.condition, ""]
        }
        rows += result.keySignificatorLinks.map {
            ["key_significator_link", $0.pair, "", "", "", $0.aspect, $0.type, $0.nextPerfection.isEmpty ? "none" : $0.nextPerfection, "\($0.perfectsBeforeSignExit ? "yes" : "no"); \($0.perfectionReason); \($0.reception)"]
        }
        rows += result.degreeBasedKeyAspects.map {
            ["degree_key_aspect", $0.bodyA, "", "", "", $0.aspect, $0.bodyB, $0.orb.map(number) ?? "", $0.exactTime]
        }
        rows += result.planetarySpeeds.map {
            ["planetary_speed", $0.planet, "", "", "", $0.speedState, number($0.speed), $0.station ? "yes" : "no", ""]
        }
        rows += result.solarCondition.map {
            ["solar_condition", $0.planet, "", "", "", $0.condition, number($0.distanceFromSun), "", ""]
        }
        rows += result.negativeReceptions.map {
            ["negative_reception", $0.receiver, "", "", "", $0.received, $0.debility, $0.viaAspect, $0.strength]
        }
        rows += result.lotsSummary.map {
            ["lot_summary", $0.lot, $0.position, "", "\($0.house)", $0.ruler, $0.rulerCondition, $0.keyNotes, ""]
        }
        rows += result.advancedCandidates.map {
            ["advanced_candidate", $0.type, $0.status, "", "", $0.details, $0.planets.joined(separator: ";"), "", ""]
        }
        rows += result.moonStoryline.beforeSignExitAspects.map {
            ["moon_before_sign_exit", $0.targetName, $0.exactLocal, number($0.targetLongitude), "\($0.targetHouse)", $0.aspectName, number($0.moonLongitude), "\($0.moonHouse)", ""]
        }
        rows += result.angles.map {
            ["angle", $0.name, $0.degreeText, number($0.longitude), "\($0.house)", $0.ruler, "", "", ""]
        }
        rows += result.houses.map {
            ["house", "\($0.house)", $0.cuspText, number($0.cuspLongitude), "\($0.house)", $0.ruler, $0.sign, "", ""]
        }
        rows += result.planets.map {
            ["planet", $0.name, $0.degreeText, number($0.longitude), "\($0.house)", $0.motion, $0.sectStatus, [$0.domicile, $0.exaltation, $0.triplicity].filter { !$0.isEmpty }.joined(separator: " "), ($0.notes ?? []).joined(separator: "、")]
        }
        rows += result.lots.map {
            ["lot", $0.name, $0.degreeText, number($0.longitude), "\($0.house)", $0.ruler, $0.formula ?? "", "", ""]
        }
        rows += result.aspects.map {
            ["aspect", $0.bodyA, "", "", "", $0.aspect, $0.bodyB, $0.orb.map(number) ?? "", $0.applying ?? ""]
        }
        rows += result.receptions.map {
            ["reception", $0.receiver, "", "", "", $0.received, $0.dignity, $0.viaAspect, $0.strengthLabel ?? ""]
        }

        return csv(rows)
    }

    private static func csv(_ rows: [[String]]) -> String {
        rows.map { row in
            row.map(escape).joined(separator: ",")
        }.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.8f", value)
    }

    static func csv(_ result: VedicResult) -> String {
        var rows: [[String]] = [["Planet", "Longitude", "Sign", "Degree", "House", "Nakshatra", "Pada"]]
        let chartPlanets = result.rasiChart?.planets ?? [:]
        if let planets = result.planets {
            for (pid, planet) in planets.sorted(by: { $0.value.longitude < $1.value.longitude }) {
                let nak = planet.nakshatra?.nakshatra
                let house = chartPlanets[pid]?.house ?? planet.house ?? 0
                rows.append([
                    pid,
                    number(planet.longitude),
                    planet.sign,
                    planet.degreeText,
                    "\(house)",
                    nak?.nameSa ?? "-",
                    nak.map { "\($0.pada)" } ?? "-"
                ])
            }
        }

        // Add Shadbala if present
        if let sb = result.shadbala {
            rows.append([])
            rows.append(["Shadbala", "Sthana", "Dig", "Kala", "Cheshta", "Naisargika", "Drig", "Total", "Percent"])
            for pid in ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"] {
                guard let row = sb[pid] else { continue }
                rows.append([
                    pid,
                    number(row.sthanaBala), number(row.digBala), number(row.kalaBala),
                    number(row.cheshtaBala), number(row.naisargikaBala), number(row.drigBala),
                    number(row.shadbalaTotal), "\(Int(row.percent))%"
                ])
            }
        }

        return csv(rows)
    }

    private static func natalAspects(from result: TransitResult) -> [AspectHit] {
        var seen = Set<String>()
        return result.aspects.filter { aspect in
            guard aspect.transitBodyID != aspect.natalBodyID else {
                return false
            }
            let pair = [aspect.transitBodyID, aspect.natalBodyID].sorted().joined(separator: "::")
            let key = "\(pair)::\(aspect.aspectID)"
            guard !seen.contains(key) else {
                return false
            }
            seen.insert(key)
            return true
        }
    }
}

private struct NatalChartExport: Codable {
    struct Meta: Codable {
        let birthUTC: String
        let ephemeris: String

        enum CodingKeys: String, CodingKey {
            case birthUTC = "birth_utc"
            case ephemeris
        }
    }

    let meta: Meta
    let positions: [PositionRow]
    let aspects: [AspectHit]
    let warnings: [String]
}
