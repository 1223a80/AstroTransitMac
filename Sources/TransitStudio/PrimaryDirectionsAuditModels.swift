import Foundation

struct PrimaryDirectionsAuditMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let ephemeris: String?
    let algorithmName: String?
    let directionCount: Int?
    let naibodRate: Double?
    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris
        case schemaVersion = "schema_version"
        case algorithmName = "algorithm_name"
        case directionCount = "direction_count"
        case naibodRate = "naibod_rate"
    }
}

struct PDDirectionRow: Codable, Identifiable {
    let id: String
    let promissor: String?
    let promissorId: String?
    let significator: String?
    let significatorId: String?
    let aspectType: String?
    let aspectName: String?
    let directionType: String?
    let arcSigned: Double?
    let arcAbs: Double?
    let ageFromAbsArc: Double?
    let algorithmName: String?
    let methodKey: String?
    let key: String?
    enum CodingKeys: String, CodingKey {
        case id, promissor, significator, key
        case promissorId = "promissor_id"
        case significatorId = "significator_id"
        case aspectType = "aspect_type"
        case aspectName = "aspect_name"
        case directionType = "direction_type"
        case arcSigned = "arc_signed"
        case arcAbs = "arc_abs"
        case ageFromAbsArc = "age_from_abs_arc"
        case algorithmName = "algorithm_name"
        case methodKey = "method_key"
    }
}

struct PrimaryDirectionsAuditResult: Codable {
    let meta: PrimaryDirectionsAuditMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let algorithmDescription: NestedJSON?
    let directions: [PDDirectionRow]
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, warnings, directions
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case algorithmDescription = "algorithm_description"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
