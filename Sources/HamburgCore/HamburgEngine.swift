import Foundation

/// The Hamburg / Uranian calculation engine.
///
/// The engine is deliberately independent from the app's Python pipeline.
/// It consumes a `HamburgChart` (standard positions may come from the
/// existing backend, TNPs are native) and produces a deterministic,
/// Codable report.
public struct HamburgEngine {
    public var options: HamburgOptions

    public init(options: HamburgOptions = HamburgOptions()) {
        self.options = options
    }

    public func report(
        chart: HamburgChart,
        referenceJulianDay: Double? = nil,
        referenceMoment: Moment? = nil
    ) -> HamburgReport {
        let normalized = options.normalized()
        var warnings = chart.warnings + normalized.warnings
        let options = normalized.options
        var resolvedReferenceJD = referenceJulianDay
        if resolvedReferenceJD == nil, let referenceMoment {
            resolvedReferenceJD = try? referenceMoment.julianDayUT
        }

        let positions = makePositions(chart: chart, options: options)
        let houses = makeHouses(chart: chart)
        let axes = makeAxes(chart: chart, options: options)
        let trees = makeTrees(chart: chart, axes: axes, options: options, warnings: &warnings)
        let pictures = makePictures(chart: chart, options: options, warnings: &warnings)
        let solarArc = makeSolarArc(
            chart: chart,
            referenceJulianDay: resolvedReferenceJD,
            axes: axes,
            options: options,
            warnings: &warnings
        )
        let antiscia = makeAntiscia(
            chart: chart,
            axes: axes,
            options: options,
            warnings: &warnings
        )

        let usesBackend = chart.points.contains { $0.source == .backend }
        let meta = ReportMeta(
            engine: HamburgCoreVersion.engine,
            version: HamburgCoreVersion.version,
            method: HamburgCoreVersion.method,
            julianDayUT: chart.julianDayUT,
            momentUTC: JulianDay.iso8601(fromJulianDay: chart.julianDayUT),
            referenceUTC: resolvedReferenceJD.map { JulianDay.iso8601(fromJulianDay: $0) },
            location: chart.location.map { ReportLocation(location: $0) },
            dialModulus: options.dialModulus,
            orbUnit: options.orbUnit.rawValue,
            midpointOrb: options.midpointOrb,
            pictureOrb: options.pictureOrb,
            pointCount: chart.points.count,
            tnpModel: "Neely 1980 J1900 Keplerian (native Swift)",
            ephemeris: usesBackend
                ? "Swiss Ephemeris via existing Python backend + native TNP"
                : "User-supplied positions + native TNP"
        )

        return HamburgReport(
            meta: meta,
            positions: positions,
            houses: houses,
            midpoints: axes,
            trees: trees,
            pictures: pictures,
            solarArc: solarArc,
            antiscia: antiscia,
            warnings: Array(Set(warnings)).sorted()
        )
    }

    // MARK: - Positions and houses

    private func makePositions(chart: HamburgChart, options: HamburgOptions) -> [ReportPosition] {
        chart.points.map { point in
            let zodiac = ZodiacPosition(longitude: point.longitude)
            let dials = options.displayDials.map {
                DialValue(modulus: $0, longitude: Angle.fold(point.longitude, modulus: $0))
            }
            return ReportPosition(
                id: point.id,
                name: point.name,
                nameLocal: point.nameLocal,
                kind: point.kind.rawValue,
                longitude: point.longitude,
                latitude: point.latitude,
                speed: point.speed,
                sign: zodiac.sign.name,
                degreeText: zodiac.text,
                house: point.house,
                dials: dials,
                antiscion: Angle.normalize(180 - point.longitude),
                contraAntiscion: Angle.normalize(-point.longitude),
                source: point.source.rawValue,
                keywords: point.keywords,
                keywordsZh: point.keywordsZh
            )
        }
    }

