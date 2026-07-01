import Foundation

struct TransitResult: Codable {
    let meta: ResultMeta
    let natalPositions: [PositionRow]
    let transitPositions: [PositionRow]
    let angles: [ClassicalPoint]?
    let houses: [HouseRow]?
    let lots: [ClassicalPoint]?
    let aspects: [AspectHit]
    let declinationAspects: [DeclinationAspect]?
    let natalStarConjunctions: [FixedStarConjunction]?
    let transitStarConjunctions: [FixedStarConjunction]?
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case meta
        case natalPositions = "natal_positions"
        case transitPositions = "transit_positions"
        case angles
        case houses
        case lots
        case aspects
        case declinationAspects = "declination_aspects"
        case natalStarConjunctions = "natal_star_conjunctions"
        case transitStarConjunctions = "transit_star_conjunctions"
        case warnings
    }
}

struct ResultMeta: Codable {
    let natalUTC: String
    let transitUTC: String
    let ephemeris: String

    enum CodingKeys: String, CodingKey {
        case natalUTC = "natal_utc"
        case transitUTC = "transit_utc"
        case ephemeris
    }
}

struct PositionRow: Codable, Identifiable {
    let bodyID: String
    let name: String
    let longitude: Double
    let latitude: Double
    let declination: Double?
    let outOfBounds: Bool?
    let speed: Double
    let sign: String
    let degreeText: String
    let house: Int?

    var id: String { bodyID }

    enum CodingKeys: String, CodingKey {
        case bodyID = "body_id"
        case name
        case longitude
        case latitude
        case declination
        case outOfBounds = "out_of_bounds"
        case speed
        case sign
        case degreeText = "degree_text"
        case house
    }
}

struct AspectHit: Codable, Identifiable {
    let id: String
    let transitBodyID: String
    let transitBodyName: String
    let natalBodyID: String
    let natalBodyName: String
    let aspectID: String
    let aspectName: String
    let angle: Double
    let separation: Double
    let orb: Double

    enum CodingKeys: String, CodingKey {
        case id
        case transitBodyID = "transit_body_id"
        case transitBodyName = "transit_body_name"
        case natalBodyID = "natal_body_id"
        case natalBodyName = "natal_body_name"
        case aspectID = "aspect_id"
        case aspectName = "aspect_name"
        case angle
        case separation
        case orb
    }
}

struct DeclinationAspect: Codable {
    let body1: String
    let body2: String
    let type: String        // "parallel" or "contraparallel"
    let diff: Double
    let declination1: Double?
    let declination2: Double?

    enum CodingKeys: String, CodingKey {
        case body1
        case body2
        case type
        case diff
        case declination1
        case declination2
    }
}

struct FixedStarConjunction: Codable {
    let planet: String
    let star: String
    let starMag: Double
    let starNature: String
    let starKeyword: String
    let orb: Double

    enum CodingKeys: String, CodingKey {
        case planet
        case star
        case starMag = "star_mag"
        case starNature = "star_nature"
        case starKeyword = "star_keyword"
        case orb
    }
}

struct ScanResult: Codable {
    let meta: ScanMeta
    let hits: [ScanHit]
    let warnings: [String]
}

struct ScanMeta: Codable {
    let label: String
    let scanKind: String
    let startUTC: String
    let endUTC: String
    let ephemeris: String
    let targetCount: Int

    enum CodingKeys: String, CodingKey {
        case label
        case scanKind = "scan_kind"
        case startUTC = "start_utc"
        case endUTC = "end_utc"
        case ephemeris
        case targetCount = "target_count"
    }
}

struct ScanHit: Codable, Identifiable {
    let id: String
    let window: String
    let dateTimeLocal: String
    let transitBodyID: String
    let transitBodyName: String
    let aspectID: String
    let aspectName: String
    let aspectAngle: Double?
    let targetName: String
    let targetLongitude: Double
    let targetPosition: String?
    let transitLongitude: Double
    let transitPosition: String
    let exactTransitPosition: String?
    let exactLongitude: Double
    let orb: Double?
    let phase: String?
    let scanStep: String?
    let exactMethod: String?
    let maxOrb: Double?
    let priorityScore: Int?
    let priorityGrade: String?

    var priorityGradeSortValue: String { priorityGrade ?? "" }

    enum CodingKeys: String, CodingKey {
        case id
        case window
        case dateTimeLocal = "date_time_local"
        case transitBodyID = "transit_body_id"
        case transitBodyName = "transit_body_name"
        case aspectID = "aspect_id"
        case aspectName = "aspect_name"
        case aspectAngle = "aspect_angle"
        case targetName = "target_name"
        case targetLongitude = "target_longitude"
        case targetPosition = "target_position"
        case transitLongitude = "transit_longitude"
        case transitPosition = "transit_position"
        case exactTransitPosition = "exact_transit_position"
        case exactLongitude = "exact_longitude"
        case orb
        case phase
        case scanStep = "scan_step"
        case exactMethod = "exact_method"
        case maxOrb = "max_orb"
        case priorityScore = "priority_score"
        case priorityGrade = "priority_grade"
    }
}
