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
                ephemeris: result.meta.ephemeris,
                effectivePointSet: result.meta.effectivePointSet
            ),
            positions: result.natalPositions,
            angles: result.angles ?? [],
            houses: result.houses ?? [],
            aspects: natalAspects(from: result),
            declinationAspects: result.declinationAspects ?? [],
            fixedStarConjunctions: result.natalStarConjunctions ?? [],
            patterns: result.patterns ?? [],
            chartProfile: result.chartProfile,
            warnings: result.warnings
        )
        return json(payload)
    }

    static func natalCSV(_ result: TransitResult) -> String {
        var rows: [[String]] = [
            ["section", "name", "longitude", "degree_text", "latitude", "speed", "aspect", "other", "separation", "orb"]
        ]

        rows += result.natalPositions.map {
            ["natal_position", $0.name, number($0.longitude), $0.degreeText, number($0.latitude), $0.speed.map(number) ?? "", $0.house.map(String.init) ?? "", "", "", ""]
        }
        rows += (result.angles ?? []).map {
            ["angle", $0.name, number($0.longitude), $0.degreeText, "", "", "\($0.house)", $0.ruler, "", ""]
        }
        rows += (result.houses ?? []).map {
            ["house_cusp", "\($0.house)", number($0.cuspLongitude), $0.cuspText, "", "", "\($0.house)", $0.ruler, "", ""]
        }
        rows += result.natalPositions.map {
            ["declination_position", $0.name, number($0.longitude), $0.degreeText, $0.declination.map(number) ?? "", "", $0.outOfBounds == true ? "OOB" : "", "", "", ""]
        }
        rows += natalAspects(from: result).map {
            ["natal_aspect", $0.transitBodyName, "", "", "", "", $0.aspectName, $0.natalBodyName, number($0.separation), number($0.orb)]
        }
        rows += (result.declinationAspects ?? []).map {
            ["declination_aspect", $0.body1, "", "", $0.declination1.map(number) ?? "", "", $0.type, $0.body2, "", number($0.diff)]
        }
        rows += (result.natalStarConjunctions ?? []).map {
            ["fixed_star", $0.planet, "", "", "", "", "", $0.star, "", number($0.orb)]
        }
        rows += patternRows(result.patterns)
        if let profile = result.chartProfile {
            rows += profile.elements.sorted { $0.key < $1.key }.map {
                ["chart_profile", "element_\($0.key)", "", "", "", "", "\($0.value)", "", "", ""]
            }
        }

        return csv(rows)
    }

    static func csv(_ result: TransitResult) -> String {
        var rows: [[String]] = [
            ["section", "name", "longitude", "degree_text", "latitude", "speed", "aspect", "other", "separation", "orb"]
        ]

        rows += result.natalPositions.map {
            ["natal_position", $0.name, number($0.longitude), $0.degreeText, number($0.latitude), $0.speed.map(number) ?? "", $0.house.map(String.init) ?? "", "", "", ""]
        }
        rows += result.transitPositions.map {
            ["transit_position", $0.name, number($0.longitude), $0.degreeText, number($0.latitude), $0.speed.map(number) ?? "", $0.house.map(String.init) ?? "", "", "", ""]
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

    // MARK: - Modern mode CSV

    private static let modernCSVHeader = [
        "section", "name", "longitude", "degree_text", "latitude", "speed", "aspect_or_house", "other", "separation", "orb"
    ]

    private static func positionRows(_ section: String, _ positions: [PositionRow]) -> [[String]] {
        positions.map {
            [section, $0.name, number($0.longitude), $0.degreeText, number($0.latitude), $0.speed.map(number) ?? "", $0.house.map(String.init) ?? "", "", "", ""]
        }
    }

    private static func aspectRows(_ section: String, _ aspects: [AspectHit]) -> [[String]] {
        aspects.map {
            [section, $0.transitBodyName, "", "", "", "", $0.aspectName, $0.natalBodyName, number($0.separation), number($0.orb)]
        }
    }

    private static func patternRows(_ patterns: [PatternResult]?) -> [[String]] {
        (patterns ?? []).map {
            ["pattern", $0.typeName, "", "", "", "", $0.confidence, $0.members.joined(separator: ";"), "", ""]
        }
    }

    static func csv(_ result: some ChartResultFields) -> String {
        var rows: [[String]] = [modernCSVHeader]
        rows += result.angles.map {
            ["angle", $0.name, number($0.longitude), $0.degreeText, "", "", "\($0.house)", $0.ruler, "", ""]
        }
        rows += result.houses.map {
            ["house_cusp", "\($0.house)", number($0.cuspLongitude), $0.cuspText, "", "", "\($0.house)", $0.ruler, "", ""]
        }
        rows += positionRows("planet", result.planets)
        rows += aspectRows("aspect", result.aspects)
        rows += patternRows(result.patterns)
        return csv(rows)
    }

    static func csv(_ result: SynastryResult) -> String {
        var rows: [[String]] = [modernCSVHeader]
        rows += positionRows("person_a_planet", result.personAPlanets)
        rows += positionRows("person_b_planet", result.personBPlanets)
        rows += aspectRows("cross_aspect", result.crossAspects)
        rows += result.aInBHouses.map {
            ["a_in_b_house", $0.bodyName, "", "", "", "", "\($0.house)", "", "", ""]
        }
        rows += result.bInAHouses.map {
            ["b_in_a_house", $0.bodyName, "", "", "", "", "\($0.house)", "", "", ""]
        }
        rows += (result.crossDeclinationAspects ?? []).map {
            ["cross_declination_aspect", $0.body1, "", "", $0.declination1.map(number) ?? "", "", $0.type, $0.body2, "", number($0.diff)]
        }
        rows += patternRows(result.patterns)
        return csv(rows)
    }

    static func csv(_ result: ProgressionResult) -> String {
        var rows: [[String]] = [modernCSVHeader]
        rows += positionRows("natal_position", result.natalPlanets)
        rows += positionRows("progressed_position", result.progressedPlanets)
        rows += aspectRows("prog_to_natal_aspect", result.progressedToNatalAspects)
        rows += aspectRows("prog_to_prog_aspect", result.progressedToProgressedAspects)
        if let lunation = result.progressedLunation {
            rows.append(["progressed_lunation", lunation.phaseName, "", "", "", "", "", "", number(lunation.sunMoonSeparation), number(lunation.phaseAngle)])
        }
        return csv(rows)
    }

    static func csv(_ result: SolarArcResult) -> String {
        var rows: [[String]] = [modernCSVHeader + ["solar_arc_rate_deg_per_year"]]
        rows.append(["arc_value", "solar_arc", number(result.arcValue), "", "", "", "", "", "", "", ""])
        rows += positionRows("natal_position", result.natalPlanets).map { $0 + [""] }
        rows += zip(positionRows("solar_arc_position", result.solarArcPlanets), result.solarArcPlanets).map {
            $0.0 + [$0.1.solarArcRateDegPerYear.map(number) ?? ""]
        }
        rows += aspectRows("sa_to_natal_aspect", result.solarArcToNatalAspects).map { $0 + [""] }
        rows += patternRows(result.patterns).map { $0 + [""] }
        return csv(rows)
    }

    static func csv(_ result: HarmonicResult) -> String {
        var rows: [[String]] = [modernCSVHeader]
        rows.append(["harmonic_order", "H\(result.harmonicOrder)", "", "", "", "", "", "", "", ""])
        rows += positionRows("harmonic_position", result.planets)
        rows += aspectRows("harmonic_aspect", result.aspects)
        return csv(rows)
    }

    static func csv(_ result: ModernReturnResult) -> String {
        let header = [
            "section", "occurrence", "label", "exact_utc", "exact_local",
            "return_longitude", "exact_error", "body", "aspect_or_house", "other", "separation", "orb",
            "meta_key", "meta_value"
        ]
        var rows: [[String]] = [header]
        func appendMeta(_ key: String, _ value: String?) {
            guard let value else { return }
            rows.append(["meta", "", "", "", "", "", "", "", "", "", "", "", key, value])
        }
        appendMeta("return_body_id", result.meta.returnBodyID)
        appendMeta("target_longitude", result.meta.targetLongitude.map(number))
        appendMeta("location_source", result.meta.locationSource)
        if let location = result.meta.location {
            appendMeta("location", "\(location.name) (\(location.latitude), \(location.longitude), \(location.timezone))")
        }
        appendMeta("zodiac", result.meta.zodiac)
        appendMeta("house_system_requested", result.meta.houseSystemRequested)
        appendMeta("house_system_effective", result.meta.houseSystemEffective)
        appendMeta("precession_correction", result.meta.precessionCorrection)
        appendMeta("ephemeris", result.meta.ephemeris)
        for (section, occurrence) in [
            ("previous_return", result.previousReturn),
            ("current_return", result.currentCycleReturn),
            ("next_return", result.nextReturn),
        ] as [(String, ModernReturnOccurrence?)] {
            guard let occurrence else { continue }
            let base = [
                section,
                section,
                occurrence.label,
                occurrence.exactUTC,
                occurrence.exactLocal,
                number(occurrence.returnLongitude),
                number(occurrence.exactError),
            ]
            rows.append(base + ["", "", "", "", "", "", ""])
            rows += occurrence.returnToNatalAspects.map {
                base + [$0.transitBodyName, $0.aspectName, $0.natalBodyName, number($0.separation), number($0.orb), "", ""]
            }
            rows += occurrence.houseOverlay.map {
                base + [$0.bodyName, "return_house \($0.returnHouse)", "natal_house \($0.natalHouse)", "", "", "", ""]
            }
            if let patterns = occurrence.chart?.patterns {
                rows += patterns.map {
                    base + ["pattern", $0.typeName, $0.members.joined(separator: ";"), "", $0.confidence, "", ""]
                }
            }
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
                    rows.append(["circumambulation_boundary", b.sign, "\(classicalBoundDegreeText(b.endDegree))°", b.ruler, String(format: "%.2f", b.arcValue), String(format: "%.1f", b.ageAtBoundary), b.estimatedDate, "", ""])
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

    static func csv(_ result: HoraryDataPacket) -> String {
        var rows: [[String]] = [
            ["section", "name", "position", "longitude", "house", "ruler_or_aspect", "extra_1", "extra_2", "extra_3"]
        ]

        rows.append(["schema", result.schema.schemaId, "", "", "", "", result.provenance.engineVersion, result.provenance.algorithmVersion, ""])
        rows.append(["question", result.questionMetadata.questionText, "", "", "", "", "", "", ""])
        rows.append(["provenance", "input_hash", result.provenance.inputHashSha256, "", "", "", "", "", ""])
        rows.append(["provenance", "config_hash", result.provenance.configHashSha256, "", "", "", "", "", ""])
        rows.append(["provenance", "aberration_light_time", result.provenance.string("aberration_light_time") ?? "", "", "", "", "", "", ""])
        rows.append(["provenance", "precession_nutation", result.provenance.string("precession_nutation") ?? "", "", "", "", "", "", ""])
        rows.append(["calculation_setting", "house_system", result.calculationConfig.houseSystem, "", "", "", "", "", ""])
        rows.append(["calculation_setting", "zodiac", result.calculationConfig.zodiac, "", "", "", "", "", ""])
        rows.append(["calculation_setting", "bounds_system", result.calculationConfig.boundsSystem, "", "", "", "", "", ""])
        rows.append(["calculation_setting", "triplicity_system", result.calculationConfig.triplicitySystem, "", "", "", "", "", ""])
        rows.append(["calculation_setting", "aspect_orb", number(result.calculationConfig.aspectOrbDeg), "", "", "", "", "", ""])
        rows.append([
            "calculation_setting",
            "numeric_precision",
            result.calculationConfig.value("numeric_precision").map(jsonString) ?? "",
            "",
            "",
            "",
            "",
            "",
            "",
        ])
        rows.append(["time", "local", result.timeAndLocation.localDatetime, "", "", "", "", "", ""])
        rows.append(["time", "utc", result.timeAndLocation.utcDatetime, "", "", "", result.timeAndLocation.timezone, "\(result.timeAndLocation.utcOffsetSeconds)", ""])
        rows.append(["sect", "is_day", "\(result.timeAndLocation.sect.isDay)", "", "", result.timeAndLocation.sect.ruleId, result.timeAndLocation.sect.evidence != nil ? "evidence_present" : "", "", ""])
        rows.append(["geocoding", result.timeAndLocation.geocoding != nil ? "present" : "null", "", "", "", "", "", "", ""])

        rows += result.angles.points.map {
            ["angle", $0.id, $0.sign.displayEn, number($0.longitudeDeg), "", "", "", "", ""]
        }
        rows += result.houses.cusps.map {
            ["house", "\($0.house)", $0.sign.displayEn, number($0.cuspLongitudeDeg), "\($0.house)", $0.domicileRulerId, $0.spanDeg.map(number) ?? "", "", ""]
        }
        rows += result.bodies.map {
            ["body", $0.bodyId, $0.displayEn, number($0.eclipticLongitude), "\($0.integerHouse)", $0.motionState, $0.eclipticSpeed.map(number) ?? "", $0.nameZh, ""]
        }
        rows += result.dignities.map {
            ["dignity", $0.string("body_id") ?? $0.id, "", "", "", $0.string("domicile_ruler_id") ?? "", "", "", ""]
        }
        rows += result.aspects.map {
            [
                "aspect",
                $0.bodyAId ?? "",
                "",
                "",
                "",
                $0.aspectId ?? "",
                $0.bodyBId ?? "",
                $0.absoluteOrbDeg.map(number) ?? "",
                $0.application ?? "",
            ]
        }
        rows += result.receptions.map {
            [
                "reception",
                $0.receiverId ?? $0.bodyAId ?? "",
                "",
                "",
                "",
                $0.receivedBodyId ?? $0.bodyBId ?? "",
                $0.dignityType ?? $0.relationKind ?? "",
                $0.relatedAspectId ?? "",
                $0.string("id") ?? $0.id,
            ]
        }
        rows += result.lots.map {
            [
                "lot",
                $0.id,
                $0.sign.displayEn,
                number($0.longitudeDeg ?? 0),
                "\($0.house.integerHouse)",
                $0.domicileRulerId ?? "",
                $0.formulaUsed ?? "",
                $0.names.en,
                $0.sectUsed ?? "",
            ]
        }
        rows += result.events.map {
            ["event", $0.eventType ?? "", $0.datetimeUtc ?? "", "", "", $0.bodyIds.joined(separator: ";"), $0.aspectId ?? "", "\($0.offsetSecondsFromQuery.map { String($0) } ?? "")", $0.id]
        }
        // Nested v2 sections as flat JSON-string rows (parity with Markdown/JSON export).
        rows += result.pairwiseGeometry.map {
            ["pairwise_geometry", $0.string("id") ?? $0.id, "", "", "", $0.string("body_a_id") ?? "", $0.string("body_b_id") ?? "", number($0.number("minimum_separation_deg") ?? 0), jsonString($0.raw)]
        }
        if let eventGraph = result.eventGraph {
            rows.append(["event_graph", "packet", "", "", "", "", "", "", jsonString(eventGraph)])
        }
        if let moon = result.moon {
            rows.append(["moon", "index", "", "", "", "", "", "", jsonString(moon)])
        } else {
            rows.append(["moon", "index", "", "", "", "", "", "", "null"])
        }
        if let nodes = result.nodes {
            rows.append(["nodes", "packet", "", "", "", "", "", "", jsonString(nodes)])
        }
        if let planetary = result.planetaryDayHour {
            rows.append(["planetary_day_hour", "packet", "", "", "", "", "", "", jsonString(planetary)])
        }
        if let considerations = result.considerationsEvidence {
            for (idx, item) in considerations.enumerated() {
                rows.append(["considerations_evidence", "\(idx)", "", "", "", "", "", "", jsonString(item)])
            }
        }
        if let optional = result.optionalModules {
            rows.append(["optional_modules", "packet", "", "", "", "", "", "", jsonString(optional)])
        }
        if let display = result.display {
            rows.append(["display", "language_primary", display.languagePrimary ?? "", "", "", "", "", "", ""])
        }
        rows += result.visibility.map {
            ["visibility", $0.bodyId, "", "", "", $0.string("morning_evening") ?? "", $0.number("ecliptic_separation_from_sun_deg").map(number) ?? "", $0.bool("visible").map { "\($0)" } ?? "null", $0.string("visible_reason_code") ?? ""]
        }
        rows += result.validation.warnings.map {
            ["warning", $0, "", "", "", "", "", "", ""]
        }

        return csv(rows)
    }

    /// Compact JSON encoding of a v2 JSON value for CSV extra columns.
    private static func jsonString(_ value: HoraryV2JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let s = String(data: data, encoding: .utf8) else {
            return String(describing: value)
        }
        return s
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
        let effectivePointSet: ModernPointSet?

        enum CodingKeys: String, CodingKey {
            case birthUTC = "birth_utc"
            case ephemeris
            case effectivePointSet = "effective_point_set"
        }
    }

    let meta: Meta
    let positions: [PositionRow]
    let angles: [ClassicalPoint]
    let houses: [HouseRow]
    let aspects: [AspectHit]
    let declinationAspects: [DeclinationAspect]
    let fixedStarConjunctions: [FixedStarConjunction]
    let patterns: [PatternResult]
    let chartProfile: ChartProfile?
    let warnings: [String]
}