    private func makeHouses(chart: HamburgChart) -> HouseSet {
        HouseSet(
            system: chart.houseAssignment.rawValue,
            cusps: makeCusps(chart.cusps),
            backendSystem: chart.location?.backendHouseSystem,
            backendCusps: chart.backendCusps.count == 12 ? makeCusps(chart.backendCusps) : nil
        )
    }

    private func makeCusps(_ cusps: [Double]) -> [HouseCusp] {
        cusps.enumerated().map { index, longitude in
            let zodiac = ZodiacPosition(longitude: longitude)
            return HouseCusp(
                house: index + 1,
                longitude: Angle.normalize(longitude),
                sign: zodiac.sign.name,
                degreeText: zodiac.text
            )
        }
    }

    // MARK: - Midpoints

    private func makeAxes(chart: HamburgChart, options: HamburgOptions) -> [MidpointAxis] {
        let points = chart.points.sorted { $0.id < $1.id }
        guard points.count >= 2 else { return [] }
        var axes: [MidpointAxis] = []
        axes.reserveCapacity(points.count * (points.count - 1) / 2)
        for first in 0..<(points.count - 1) {
            for second in (first + 1)..<points.count {
                let a = points[first]
                let b = points[second]
                let direct = Angle.midpoint(a.longitude, b.longitude)
                let opposite = Angle.normalize(direct + 180)
                axes.append(MidpointAxis(
                    id: "midpoint|\(a.id)|\(b.id)",
                    pointA: a.id,
                    pointB: b.id,
                    direct: direct,
                    opposite: opposite,
                    dialDirect: Angle.fold(direct, modulus: options.dialModulus),
                    dialOpposite: Angle.fold(opposite, modulus: options.dialModulus)
                ))
            }
        }
        return axes.sorted {
            if abs($0.direct - $1.direct) > 1e-12 { return $0.direct < $1.direct }
            return $0.id < $1.id
        }
    }

    private func makeTrees(
        chart: HamburgChart,
        axes: [MidpointAxis],
        options: HamburgOptions,
        warnings: inout [String]
    ) -> [MidpointTree] {
        let pointsByID = chart.pointsByID
        let allIDs = options.focusPointIDs.contains(where: { $0 == "*" || $0 == "ALL" })
        let requested = allIDs ? chart.points.map(\.id) : options.focusPointIDs
        var seen: Set<String> = []
        var trees: [MidpointTree] = []

        for focusID in requested {
            guard !seen.contains(focusID) else { continue }
            seen.insert(focusID)
            // A chart may legitimately lack angles (unknown birth time), so
            // default focus IDs that are absent are skipped rather than
            // turned into noise.
            guard let focus = pointsByID[focusID] else { continue }
            var hits: [MidpointHit] = []
            for axis in axes {
                // A planet on the midpoint of itself and another point is a
                // geometric artifact, not a Witte picture. Exclude it.
                guard axis.pointA != focus.id, axis.pointB != focus.id else { continue }
                let proximity = DialMath.proximity(
                    longitude: focus.longitude,
                    axis: axis.direct,
                    modulus: options.dialModulus
                )
                guard proximity.distance <= options.dialOrbForMidpoints + 1e-9 else { continue }
                hits.append(MidpointHit(
                    id: "midpoint_hit|\(focus.id)|\(axis.id)|\(proximity.harmonic)",
                    focus: focus.id,
                    focusName: focus.name,
                    axisID: axis.id,
                    pointA: axis.pointA,
                    pointB: axis.pointB,
                    branch: proximity.branch,
                    harmonic: proximity.harmonic,
                    axisLongitude: proximity.nearestLongitude,
                    focusLongitude: focus.longitude,
                    orb: DialMath.zodiacOrb(
                        fromDialDistance: proximity.distance,
                        modulus: options.dialModulus
                    ),
                    orbDial: proximity.distance,
                    formula: "\(focus.id) = \(axis.pointA)/\(axis.pointB)"
                ))
            }
            hits.sort {
                if abs($0.orbDial - $1.orbDial) > 1e-12 { return $0.orbDial < $1.orbDial }
                if $0.axisID != $1.axisID { return $0.axisID < $1.axisID }
                return $0.harmonic < $1.harmonic
            }
            if hits.count > options.maxHitsPerTree {
                warnings.append("Midpoint tree \(focus.id) truncated from \(hits.count) to \(options.maxHitsPerTree) hits.")
                hits = Array(hits.prefix(options.maxHitsPerTree))
            }
            trees.append(MidpointTree(focus: focus.id, focusName: focus.name, hits: hits))
        }
        return trees
    }

