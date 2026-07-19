import Foundation

struct MundaneElectionalMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let ephemeris: String?
    let ingressCount: Int?
    let candidateCount: Int?
    let displayTimezone: String?
    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris
        case schemaVersion = "schema_version"
        case ingressCount = "ingress_count"
        case candidateCount = "candidate_count"
        case displayTimezone = "display_timezone"
    }
}

struct MundaneIngressRow: Codable, Identifiable {
    let ingress: String?
    let targetLongitude: Double?
    let exactUtc: String?
    let exactLocal: String?
    let exactOrb: Double?
    let houseSystem: String?
    let methodKey: String?
    let planets: NestedJSON?
    let angles: NestedJSON?
    var id: String { "\(ingress ?? "")|\(exactUtc ?? "")" }
    enum CodingKeys: String, CodingKey {
        case ingress, planets, angles
        case targetLongitude = "target_longitude"
        case exactUtc = "exact_utc"
        case exactLocal = "exact_local"
        case exactOrb = "exact_orb"
        case houseSystem = "house_system"
        case methodKey = "method_key"
    }
}

struct ElectionalMoonAspect: Codable, Hashable {
    let bodyId: String?
    let separationDeg: Double?
    enum CodingKeys: String, CodingKey {
        case bodyId = "body_id"
        case separationDeg = "separation_deg"
    }
}

struct ElectionalCandidateRow: Codable, Identifiable {
    let candidateUtc: String?
    let candidateLocal: String?
    let moonLongitude: Double?
    let moonSpeed: Double?
    let moonSignExitDistance: Double?
    let sunMoonSeparation: Double?
    let nearestMoonAspects: [ElectionalMoonAspect]?
    let ascLongitude: Double?
    let topicHouse: Int?
    let planetaryHour: NestedJSON?
    let planetaryHoursStatus: String?
    let methodKey: String?
    let note: String?
    var id: String { candidateUtc ?? UUID().uuidString }
    enum CodingKeys: String, CodingKey {
        case note
        case candidateUtc = "candidate_utc"
        case candidateLocal = "candidate_local"
        case moonLongitude = "moon_longitude"
        case moonSpeed = "moon_speed"
        case moonSignExitDistance = "moon_sign_exit_distance"
        case sunMoonSeparation = "sun_moon_separation"
        case nearestMoonAspects = "nearest_moon_aspects"
        case ascLongitude = "asc_longitude"
        case topicHouse = "topic_house"
        case planetaryHour = "planetary_hour"
        case planetaryHoursStatus = "planetary_hours_status"
        case methodKey = "method_key"
    }
}

struct MundaneElectionalResult: Codable {
    let meta: MundaneElectionalMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let mundaneIngresses: [MundaneIngressRow]
    let electionalCandidates: [ElectionalCandidateRow]
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, warnings
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case mundaneIngresses = "mundane_ingresses"
        case electionalCandidates = "electional_candidates"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
