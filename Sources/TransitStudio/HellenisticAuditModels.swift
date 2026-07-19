import Foundation

struct HellenisticConditionAuditRequest: Codable {
    let mode: String
    let birth: BirthSettings
    let aspectOrb: Double
    let sourceProfile: String?
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "hellenistic_condition_audit",
        birth: BirthSettings,
        aspectOrb: Double = 3.0,
        sourceProfile: String? = nil,
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.birth = birth
        self.aspectOrb = aspectOrb
        self.sourceProfile = sourceProfile
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode, birth
        case aspectOrb = "aspect_orb"
        case sourceProfile = "source_profile"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

struct HellenisticConditionRow: Codable, Identifiable {
    let conditionID: String
    let subject: String
    let actors: [String]?
    let geometry: String?
    let applyingSeparating: String?
    let orb: Double?
    let sourceProfile: String?
    let evidence: [String]?
    let methodKey: String?
    let value: String?

    var id: String { "\(conditionID)|\(subject)|\(geometry ?? "")|\(actors?.joined() ?? "")" }

    enum CodingKeys: String, CodingKey {
        case subject, geometry, orb, evidence, value
        case conditionID = "condition_id"
        case actors
        case applyingSeparating = "applying_separating"
        case sourceProfile = "source_profile"
        case methodKey = "method_key"
    }
}

struct HellenisticConditionAuditMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let sourceProfile: String?
    let birthUTC: String?
    let isDay: Bool?
    let conditionCount: Int?
    let ephemeris: String?

    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris
        case schemaVersion = "schema_version"
        case sourceProfile = "source_profile"
        case birthUTC = "birth_utc"
        case isDay = "is_day"
        case conditionCount = "condition_count"
    }
}

struct HellenisticConditionAuditResult: Codable {
    let meta: HellenisticConditionAuditMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let conditions: [HellenisticConditionRow]
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, conditions, warnings
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
