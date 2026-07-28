import Foundation

struct AntisciaRow: Codable, Identifiable {
    let id: String
    let planet: String
    let planetId: String
    let longitude: Double
    let antisciaLongitude: Double
    let contraLongitude: Double
    let antisciaSign: String
    let antisciaDegree: String
    let contraSign: String
    let contraDegree: String
    let natalHits: [AntisciaHit]
    let orbThreshold: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case planet
        case planetId = "planet_id"
        case longitude
        case antisciaLongitude = "antiscia_longitude"
        case contraLongitude = "contra_longitude"
        case antisciaSign = "antiscia_sign"
        case antisciaDegree = "antiscia_degree"
        case contraSign = "contra_sign"
        case contraDegree = "contra_degree"
        case natalHits = "natal_hits"
        case orbThreshold = "orb_threshold"
    }
}

struct AntisciaHit: Codable, Identifiable {
    let id: String
    let hitPlanet: String
    let via: String
    let orb: Double

    enum CodingKeys: String, CodingKey {
        case id
        case hitPlanet = "hit_planet"
        case via
        case orb
    }
}

struct Circumambulation: Codable, Identifiable {
    let id: String
    let system: String
    let startLon: Double
    let currentRuler: String
    let currentRulerId: String
    let currentBoundInfo: String?
    let currentDirectedPosition: Double?
    let boundLord: String?
    let boundLordId: String?
    let boundSign: String?
    let boundStartDegree: Double?
    let boundEndDegree: Double?
    let boundStartDate: String?
    let boundEndDate: String?
    let naibodRate: Double
    let boundaries: [CircumambulationBoundary]

    enum CodingKeys: String, CodingKey {
        case id
        case system
        case startLon = "start_lon"
        case currentRuler = "current_ruler"
        case currentRulerId = "current_ruler_id"
        case currentBoundInfo = "current_bound_info"
        case currentDirectedPosition = "current_directed_position"
        case boundLord = "bound_lord"
        case boundLordId = "bound_lord_id"
        case boundSign = "bound_sign"
        case boundStartDegree = "bound_start_degree"
        case boundEndDegree = "bound_end_degree"
        case boundStartDate = "bound_start_date"
        case boundEndDate = "bound_end_date"
        case naibodRate = "naibod_rate"
        case boundaries
    }
}

struct CircumambulationBoundary: Codable, Identifiable {
    let sign: String
    let startDegree: Double?
    let endDegree: Double
    let ruler: String
    let rulerId: String
    let arcValue: Double
    let ageAtBoundary: Double
    let estimatedDate: String
    let isCurrent: Bool?

    var id: String { "\(sign):\(endDegree):\(ruler):\(ageAtBoundary)" }

    enum CodingKeys: String, CodingKey {
        case sign
        case startDegree = "start_degree"
        case endDegree = "end_degree"
        case ruler
        case rulerId = "ruler_id"
        case arcValue = "arc_value"
        case ageAtBoundary = "age_at_boundary"
        case estimatedDate = "estimated_date"
        case isCurrent = "is_current"
    }
}

func classicalBoundDegreeText(_ value: Double) -> String {
    String(format: "%g", value)
}

struct PrimaryDirection: Codable, Identifiable {
    let id: String
    let promissor: String
    let promissorId: String
    let significator: String
    let significatorId: String
    let aspectType: String
    let aspectName: String
    let natalPromissorLon: Double
    let natalSignificatorLon: Double
    let directionType: String?
    let arcSigned: Double?
    let arcAbs: Double?
    let ageFromAbsArc: Double
    let eventDateAfterBirth: String?
    let symbolicDateFromSignedArc: String?

    enum CodingKeys: String, CodingKey {
        case id
        case promissor
        case promissorId = "promissor_id"
        case significator
        case significatorId = "significator_id"
        case aspectType = "aspect_type"
        case aspectName = "aspect_name"
        case natalPromissorLon = "natal_promissor_lon"
        case natalSignificatorLon = "natal_significator_lon"
        case directionType = "direction_type"
        case arcSigned = "arc_signed"
        case arcAbs = "arc_abs"
        case ageFromAbsArc = "age_from_abs_arc"
        case eventDateAfterBirth = "event_date_after_birth"
        case symbolicDateFromSignedArc = "symbolic_date_from_signed_arc"
    }
}
