import Foundation

public struct DialValue: Codable, Hashable, Sendable {
    public let modulus: Double
    public let longitude: Double

    public init(modulus: Double, longitude: Double) {
        self.modulus = modulus
        self.longitude = longitude
    }

    enum CodingKeys: String, CodingKey {
        case modulus, longitude
    }
}

public struct ReportLocation: Codable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let timezone: String?
    public let backendHouseSystem: String?

    public init(location: ChartLocation?) {
        self.latitude = location?.latitude ?? 0
        self.longitude = location?.longitude ?? 0
        self.timezone = location?.timezone
        self.backendHouseSystem = location?.backendHouseSystem
    }

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, timezone
        case backendHouseSystem = "backend_house_system"
    }
}

public struct ReportMeta: Codable, Sendable {
    public let engine: String
    public let version: String
    public let method: String
    public let julianDayUT: Double
    public let momentUTC: String?
    public let referenceUTC: String?
    public let location: ReportLocation?
    public let dialModulus: Double
    public let orbUnit: String
    public let midpointOrb: Double
    public let pictureOrb: Double
    public let pointCount: Int
    public let tnpModel: String
    public let ephemeris: String

    enum CodingKeys: String, CodingKey {
        case engine, version, method, location, ephemeris
        case julianDayUT = "julian_day_ut"
        case momentUTC = "moment_utc"
        case referenceUTC = "reference_utc"
        case dialModulus = "dial_modulus"
        case orbUnit = "orb_unit"
        case midpointOrb = "midpoint_orb"
        case pictureOrb = "picture_orb"
        case pointCount = "point_count"
        case tnpModel = "tnp_model"
    }
}

public struct ReportPosition: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let nameLocal: String?
    public let kind: String
    public let longitude: Double
    public let latitude: Double?
    public let speed: Double?
    public let sign: String
    public let degreeText: String
    public let house: Int?
    public let dials: [DialValue]
    public let antiscion: Double?
    public let contraAntiscion: Double?
    public let source: String
    public let keywords: [String]
    public let keywordsZh: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, kind, longitude, latitude, speed, sign, house, dials
        case nameLocal = "name_local"
        case degreeText = "degree_text"
        case antiscion
        case contraAntiscion = "contra_antiscion"
        case source, keywords
        case keywordsZh = "keywords_zh"
    }
}

public struct HouseCusp: Codable, Identifiable, Sendable {
    public let house: Int
    public let longitude: Double
    public let sign: String
    public let degreeText: String

    public var id: Int { house }

    enum CodingKeys: String, CodingKey {
        case house, longitude, sign
        case degreeText = "degree_text"
    }
}

public struct HouseSet: Codable, Sendable {
    public let system: String
    public let cusps: [HouseCusp]
    public let backendSystem: String?
    public let backendCusps: [HouseCusp]?

    enum CodingKeys: String, CodingKey {
        case system, cusps
        case backendSystem = "backend_system"
        case backendCusps = "backend_cusps"
    }
}

public struct MidpointAxis: Codable, Identifiable, Sendable {
    public let id: String
    public let pointA: String
    public let pointB: String
    public let direct: Double
    public let opposite: Double
    public let dialDirect: Double
    public let dialOpposite: Double

    enum CodingKeys: String, CodingKey {
        case id, direct, opposite
        case pointA = "point_a"
        case pointB = "point_b"
        case dialDirect = "dial_direct"
        case dialOpposite = "dial_opposite"
    }
}

public struct MidpointHit: Codable, Identifiable, Sendable {
    public let id: String
    public let focus: String
    public let focusName: String
    public let axisID: String
    public let pointA: String
    public let pointB: String
    public let branch: String
    public let harmonic: Int
    public let axisLongitude: Double
    public let focusLongitude: Double
    public let orb: Double
    public let orbDial: Double
    public let formula: String

    enum CodingKeys: String, CodingKey {
        case id, focus, branch, harmonic, orb, formula
        case focusName = "focus_name"
        case axisID = "axis_id"
        case pointA = "point_a"
        case pointB = "point_b"
        case axisLongitude = "axis_longitude"
        case focusLongitude = "focus_longitude"
        case orbDial = "orb_dial"
    }
}

public struct MidpointTree: Codable, Identifiable, Sendable {
    public let focus: String
    public let focusName: String
    public let hits: [MidpointHit]

    public var id: String { focus }

    enum CodingKeys: String, CodingKey {
        case focus, hits
        case focusName = "focus_name"
    }
}

public struct PlanetaryPicture: Codable, Identifiable, Sendable {
    public let id: String
    public let formula: String
    public let left: [String]
    public let right: [String]
    public let leftSum: Double
    public let rightSum: Double
    public let dialLongitude: Double
    public let orb: Double
    public let orbDial: Double

