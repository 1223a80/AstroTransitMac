import Foundation
import HamburgCore

struct CLILocation: Decodable {
    let latitude: Double?
    let longitude: Double?
    let timezone: String?
    let houseSystem: String?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, timezone
        case houseSystem = "house_system"
    }
}

struct CLIPoint: Decodable {
    let id: String
    let name: String?
    let nameLocal: String?
    let kind: String?
    let longitude: Double
    let latitude: Double?
    let speed: Double?
    let keywords: [String]?
    let keywordsZh: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, kind, longitude, latitude, speed, keywords
        case nameLocal = "name_local"
        case keywordsZh = "keywords_zh"
    }

    func chartPoint() -> ChartPoint {
        let normalizedKind = kind?.lowercased()
        let resolvedKind: ChartPoint.Kind
        switch normalizedKind {
        case "planet": resolvedKind = .planet
        case "transneptunian", "tnp": resolvedKind = .transneptunian
        case "angle": resolvedKind = .angle
        case "node": resolvedKind = .node
        case "axis": resolvedKind = .axis
        case "lot": resolvedKind = .lot
        default:
            if id.uppercased().contains("NODE") {
                resolvedKind = .node
            } else if ["ASC", "MC", "DSC", "IC"].contains(id.uppercased()) {
                resolvedKind = .angle
            } else if UranianPlanet(rawValue: id.uppercased()) != nil {
                resolvedKind = .transneptunian
            } else {
                resolvedKind = .custom
            }
        }
        return ChartPoint(
            id: id,
            name: name,
            nameLocal: nameLocal,
            kind: resolvedKind,
            longitude: longitude,
            latitude: latitude,
            speed: speed,
            source: .user,
            keywords: keywords ?? [],
            keywordsZh: keywordsZh ?? []
        )
    }
}

struct CLIRequest: Decodable {
    let moment: Moment?
    let location: CLILocation?
    let reference: Moment?
    let points: [CLIPoint]?
    let angles: [CLIPoint]?
    let houses: [Double]?
    let julianDayUT: Double?
    let referenceJulianDayUT: Double?
    let options: HamburgOptions?
    let bodyIDs: [String]?
    let includeNodes: Bool?
    let houseAssignment: HouseAssignment?
    let zodiac: String?

    enum CodingKeys: String, CodingKey {
        case moment, location, reference, points, angles, houses, options, zodiac
        case julianDayUT = "julian_day_ut"
        case referenceJulianDayUT = "reference_julian_day_ut"
        case bodyIDs = "body_ids"
        case includeNodes = "include_nodes"
        case houseAssignment = "house_assignment"
    }

    var effectiveLocation: ChartLocation? {
        guard let location else { return nil }
        return ChartLocation(
            latitude: location.latitude ?? 0,
            longitude: location.longitude ?? 0,
            timezone: location.timezone ?? moment?.timezone,
            backendHouseSystem: backendHouseSystem
        )
    }

    /// The Python backend has no "hamburg" house system. Hamburg houses are
    /// assigned natively; Placidus is only requested so ASC/MC and a reference
    /// cusp set are available.
    var backendHouseSystem: String {
        let requested = location?.houseSystem ?? "placidus"
        return requested == "hamburg" ? "placidus" : requested
    }

    var effectiveBodyIDs: [String] {
        if let bodyIDs, !bodyIDs.isEmpty {
            return bodyIDs.map { $0.uppercased() }
        }
        var ids = [
            "SUN", "MOON", "MERCURY", "VENUS", "MARS",
            "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
        ]
        if includeNodes ?? true {
            ids.append("TRUE_NODE")
        }
        return ids
    }
}
