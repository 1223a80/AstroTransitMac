import Foundation

struct DistributionsPdMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let ephemeris: String?
    let baselineAlgorithm: String?
    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris
        case schemaVersion = "schema_version"
        case baselineAlgorithm = "baseline_algorithm"
    }
}

struct DistributionPacketRow: Codable, Identifiable {
    let significator: String?
    let significatorLongitude: Double?
    let boundsSystem: String?
    let methodKey: String?
    let packet: NestedJSON?
    var id: String { "\(significator ?? "")|\(boundsSystem ?? "")|\(methodKey ?? "")" }
    enum CodingKeys: String, CodingKey {
        case significator, packet
        case significatorLongitude = "significator_longitude"
        case boundsSystem = "bounds_system"
        case methodKey = "method_key"
    }
}

struct ProfilePDDirectionRow: Codable, Identifiable {
    let directionId: String
    let promissor: String?
    let promissorId: String?
    let significator: String?
    let significatorId: String?
    let aspectType: String?
    let directionType: String?
    let arcSigned: Double?
    let ageFromAbsArc: Double?
    let methodProfile: String?
    let methodKey: String?
    let key: String?
    let keyRateDegPerYear: Double?
    var id: String { "\(methodProfile ?? methodKey ?? "")|\(directionId)" }
    enum CodingKeys: String, CodingKey {
        case promissor, significator, key
        case directionId = "id"
        case promissorId = "promissor_id"
        case significatorId = "significator_id"
        case aspectType = "aspect_type"
        case directionType = "direction_type"
        case arcSigned = "arc_signed"
        case ageFromAbsArc = "age_from_abs_arc"
        case methodProfile = "method_profile"
        case methodKey = "method_key"
        case keyRateDegPerYear = "key_rate_deg_per_year"
    }
}

struct DistributionsPdResult: Codable {
    let meta: DistributionsPdMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let distributions: [DistributionPacketRow]
    let primaryDirectionsByProfile: [ProfilePDDirectionRow]
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, warnings, distributions
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case primaryDirectionsByProfile = "primary_directions_by_profile"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
