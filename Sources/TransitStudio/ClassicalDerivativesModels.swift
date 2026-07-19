import Foundation

struct ClassicalDerivativesMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let ephemeris: String?
    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris
        case schemaVersion = "schema_version"
    }
}

struct ClassicalDerivativesResult: Codable {
    let meta: ClassicalDerivativesMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, warnings
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