    // MARK: - Planetary pictures

    private func makePictures(
        chart: HamburgChart,
        options: HamburgOptions,
        warnings: inout [String]
    ) -> [PlanetaryPicture] {
        var points = chart.points
        guard points.count >= 4 else { return [] }
        if points.count > 64 {
            warnings.append("Planetary picture scan limited to the first 64 of \(points.count) points.")
            points = Array(points.prefix(64))
        }
        let orbDial = options.dialOrbForPictures
        var pictures: [String: PlanetaryPicture] = [:]

        // Four distinct factors are the smallest complete Witte sum picture
        // A + B = C + D. Enumerating combinations, rather than permutations,
        // keeps the scan O(C(n,4)) and automatically avoids duplicate points.
        for i in 0..<(points.count - 3) {
            for j in (i + 1)..<(points.count - 2) {
                for k in (j + 1)..<(points.count - 1) {
                    for l in (k + 1)..<points.count {
                        let pairings: [((Int, Int), (Int, Int))] = [
                            ((i, j), (k, l)),
                            ((i, k), (j, l)),
                            ((i, l), (j, k)),
                        ]
                        var best: ((Int, Int), (Int, Int))?
                        var bestDistance = Double.infinity
                        for pairing in pairings {
                            let first = points[pairing.0.0].longitude + points[pairing.0.1].longitude
                            let second = points[pairing.1.0].longitude + points[pairing.1.1].longitude
                            let difference = Angle.fold(first - second, modulus: options.dialModulus)
                            let distance = min(difference, options.dialModulus - difference)
                            if distance < bestDistance {
                                bestDistance = distance
                                best = pairing
                            }
                        }
                        guard let pairing = best, bestDistance <= orbDial + 1e-9 else { continue }

                        var leftIndices = [pairing.0.0, pairing.0.1]
                        var rightIndices = [pairing.1.0, pairing.1.1]
                        leftIndices.sort { points[$0].id < points[$1].id }
                        rightIndices.sort { points[$0].id < points[$1].id }
                        let leftKey = "\(points[leftIndices[0]].id)|\(points[leftIndices[1]].id)"
                        let rightKey = "\(points[rightIndices[0]].id)|\(points[rightIndices[1]].id)"
                        if leftKey > rightKey {
                            swap(&leftIndices, &rightIndices)
                        }

                        let left = leftIndices.map { points[$0].id }
                        let right = rightIndices.map { points[$0].id }
                        let leftSum = Angle.normalize(
                            points[leftIndices[0]].longitude + points[leftIndices[1]].longitude
                        )
                        let rightSum = Angle.normalize(
                            points[rightIndices[0]].longitude + points[rightIndices[1]].longitude
                        )
                        let formula = "\(left[0]) + \(left[1]) = \(right[0]) + \(right[1])"
                        let picture = PlanetaryPicture(
                            id: formula,
                            formula: formula,
                            left: left,
                            right: right,
                            leftSum: leftSum,
                            rightSum: rightSum,
                            dialLongitude: Angle.fold(leftSum, modulus: options.dialModulus),
                            orb: DialMath.zodiacOrb(
                                fromDialDistance: bestDistance,
                                modulus: options.dialModulus
                            ),
                            orbDial: bestDistance
                        )
                        if let existing = pictures[formula], existing.orbDial <= picture.orbDial {
                            continue
                        }
                        pictures[formula] = picture
                    }
                }
            }
        }

        var result = Array(pictures.values).sorted {
            if abs($0.orbDial - $1.orbDial) > 1e-12 { return $0.orbDial < $1.orbDial }
            return $0.formula < $1.formula
        }
        if result.count > options.maxPictures {
            warnings.append("Planetary picture list truncated from \(result.count) to \(options.maxPictures).")
            result = Array(result.prefix(options.maxPictures))
        }
        return result
    }