    enum CodingKeys: String, CodingKey {
        case id, formula, left, right, orb
        case leftSum = "left_sum"
        case rightSum = "right_sum"
        case dialLongitude = "dial_longitude"
        case orbDial = "orb_dial"
    }
}

public struct DirectedPosition: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let longitude: Double
    public let sign: String
    public let degreeText: String
    public let dials: [DialValue]
    public let arc: Double
    public let direction: String

    enum CodingKeys: String, CodingKey {
        case id, name, longitude, sign, dials, arc, direction
        case degreeText = "degree_text"
    }
}

public struct SolarArcPointHit: Codable, Identifiable, Sendable {
    public let id: String
    public let directed: String
    public let natal: String
    public let directedLongitude: Double
    public let natalLongitude: Double
    public let orb: Double
    public let orbDial: Double
    public let formula: String
    public let direction: String

    enum CodingKeys: String, CodingKey {
        case id, directed, natal, orb, formula, direction
        case directedLongitude = "directed_longitude"
        case natalLongitude = "natal_longitude"
        case orbDial = "orb_dial"
    }
}

public struct SolarArcMidpointHit: Codable, Identifiable, Sendable {
    public let id: String
    public let directed: String
    public let axisID: String
    public let pointA: String
    public let pointB: String
    public let branch: String
    public let harmonic: Int
    public let directedLongitude: Double
    public let axisLongitude: Double
    public let orb: Double
    public let orbDial: Double
    public let formula: String
    public let direction: String

    enum CodingKeys: String, CodingKey {
        case id, directed, branch, harmonic, orb, formula, direction
        case axisID = "axis_id"
        case pointA = "point_a"
        case pointB = "point_b"
        case directedLongitude = "directed_longitude"
        case axisLongitude = "axis_longitude"
        case orbDial = "orb_dial"
    }
}

public struct SolarArcReport: Codable, Sendable {
    public let method: String
    public let ageYears: Double
    public let arcDegrees: Double
    public let converseArcDegrees: Double?
    public let directedPositions: [DirectedPosition]
    public let pointHits: [SolarArcPointHit]
    public let midpointHits: [SolarArcMidpointHit]

    enum CodingKeys: String, CodingKey {
        case method
        case ageYears = "age_years"
        case arcDegrees = "arc_degrees"
        case converseArcDegrees = "converse_arc_degrees"
        case directedPositions = "directed_positions"
        case pointHits = "point_hits"
        case midpointHits = "midpoint_hits"
    }
}

public struct AntisciaPointContact: Codable, Identifiable, Sendable {
    public let id: String
    public let source: String
    public let target: String
    public let type: String
    public let projectedLongitude: Double
    public let targetLongitude: Double
    public let orb: Double
    public let orbDial: Double
    public let formula: String

    enum CodingKeys: String, CodingKey {
        case id, source, target, type, orb, formula
        case projectedLongitude = "projected_longitude"
        case targetLongitude = "target_longitude"
        case orbDial = "orb_dial"
    }
}

public struct AntisciaMidpointContact: Codable, Identifiable, Sendable {
    public let id: String
    public let source: String
    public let axisID: String
    public let pointA: String
    public let pointB: String
    public let type: String
    public let branch: String
    public let harmonic: Int
    public let projectedLongitude: Double
    public let axisLongitude: Double
    public let orb: Double
    public let orbDial: Double
    public let formula: String

    enum CodingKeys: String, CodingKey {
        case id, source, type, branch, harmonic, orb, formula
        case axisID = "axis_id"
        case pointA = "point_a"
        case pointB = "point_b"
        case projectedLongitude = "projected_longitude"
        case axisLongitude = "axis_longitude"
        case orbDial = "orb_dial"
    }
}

public struct AntisciaReport: Codable, Sendable {
    public let pointContacts: [AntisciaPointContact]
    public let midpointContacts: [AntisciaMidpointContact]

    enum CodingKeys: String, CodingKey {
        case pointContacts = "point_contacts"
        case midpointContacts = "midpoint_contacts"
    }
}

public struct HamburgReport: Codable, Sendable {
    public let meta: ReportMeta
    public let positions: [ReportPosition]
    public let houses: HouseSet
    public let midpoints: [MidpointAxis]
    public let trees: [MidpointTree]
    public let pictures: [PlanetaryPicture]
    public let solarArc: SolarArcReport?
    public let antiscia: AntisciaReport?
    public let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case meta, positions, houses, midpoints, trees, pictures, antiscia, warnings
        case solarArc = "solar_arc"
    }
}

public enum HamburgCoreVersion {
    public static let version = "0.1.0"
    public static let method = "hamburg_uranian_v1"
    public static let engine = "HamburgCore"
}
