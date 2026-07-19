import Foundation

struct PrenatalParansMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let ephemeris: String?
    let paranCount: Int?
    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris
        case schemaVersion = "schema_version"
        case paranCount = "paran_count"
    }
}

struct FixedStarParanRow: Codable, Identifiable {
    let planetId: String?
    let planetName: String?
    let starName: String?
    let planetRa: Double?
    let starRa: Double?
    let raDeltaDeg: Double?
    let paranClass: String?
    let methodKey: String?
    let note: String?
    var id: String { "\(planetId ?? "")|\(starName ?? "")|\(raDeltaDeg.map { String($0) } ?? "")" }
    enum CodingKeys: String, CodingKey {
        case note
        case planetId = "planet_id"
        case planetName = "planet_name"
        case starName = "star_name"
        case planetRa = "planet_ra"
        case starRa = "star_ra"
        case raDeltaDeg = "ra_delta_deg"
        case paranClass = "paran_class"
        case methodKey = "method_key"
    }
}

struct PrenatalParansResult: Codable {
    let meta: PrenatalParansMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let prenatalPacket: NestedJSON?
    let fixedStarParans: [FixedStarParanRow]
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, warnings
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case prenatalPacket = "prenatal_packet"
        case fixedStarParans = "fixed_star_parans"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