    // MARK: - Solar arc

    private func makeSolarArc(
        chart: HamburgChart,
        referenceJulianDay: Double?,
        axes: [MidpointAxis],
        options: HamburgOptions,
        warnings: inout [String]
    ) -> SolarArcReport? {
        guard options.solarArcEnabled else { return nil }
        guard let referenceJulianDay else {
            warnings.append("solar_arc_enabled=true but no reference moment was supplied; solar arc skipped.")
            return nil
        }
        guard let sun = chart.pointsByID["SUN"] else {
            warnings.append("Solar arc requires SUN in the chart; solar arc skipped.")
            return nil
        }

        let ageYears = (referenceJulianDay - chart.julianDayUT) / 365.2422
        let signedArc: Double
        switch options.solarArcMethod {
        case .trueSun:
            let progressedJD = chart.julianDayUT + ageYears
            let progressedSun = SolarEphemeris.apparentLongitude(julianDay: progressedJD)
            signedArc = Angle.signedSeparation(sun.longitude, progressedSun)
        case .naibod:
            signedArc = 0.98564733 * ageYears
        case .custom:
            signedArc = (options.solarArcRate ?? 1.0) * ageYears
        }

        let directArc = Angle.normalize(signedArc)
        let converseArc = Angle.normalize(-signedArc)
        let includeConverse = options.includeConverseSolarArc && abs(signedArc) > 1e-12
        let directions: [(label: String, arc: Double, displayArc: Double)] = [
            ("direct", signedArc, directArc)
        ] + (includeConverse ? [("converse", -signedArc, converseArc)] : [])

        var directedPositions: [DirectedPosition] = []
        var pointHits: [String: SolarArcPointHit] = [:]
        var midpointHits: [String: SolarArcMidpointHit] = [:]
        let orbDial = options.dialOrbForSolarArc
        let directable = chart.points.filter { $0.kind != .axis }

        for direction in directions {
            for point in directable {
                let longitude = Angle.normalize(point.longitude + direction.arc)
                let zodiac = ZodiacPosition(longitude: longitude)
                directedPositions.append(DirectedPosition(
                    id: point.id,
                    name: "SA \(point.name)",
                    longitude: longitude,
                    sign: zodiac.sign.name,
                    degreeText: zodiac.text,
                    dials: options.displayDials.map {
                        DialValue(modulus: $0, longitude: Angle.fold(longitude, modulus: $0))
                    },
                    arc: direction.displayArc,
                    direction: direction.label
                ))

                for natal in chart.points {
                    guard natal.id != point.id else { continue }
                    let proximity = DialMath.proximity(
                        longitude: longitude,
                        axis: natal.longitude,
                        modulus: options.dialModulus
                    )
                    guard proximity.distance <= orbDial + 1e-9 else { continue }
                    let hit = SolarArcPointHit(
                        id: "solar_arc_point|\(direction.label)|\(point.id)|\(natal.id)|\(proximity.harmonic)",
                        directed: point.id,
                        natal: natal.id,
                        directedLongitude: longitude,
                        natalLongitude: natal.longitude,
                        orb: DialMath.zodiacOrb(
                            fromDialDistance: proximity.distance,
                            modulus: options.dialModulus
                        ),
                        orbDial: proximity.distance,
                        formula: "SA(\(point.id)) = \(natal.id)",
                        direction: direction.label
                    )
                    if pointHits[hit.id] == nil { pointHits[hit.id] = hit }
                }

                for axis in axes {
                    let proximity = DialMath.proximity(
                        longitude: longitude,
                        axis: axis.direct,
                        modulus: options.dialModulus
                    )
                    guard proximity.distance <= orbDial + 1e-9 else { continue }
                    let hit = SolarArcMidpointHit(
                        id: "solar_arc_midpoint|\(direction.label)|\(point.id)|\(axis.id)|\(proximity.harmonic)",
                        directed: point.id,
                        axisID: axis.id,
                        pointA: axis.pointA,
                        pointB: axis.pointB,
                        branch: proximity.branch,
                        harmonic: proximity.harmonic,
                        directedLongitude: longitude,
                        axisLongitude: proximity.nearestLongitude,
                        orb: DialMath.zodiacOrb(
                            fromDialDistance: proximity.distance,
                            modulus: options.dialModulus
                        ),
                        orbDial: proximity.distance,
                        formula: "SA(\(point.id)) = \(axis.pointA)/\(axis.pointB)",
                        direction: direction.label
                    )
                    if midpointHits[hit.id] == nil { midpointHits[hit.id] = hit }
                }
            }

            if options.includeDirectedMidpoints {
                for axis in axes {
                    let directedAxis = Angle.normalize(axis.direct + direction.arc)
                    for natal in chart.points {
                        let proximity = DialMath.proximity(
                            longitude: directedAxis,
                            axis: natal.longitude,
                            modulus: options.dialModulus
                        )
                        guard proximity.distance <= orbDial + 1e-9 else { continue }
                        let hit = SolarArcMidpointHit(
                            id: "solar_arc_axis|\(direction.label)|\(axis.id)|\(natal.id)|\(proximity.harmonic)",
                            directed: axis.id,
                            axisID: axis.id,
                            pointA: axis.pointA,
                            pointB: axis.pointB,
                            branch: proximity.branch,
                            harmonic: proximity.harmonic,
                            directedLongitude: directedAxis,
                            axisLongitude: natal.longitude,
                            orb: DialMath.zodiacOrb(
                                fromDialDistance: proximity.distance,
                                modulus: options.dialModulus
                            ),
                            orbDial: proximity.distance,
                            formula: "SA(\(axis.pointA)/\(axis.pointB)) = \(natal.id)",
                            direction: direction.label
                        )
                        if midpointHits[hit.id] == nil { midpointHits[hit.id] = hit }
                    }
                }
            }
        }

        var pointResult = Array(pointHits.values).sorted {
            if abs($0.orbDial - $1.orbDial) > 1e-12 { return $0.orbDial < $1.orbDial }
            return $0.formula < $1.formula
        }
        var midpointResult = Array(midpointHits.values).sorted {
            if abs($0.orbDial - $1.orbDial) > 1e-12 { return $0.orbDial < $1.orbDial }
            return $0.formula < $1.formula
        }
        if pointResult.count + midpointResult.count > options.maxSolarArcHits {
            warnings.append(
                "Solar-arc contacts truncated from \(pointResult.count + midpointResult.count) to \(options.maxSolarArcHits)."
            )
            let pointQuota = min(pointResult.count, options.maxSolarArcHits)
            pointResult = Array(pointResult.prefix(pointQuota))
            midpointResult = Array(midpointResult.prefix(options.maxSolarArcHits - pointQuota))
        }

        return SolarArcReport(
            method: options.solarArcMethod.rawValue,
            ageYears: ageYears,
            arcDegrees: directArc,
            converseArcDegrees: includeConverse ? converseArc : nil,
            directedPositions: directedPositions.sorted {
                if $0.direction != $1.direction { return $0.direction < $1.direction }
                return $0.id < $1.id
            },
            pointHits: pointResult,
            midpointHits: midpointResult
        )
    }

