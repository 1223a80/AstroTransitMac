import Foundation

struct MethodFamiliesMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let ephemeris: String?
    let ageYears: Double?
    let trueSolarArcDeg: Double?
    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris
        case schemaVersion = "schema_version"
        case ageYears = "age_years"
        case trueSolarArcDeg = "true_solar_arc_deg"
    }
}

struct MethodFamilyBodyRow: Codable, Identifiable {
    let bodyId: String
    let name: String?
    let natalLongitude: Double?
    let progressedLongitude: Double?
    let solarArcLongitude: Double?
    let arcDeg: Double?
    let methodKey: String?
    let component: String?
    var id: String { "\(bodyId)|\(methodKey ?? "")|\(progressedLongitude.map { String($0) } ?? solarArcLongitude.map { String($0) } ?? "")" }
    enum CodingKeys: String, CodingKey {
        case name, component
        case bodyId = "body_id"
        case natalLongitude = "natal_longitude"
        case progressedLongitude = "progressed_longitude"
        case solarArcLongitude = "solar_arc_longitude"
        case arcDeg = "arc_deg"
        case methodKey = "method_key"
    }
}

struct ProgressionProfilePack: Codable, Identifiable {
    let profileId: String
    let description: String?
    let progressedUtc: String?
    let rows: [MethodFamilyBodyRow]
    var id: String { profileId }
    enum CodingKeys: String, CodingKey {
        case description, rows
        case profileId = "profile_id"
        case progressedUtc = "progressed_utc"
    }
}

struct SolarArcProfilePack: Codable, Identifiable {
    let profileId: String
    let description: String?
    let arcDeg: Double?
    let rows: [MethodFamilyBodyRow]
    var id: String { profileId }
    enum CodingKeys: String, CodingKey {
        case description, rows
        case profileId = "profile_id"
        case arcDeg = "arc_deg"
    }
}

struct MethodFamiliesResult: Codable {
    let meta: MethodFamiliesMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let progressionProfiles: [ProgressionProfilePack]
    let solarArcProfiles: [SolarArcProfilePack]
    let profileArcComparison: [String: Double]?
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, warnings
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case progressionProfiles = "progression_profiles"
        case solarArcProfiles = "solar_arc_profiles"
        case profileArcComparison = "profile_arc_comparison"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
