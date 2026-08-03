import SwiftUI

extension ContentView {
    var isModernTimingWorkspace: Bool {
        practiceMode == .modern && scanWorkspaceMode == "modern_timing"
    }

func selectedAspectRequests(orb: Double) -> [AspectRequest] {
        let builtinRequests = aspectOptions
            .filter { selectedAspects.contains($0.id) }
            .map { AspectRequest(id: $0.id, name: $0.name, angle: $0.angle, orb: orb) }
        let builtinAngles = Set(builtinRequests.map { aspectKey($0.angle) })
        let customRequests = parseCustomAspectDegrees(customAspectDegrees)
            .filter { !builtinAngles.contains(aspectKey($0)) }
            .map {
                AspectRequest(
                    id: "custom_\(aspectKey($0))",
                    name: "自定义 \(formatAspectDegree($0))",
                    angle: $0,
                    orb: orb
                )
            }
        return builtinRequests + customRequests
    }

    func parseCustomAspectDegrees(_ text: String) -> [Double] {
        var seen = Set<String>()
        return text
            .split { character in
                character == "," || character == "，" || character == " " || character == "\n" || character == "\t" || character == ";"
            }
            .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0 >= 0 && $0 <= 180 }
            .filter { value in
                let key = aspectKey(value)
                guard !seen.contains(key) else {
                    return false
                }
                seen.insert(key)
                return true
            }
    }

    func aspectKey(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    func formatAspectDegree(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))°"
        }
        return String(format: "%.2f°", value)
    }

    func makeMoment(from date: Date, gmtOffset: Double? = nil, includeSeconds: Bool = false) -> ChartMoment {
        var calendar = Calendar(identifier: .gregorian)
        let effectiveOffset = gmtOffset ?? self.gmtOffset
        calendar.timeZone = timeZone(for: effectiveOffset)
        var requested: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]
        if includeSeconds {
            requested.insert(.second)
        }
        let components = calendar.dateComponents(requested, from: date)

        return ChartMoment(
            year: components.year ?? 2000,
            month: components.month ?? 1,
            day: components.day ?? 1,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            timezone: timezoneLabel(for: effectiveOffset),
            second: includeSeconds ? components.second : nil
        )
    }

    func makeBirthSettingsIfValid() -> BirthSettings? {
        guard let latitude = parseDouble(birthLatitude), let longitude = parseDouble(birthLongitude) else {
            return nil
        }
        return BirthSettings(
            moment: makeMoment(from: natalDate),
            latitude: latitude,
            longitude: longitude,
            houseSystem: selectedHouseSystem,
            zodiac: selectedZodiac,
            boundsSystem: selectedBoundsSystem,
            triplicitySystem: selectedTriplicitySystem
        )
    }

    var selectedTimeZone: TimeZone {
        timeZone(for: gmtOffset)
    }

    var timezoneLabel: String {
        timezoneLabel(for: gmtOffset)
    }

    func timeZone(for offset: Double) -> TimeZone {
        GMTOffset.timeZone(hours: offset)
    }

    func timezoneLabel(for offset: Double) -> String {
        GMTOffset.label(hours: offset)
    }

    func dateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = selectedTimeZone
        return formatter.string(from: date)
    }
    func sortedBodyIDs(_ ids: Set<String>) -> [String] {
        bodyOptions
            .map(\.id)
            .filter { ids.contains($0) }
    }

    func scanTransitBodyIDs() -> [String] {
        let filtered: [String]
        switch scanMoonFilter {
        case "exclude":
            filtered = sortedBodyIDs(selectedTransitBodies).filter { $0 != "MOON" }
        case "only":
            filtered = ["MOON"]
        default:
            filtered = sortedBodyIDs(selectedTransitBodies)
        }
        if selectedScanKind == "station" {
            return filtered.filter { $0 != "SUN" && $0 != "MOON" }
        }
        return filtered
    }

    func scanWorkEstimate(
        transitBodies: [String]? = nil,
        targetText: String? = nil,
        asteroidIDs: [Int]? = nil,
        aspects: [AspectRequest]? = nil
    ) -> ScanWorkEstimate {
        ScanWorkEstimator.estimate(
            start: scanStartDate,
            end: scanEndDate,
            transitBodyIDs: transitBodies ?? scanTransitBodyIDs(),
            customAsteroids: asteroidIDs ?? parseAsteroids(customAsteroids),
            moonFilter: scanMoonFilter,
            scanKind: selectedScanKind,
            aspects: aspects ?? selectedAspectRequests(orb: 0),
            targetText: targetText ?? resolvedScanTargetText()
        )
    }

    func timingAspectRequests(selection: Set<String>, orb: Double) -> [AspectRequest] {
        aspectOptions
            .filter { selection.contains($0.id) }
            .map { AspectRequest(id: $0.id, name: $0.name, angle: $0.angle, orb: orb) }
    }

    func timingTargetPointSet(asteroidIDs: [Int]? = nil) -> ModernPointSet {
        let nodeIDs: Set<String> = ["MEAN_NODE", "TRUE_NODE", "SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE"]
        let orderedBodies = sortedBodyIDs(timingTargetBodies)
        let angleOrder = ["ASC", "MC", "DSC", "IC", "VERTEX", "ANTIVERTEX", "EQUATORIAL_ASCENDANT"]
        let midpointPairs = timingMidpointPairs.sorted { $0.axisID < $1.axisID }
        return ModernPointSet(
            bodyIDs: orderedBodies.filter { !nodeIDs.contains($0) },
            includeNodes: orderedBodies.contains(where: nodeIDs.contains),
            nodeMode: modernNodeMode,
            customAsteroids: timingUseCustomAsteroids
                ? (asteroidIDs ?? parseAsteroids(customAsteroids))
                : [],
            angleIDs: angleOrder.filter { timingTargetAngles.contains($0) },
            houseCusps: timingTargetHouseCusps.sorted(),
            lotIDs: timingTargetLots.sorted(),
            midpointPairs: midpointPairs.isEmpty ? nil : midpointPairs
        )
    }

    /// Relationship Timing uses the point set embedded in target_chart. The
    /// ordinary sidebar point-set controls are intentionally ignored while a
    /// relationship target is active.
    func timingEffectiveTargetPointSet(asteroidIDs: [Int]? = nil) -> ModernPointSet {
        timingEffectiveTargetPointSet(for: modernTimingTargetChart, asteroidIDs: asteroidIDs)
    }

    func timingEffectiveTargetPointSet(
        for targetChart: ModernTimingTargetChart?,
        asteroidIDs: [Int]? = nil
    ) -> ModernPointSet {
        targetChart?.pointSet ?? timingTargetPointSet(asteroidIDs: asteroidIDs)
    }

    /// Progressed Composite v1 is deliberately limited to planets, nodes and
    /// custom asteroids. Angles, house cusps, Lots and midpoint pairs never
    /// enter this request, even if another modern sub-mode selected them.
    func progressedCompositePointSet(asteroidIDs: [Int]? = nil) -> ModernPointSet {
        let nodeIDs: Set<String> = ["MEAN_NODE", "TRUE_NODE", "SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE"]
        let selectedBodies = sortedBodyIDs(progressedCompositeBodies)
        return ModernPointSet(
            bodyIDs: selectedBodies.filter { !nodeIDs.contains($0) },
            includeNodes: progressedCompositeIncludeNodes || selectedBodies.contains(where: nodeIDs.contains),
            nodeMode: modernNodeMode,
            customAsteroids: progressedCompositeUseCustomAsteroids
                ? (asteroidIDs ?? parseAsteroids(customAsteroids))
                : [],
            angleIDs: [],
            houseCusps: [],
            lotIDs: [],
            midpointPairs: nil
        )
    }

    func exactMomentText(_ moment: ChartMoment) -> String {
        let date = String(format: "%04d-%02d-%02d %02d:%02d", moment.year, moment.month, moment.day, moment.hour, moment.minute)
        return date + " · " + moment.timezone
    }

    func pointSetSummary(_ pointSet: ModernPointSet) -> String {
        var sections: [String] = []
        let bodies = (pointSet.resolvedBodyIDs ?? pointSet.bodyIDs).joined(separator: ", ")
        if !bodies.isEmpty { sections.append("行星 \(bodies)") }
        if pointSet.includeNodes { sections.append("节点 \(pointSet.nodeMode)") }
        if !pointSet.customAsteroids.isEmpty {
            sections.append("小行星 " + pointSet.customAsteroids.map(String.init).joined(separator: ", "))
        }
        if !pointSet.angleIDs.isEmpty { sections.append("轴点 " + pointSet.angleIDs.joined(separator: ", ")) }
        if !pointSet.houseCusps.isEmpty { sections.append("宫头 " + pointSet.houseCusps.map(String.init).joined(separator: ", ")) }
        if !pointSet.lotIDs.isEmpty { sections.append("Lots " + pointSet.lotIDs.joined(separator: ", ")) }
        if let midpointPairs = pointSet.midpointPairs, !midpointPairs.isEmpty {
            sections.append("中点轴 \(midpointPairs.count) 条")
        }
        return sections.isEmpty ? "（空点集）" : sections.joined(separator: "；")
    }

    var midpointSelectedPointIDs: Set<String> {
        let nodeIDs: Set<String> = ["MEAN_NODE", "TRUE_NODE", "SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE"]
        var pointIDs = midpointBodies.subtracting(nodeIDs)
        if !midpointBodies.isDisjoint(with: nodeIDs) {
            if modernNodeMode == "mean_node" {
                pointIDs.formUnion(["MEAN_NODE", "SOUTH_MEAN_NODE"])
            } else {
                pointIDs.formUnion(["TRUE_NODE", "SOUTH_TRUE_NODE"])
            }
        }
        pointIDs.formUnion(parseAsteroids(customAsteroids).map { "AST:\($0)" })
        pointIDs.formUnion(midpointAngles)
        pointIDs.formUnion(midpointHouseCusps.map { "HOUSE_CUSP_\($0)" })
        pointIDs.formUnion(midpointLots)
        return pointIDs
    }

    var midpointEffectiveFocusPointIDs: [String] {
        midpointFocusPointIDs
            .intersection(midpointSelectedPointIDs)
            .sorted()
    }

    func midpointPointSet(asteroidIDs: [Int]) -> ModernPointSet {
        let nodeIDs: Set<String> = ["MEAN_NODE", "TRUE_NODE", "SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE"]
        return ModernPointSet(
            bodyIDs: sortedBodyIDs(midpointBodies).filter { !nodeIDs.contains($0) },
            includeNodes: !midpointBodies.isDisjoint(with: nodeIDs),
            nodeMode: modernNodeMode,
            customAsteroids: asteroidIDs,
            angleIDs: Self.modernTimingAngleOptions.map(\.id).filter { midpointAngles.contains($0) },
            houseCusps: midpointHouseCusps.sorted(),
            lotIDs: midpointLots.sorted()
        )
    }

    func timingTechniqueRequests() -> [ModernTimingTechniqueRequest] {
        timingTechniqueRequests(for: modernTimingTargetChart)
    }

    func timingTechniqueRequests(for targetChart: ModernTimingTargetChart?) -> [ModernTimingTechniqueRequest] {
        if targetChart != nil {
            return [
                ModernTimingTechniqueRequest(
                    id: "transit",
                    movingBodyIDs: sortedBodyIDs(timingTransitBodies),
                    eventTypes: ["aspect"],
                    aspects: timingAspectRequests(selection: timingTransitAspects, orb: timingTransitOrb)
                )
            ]
        }

        var techniques: [ModernTimingTechniqueRequest] = []
        if timingEnabledTechniques.contains("transit") {
            techniques.append(
                ModernTimingTechniqueRequest(
                    id: "transit",
                    movingBodyIDs: sortedBodyIDs(timingTransitBodies),
                    eventTypes: ["aspect", "ingress", "station"].filter { timingTransitEventTypes.contains($0) },
                    aspects: timingAspectRequests(selection: timingTransitAspects, orb: timingTransitOrb)
                )
            )
        }
        if timingEnabledTechniques.contains("secondary_progression") {
            techniques.append(
                ModernTimingTechniqueRequest(
                    id: "secondary_progression",
                    movingBodyIDs: sortedBodyIDs(timingProgressionBodies),
                    eventTypes: ["aspect", "moon_ingress", "lunation"].filter { timingProgressionEventTypes.contains($0) },
                    aspects: timingAspectRequests(selection: timingProgressionAspects, orb: timingProgressionOrb)
                )
            )
        }
        if timingEnabledTechniques.contains("solar_arc") {
            let angleOrder = ["ASC", "MC", "DSC", "IC", "VERTEX", "ANTIVERTEX", "EQUATORIAL_ASCENDANT"]
            techniques.append(
                ModernTimingTechniqueRequest(
                    id: "solar_arc",
                    movingBodyIDs: sortedBodyIDs(timingSolarArcPoints) + angleOrder.filter { timingSolarArcPoints.contains($0) },
                    eventTypes: ["aspect"],
                    aspects: timingAspectRequests(selection: timingSolarArcAspects, orb: timingSolarArcOrb)
                )
            )
        }
        return techniques
    }

    func timingWorkEstimate(
        techniques: [ModernTimingTechniqueRequest]? = nil,
        targetPointSet: ModernPointSet? = nil
    ) -> ModernTimingWorkEstimate {
        ModernTimingWorkEstimator.estimate(
            start: scanStartDate,
            end: scanEndDate,
            techniques: techniques ?? timingTechniqueRequests(),
            targetPointSet: targetPointSet ?? timingTargetPointSet()
        )
    }
    func parseAsteroids(_ text: String) -> [Int] {
        text
            .split { character in
                character == "," || character == " " || character == "\n" || character == "\t" || character == ";"
            }
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0 > 0 }
    }

func parseDouble(_ text: String) -> Double? {
    Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
}
}