    // MARK: - Antiscia

    private func makeAntiscia(
        chart: HamburgChart,
        axes: [MidpointAxis],
        options: HamburgOptions,
        warnings: inout [String]
    ) -> AntisciaReport? {
        guard options.antisciaEnabled else { return nil }
        let orbDial = options.dialOrbForMidpoints
        var pointContacts: [String: AntisciaPointContact] = [:]
        var midpointContacts: [String: AntisciaMidpointContact] = [:]

        for source in chart.points {
            let projections: [(type: String, longitude: Double)] = [
                ("antiscion", Angle.normalize(180 - source.longitude)),
                ("contra_antiscion", Angle.normalize(-source.longitude)),
            ]
            for projection in projections {
                for target in chart.points where target.id != source.id {
                    let proximity = DialMath.proximity(
                        longitude: projection.longitude,
                        axis: target.longitude,
                        modulus: options.dialModulus
                    )
                    guard proximity.distance <= orbDial + 1e-9 else { continue }
                    let formula = "\(projection.type)(\(source.id)) = \(target.id)"
                    let hit = AntisciaPointContact(
                        id: "antiscia_point|\(projection.type)|\(source.id)|\(target.id)|\(proximity.harmonic)",
                        source: source.id,
                        target: target.id,
                        type: projection.type,
                        projectedLongitude: projection.longitude,
                        targetLongitude: target.longitude,
                        orb: DialMath.zodiacOrb(
                            fromDialDistance: proximity.distance,
                            modulus: options.dialModulus
                        ),
                        orbDial: proximity.distance,
                        formula: formula
                    )
                    if pointContacts[hit.id] == nil { pointContacts[hit.id] = hit }
                }

                for axis in axes {
                    let proximity = DialMath.proximity(
                        longitude: projection.longitude,
                        axis: axis.direct,
                        modulus: options.dialModulus
                    )
                    guard proximity.distance <= orbDial + 1e-9 else { continue }
                    let formula = "\(projection.type)(\(source.id)) = \(axis.pointA)/\(axis.pointB)"
                    let hit = AntisciaMidpointContact(
                        id: "antiscia_midpoint|\(projection.type)|\(source.id)|\(axis.id)|\(proximity.harmonic)",
                        source: source.id,
                        axisID: axis.id,
                        pointA: axis.pointA,
                        pointB: axis.pointB,
                        type: projection.type,
                        branch: proximity.branch,
                        harmonic: proximity.harmonic,
                        projectedLongitude: projection.longitude,
                        axisLongitude: proximity.nearestLongitude,
                        orb: DialMath.zodiacOrb(
                            fromDialDistance: proximity.distance,
                            modulus: options.dialModulus
                        ),
                        orbDial: proximity.distance,
                        formula: formula
                    )
                    if midpointContacts[hit.id] == nil { midpointContacts[hit.id] = hit }
                }
            }
        }

        var pointResult = Array(pointContacts.values).sorted {
            if abs($0.orbDial - $1.orbDial) > 1e-12 { return $0.orbDial < $1.orbDial }
            return $0.formula < $1.formula
        }
        var midpointResult = Array(midpointContacts.values).sorted {
            if abs($0.orbDial - $1.orbDial) > 1e-12 { return $0.orbDial < $1.orbDial }
            return $0.formula < $1.formula
        }
        if pointResult.count > options.maxAntisciaContacts {
            warnings.append("Antiscia point contacts truncated to \(options.maxAntisciaContacts).")
            pointResult = Array(pointResult.prefix(options.maxAntisciaContacts))
        }
        if midpointResult.count > options.maxAntisciaContacts {
            warnings.append("Antiscia midpoint contacts truncated to \(options.maxAntisciaContacts).")
            midpointResult = Array(midpointResult.prefix(options.maxAntisciaContacts))
        }
        return AntisciaReport(pointContacts: pointResult, midpointContacts: midpointResult)
    }
}
