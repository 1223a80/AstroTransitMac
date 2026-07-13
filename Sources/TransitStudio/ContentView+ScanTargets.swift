import SwiftUI

extension ContentView {
var targetPlanetOptions: [TargetPositionOption] {
        if practiceMode == .classical {
            return calcVM.classicalResult?.planets.map {
                TargetPositionOption(id: $0.id, name: $0.name, longitude: $0.longitude)
            } ?? []
        }
        if practiceMode == .vedic {
            let planets = calcVM.vedicResult?.rasiChart?.planets ?? calcVM.vedicResult?.planets ?? [:]
            return planets.values
                .map { TargetPositionOption(id: $0.bodyId, name: $0.name, longitude: $0.longitude) }
                .sorted { $0.id < $1.id }
        }

        return calcVM.fullNatalResult?.natalPositions
            .filter { bodyGroup(for: $0.bodyID) == .planets }
            .map { TargetPositionOption(id: $0.bodyID, name: $0.name, longitude: $0.longitude) } ?? []
    }

    var targetAsteroidOptions: [TargetPositionOption] {
        guard practiceMode == .modern else {
            return []
        }

        return calcVM.fullNatalResult?.natalPositions
            .filter { row in
                row.bodyID.hasPrefix("AST:") || bodyGroup(for: row.bodyID) == .minorBodies
            }
            .map { TargetPositionOption(id: $0.bodyID, name: $0.name, longitude: $0.longitude) } ?? []
    }

    var targetVirtualAndAngleOptions: [TargetPositionOption] {
        if practiceMode == .classical {
            return calcVM.classicalResult?.angles.map {
                TargetPositionOption(id: $0.id, name: $0.name, longitude: $0.longitude)
            } ?? []
        }
        if practiceMode == .vedic {
            let angleRows = calcVM.vedicResult?.rasiChart?.angles.map {
                TargetPositionOption(id: $0.id, name: $0.name, longitude: $0.longitude)
            } ?? []
            let lagnaRows = calcVM.vedicResult?.specialLagnas?.map {
                TargetPositionOption(id: $0.id, name: $0.nameZh, longitude: $0.longitude)
            } ?? []
            return angleRows + lagnaRows.filter { lagna in !angleRows.contains(where: { $0.id == lagna.id }) }
        }

        let virtualRows = calcVM.fullNatalResult?.natalPositions
            .filter { bodyGroup(for: $0.bodyID) == .virtualPoints }
            .map { TargetPositionOption(id: $0.bodyID, name: $0.name, longitude: $0.longitude) } ?? []
        let angleRows = calcVM.fullNatalResult?.angles?.map {
            TargetPositionOption(id: $0.id, name: $0.name, longitude: $0.longitude)
        } ?? []
        return virtualRows + angleRows.filter { angle in !virtualRows.contains(where: { $0.id == angle.id }) }
    }

    var targetHouseOptions: [HouseRow] {
        if practiceMode == .classical {
            return calcVM.classicalResult?.houses ?? []
        }
        if practiceMode == .vedic {
            return calcVM.vedicResult?.rasiChart?.houses.map {
                HouseRow(
                    house: $0.house,
                    sign: $0.sign,
                    cuspLongitude: $0.cuspLongitude,
                    cuspText: $0.cuspText,
                    ruler: $0.ruler
                )
            } ?? []
        }

        if let houses = calcVM.fullNatalResult?.houses, !houses.isEmpty {
            return houses
        }
        return []
    }

    var targetLotOptions: [TargetPositionOption] {
        if practiceMode == .classical {
            return calcVM.classicalResult?.lots.map {
                TargetPositionOption(id: $0.id, name: $0.name, longitude: $0.longitude)
            } ?? []
        }
        if practiceMode == .vedic {
            return calcVM.vedicResult?.upagrahas?.map {
                TargetPositionOption(id: $0.id, name: $0.nameZh, longitude: $0.longitude)
            } ?? []
        }

        return calcVM.fullNatalResult?.lots?.map {
            TargetPositionOption(id: $0.id, name: $0.name, longitude: $0.longitude)
        } ?? []
    }

    func bodyGroup(for bodyID: String) -> BodyGroup? {
        bodyOptions.first { $0.id == bodyID }?.group
    }

    var hasNatalSourceForCurrentMode: Bool {
        switch practiceMode {
        case .modern:
            return calcVM.fullNatalResult != nil
        case .classical:
            return calcVM.classicalResult != nil
        case .vedic:
            return calcVM.vedicResult != nil
        }
    }

    @MainActor
    func syncScanTargetsFromNatalChart() {
        guard hasNatalSourceForCurrentMode else {
            return
        }

        if selectedTargetAngles.isEmpty {
            selectedTargetAngles = Set(targetVirtualAndAngleOptions.map(\.id))
        }
        if selectedTargetPlanets.isEmpty {
            selectedTargetPlanets = Set(targetPlanetOptions.map(\.id))
        }
        if selectedTargetAsteroids.isEmpty {
            selectedTargetAsteroids = Set(targetAsteroidOptions.map(\.id))
        }
        if selectedTargetHouses.isEmpty {
            selectedTargetHouses = Set(targetHouseOptions.filter { [1, 4, 7, 10].contains($0.house) }.map(\.house))
        }
        if selectedTargetLots.isEmpty {
            selectedTargetLots = Set(targetLotOptions.filter { ["fortune", "spirit", "eros", "victory"].contains($0.id) }.map(\.id))
        }

        scanTargetsText = buildNatalTargetText(includeAll: true)
    }

