import Foundation

struct ClassicalPoint: Codable, Identifiable {
    let id: String
    let name: String
    let longitude: Double
    let sign: String
    let degreeText: String
    let house: Int
    let ruler: String
    let formula: String?
    let formulaDay: String?
    let formulaNight: String?
    let usedFormula: String?
    let confidence: String?
    let lotGroup: String?
    let sourceTradition: String?
    let methodVariant: String?
    let formulaNotes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case longitude
        case sign
        case degreeText = "degree_text"
        case house
        case ruler
        case formula
        case formulaDay = "formula_day"
        case formulaNight = "formula_night"
        case usedFormula = "used_formula"
        case confidence
        case lotGroup = "lot_group"
        case sourceTradition = "source_tradition"
        case methodVariant = "method_variant"
        case formulaNotes = "formula_notes"
    }
}

struct HouseRow: Codable, Identifiable {
    let house: Int
    let sign: String
    let cuspLongitude: Double
    let cuspText: String
    let ruler: String

    var id: Int { house }

    enum CodingKeys: String, CodingKey {
        case house
        case sign
        case cuspLongitude = "cusp_longitude"
        case cuspText = "cusp_text"
        case ruler
    }
}

struct ClassicalPlanetRow: Codable, Identifiable {
    let id: String
    let name: String
    let longitude: Double
    let sign: String
    let degreeText: String
    let house: Int
    let speed: Double
    let motion: String
    let sectStatus: String
    let domicile: String
    let detriment: String?
    let exaltation: String
    let fall: String?
    let triplicity: String
    let triplicityDetails: [TriplicityRulerDetail]?
    let bound: String
    let decan: String
    let solarPhase: String
    let solarCondition: String?
    let sunDistanceDeg: Double?
    let accidental: String
    let hayz: String?
    let joy: String?
    let planetaryYears: Int?
    let score: Int
    let scoreLabel: String?
    let notes: [String]?
    let scoreBreakdown: [ScoreBreakdownItem]
    let bonification: [ConditioningModifier]
    let maltreatment: [ConditioningModifier]
    let dodekatemorionLongitude: Double?
    let dodekatemorionRuler: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case longitude
        case sign
        case degreeText = "degree_text"
        case house
        case speed
        case motion
        case sectStatus = "sect_status"
        case domicile
        case detriment
        case exaltation
        case fall
        case triplicity
        case triplicityDetails = "triplicity_details"
        case bound
        case decan
        case solarPhase = "solar_phase"
        case solarCondition = "solar_condition"
        case sunDistanceDeg = "sun_distance_deg"
        case accidental
        case hayz
        case joy
        case planetaryYears = "planetary_years"
        case score
        case scoreLabel = "score_label"
        case notes
        case scoreBreakdown = "score_breakdown"
        case bonification
        case maltreatment
        case dodekatemorionLongitude = "dodekatemorion_longitude"
        case dodekatemorionRuler = "dodekatemorion_ruler"
    }
}

struct ClassicalAspectRow: Codable, Identifiable {
    let id: String
    let bodyA: String
    let bodyB: String
    let aspect: String
    let aspectType: String
    let aspectGeometry: String?
    let aspectKind: String?
    let orb: Double?
    let applying: String?

    enum CodingKeys: String, CodingKey {
        case id
        case bodyA = "body_a"
        case bodyB = "body_b"
        case aspect
        case aspectType = "aspect_type"
        case aspectGeometry = "aspect_geometry"
        case aspectKind = "aspect_kind"
        case orb
        case applying
    }
}

struct ReceptionRow: Codable, Identifiable {
    let id: String
    let receiver: String
    let received: String
    let dignity: String
    let viaAspect: String
    let aspectGeometry: String?
    let aspectOrb: Double?
    let strengthScore: Int?
    let strengthLabel: String?

    enum CodingKeys: String, CodingKey {
        case id
        case receiver
        case received
        case dignity
        case viaAspect = "via_aspect"
        case aspectGeometry = "aspect_geometry"
        case aspectOrb = "aspect_orb"
        case strengthScore = "strength_score"
        case strengthLabel = "strength_label"
    }
}

struct ScoreBreakdownItem: Codable, Identifiable {
    let label: String
    let score: Int
    let value: String

    var id: String { "\(label):\(value):\(score)" }
}

struct TriplicityRulerDetail: Codable, Identifiable {
    let role: String
    let label: String
    let ruler: String
    let rulerId: String
    let score: Int
    let status: String
    let notes: [String]

    var id: String { "\(role):\(rulerId):\(label)" }

    enum CodingKeys: String, CodingKey {
        case role
        case label
        case ruler
        case rulerId = "ruler_id"
        case score
        case status
        case notes
    }
}

struct ConditioningModifier: Codable, Identifiable {
    let source: String
    let aspect: String
    let orb: Double?
    let applying: String?
    let strengthScore: Int
    let strengthLabel: String
    let aspectGeometry: String?
    let scoreDelta: Int?
    let beneficCondition: String?
    let strengthModifier: Double?
    let baseDelta: Int?

    var id: String {
        "\(source):\(aspect):\(orb ?? -1):\(strengthScore):\(strengthLabel)"
    }

    enum CodingKeys: String, CodingKey {
        case source
        case aspect
        case orb
        case applying
        case strengthScore = "strength_score"
        case strengthLabel = "strength_label"
        case aspectGeometry = "aspect_geometry"
        case scoreDelta = "score_delta"
        case beneficCondition = "benefic_condition"
        case strengthModifier = "strength_modifier"
        case baseDelta = "base_delta"
    }
}