    var allBuiltinBodyIDs: [String] {
        bodyOptions.map(\.id)
    }

    func filteredModernNatalResult(from result: TransitResult, asteroidIDs: [Int]) -> TransitResult {
        let asteroidBodyIDs = Set(asteroidIDs.map { "AST:\($0)" })
        let visibleBodyIDs = selectedNatalBodies.union(asteroidBodyIDs)
        let filteredNatalPositions = result.natalPositions.filter { visibleBodyIDs.contains($0.bodyID) }
        let filteredTransitPositions = result.transitPositions.filter { visibleBodyIDs.contains($0.bodyID) }
        let filteredAspects = result.aspects.filter { aspect in
            visibleBodyIDs.contains(aspect.transitBodyID) && visibleBodyIDs.contains(aspect.natalBodyID)
        }
        func visibleDeclinationBody(_ bodyID: String) -> Bool {
            let normalized = bodyID
                .replacingOccurrences(of: "natal_", with: "")
                .replacingOccurrences(of: "transit_", with: "")
            return visibleBodyIDs.contains(normalized)
        }

        return TransitResult(
            meta: result.meta,
            natalPositions: filteredNatalPositions,
            transitPositions: filteredTransitPositions,
            angles: result.angles,
            houses: result.houses,
            lots: result.lots,
            aspects: filteredAspects,
            declinationAspects: result.declinationAspects?.filter {
                visibleDeclinationBody($0.body1) && visibleDeclinationBody($0.body2)
            },
            natalStarConjunctions: result.natalStarConjunctions?.filter { visibleBodyIDs.contains($0.planet) },
            transitStarConjunctions: result.transitStarConjunctions?.filter { visibleBodyIDs.contains($0.planet) },
            warnings: result.warnings,
            patterns: result.patterns,
            chartProfile: result.chartProfile
        )
    }
    func resolvedScanTargetText() -> String {
        targetSource == "natal" ? buildNatalTargetText(includeAll: false) : scanTargetsText
    }

    func buildNatalTargetText(includeAll: Bool) -> String {
        guard hasNatalSourceForCurrentMode else {
            return ""
        }

        var lines: [String] = []
        for planet in targetPlanetOptions {
            if includeAll || selectedTargetPlanets.contains(planet.id) {
                lines.append("Natal \(planet.name) = \(englishPosition(longitude: planet.longitude))")
            }
        }
        for asteroid in targetAsteroidOptions {
            if includeAll || selectedTargetAsteroids.contains(asteroid.id) {
                lines.append("Natal \(asteroid.name) = \(englishPosition(longitude: asteroid.longitude))")
            }
        }
        for point in targetVirtualAndAngleOptions {
            if includeAll || selectedTargetAngles.contains(point.id) {
                lines.append("Natal \(point.name) = \(englishPosition(longitude: point.longitude))")
            }
        }
        for house in targetHouseOptions {
            if includeAll || selectedTargetHouses.contains(house.house) {
                lines.append("House Cusp \(ordinal(house.house)) = \(englishPosition(longitude: house.cuspLongitude))")
            }
        }
        for lot in targetLotOptions {
            if includeAll || selectedTargetLots.contains(lot.id) {
                lines.append("Lot of \(lot.name) = \(englishPosition(longitude: lot.longitude))")
            }
        }
        let customLots = customLotTargetsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !customLots.isEmpty {
            lines.append(customLots)
        }
        return lines.joined(separator: "\n")
    }

    func englishPosition(longitude: Double) -> String {
        let signs = [
            "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
            "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"
        ]
        let normalized = longitude.truncatingRemainder(dividingBy: 360) >= 0
            ? longitude.truncatingRemainder(dividingBy: 360)
            : longitude.truncatingRemainder(dividingBy: 360) + 360
        let signIndex = min(Int(normalized / 30), 11)
        let degreeInSign = normalized - Double(signIndex * 30)
        var degree = Int(degreeInSign)
        let minuteFloat = (degreeInSign - Double(degree)) * 60
        var minute = Int(minuteFloat)
        var second = Int(round((minuteFloat - Double(minute)) * 60))
        if second == 60 {
            second = 0
            minute += 1
        }
        if minute == 60 {
            minute = 0
            degree += 1
        }
        return String(format: "%@ %02d°%02d'%02d\"", signs[signIndex], degree, minute, second)
    }

func ordinal(_ value: Int) -> String {
        let suffix: String
        if (11...13).contains(value % 100) {
            suffix = "th"
        } else {
            switch value % 10 {
            case 1:
                suffix = "st"
            case 2:
                suffix = "nd"
            case 3:
                suffix = "rd"
            default:
                suffix = "th"
            }
        }
    return "\(value)\(suffix)"
}
}
