import Foundation

struct TimeLordsExtendedMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let ephemeris: String?
    let age: Int?
    let fortuneLongitude: Double?
    let spiritLongitude: Double?
    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris, age
        case schemaVersion = "schema_version"
        case fortuneLongitude = "fortune_longitude"
        case spiritLongitude = "spirit_longitude"
    }
}

struct ConcordanceRow: Codable, Identifiable {
    let bodyId: String
    let bodyName: String?
    let techniques: [String]
    let count: Int?
    var id: String { bodyId }
    enum CodingKeys: String, CodingKey {
        case techniques, count
        case bodyId = "body_id"
        case bodyName = "body_name"
    }
}

struct DailyProfectionRow: Codable {
    let activatedSignIndex: Int?
    let activatedSign: String?
    let lord: String?
    let lordId: String?
    let methodKey: String?
    let note: String?
    enum CodingKeys: String, CodingKey {
        case lord, note
        case activatedSignIndex = "activated_sign_index"
        case activatedSign = "activated_sign"
        case lordId = "lord_id"
        case methodKey = "method_key"
    }
}

struct TimeLordsExtendedResult: Codable {
    let meta: TimeLordsExtendedMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let profection: NestedJSON?
    let dailyProfection: DailyProfectionRow?
    let zodiacalReleasing: NestedJSON?
    let firdaria: NestedJSON?
    let decennials: NestedJSON?
    let revolutionsConcordance: [ConcordanceRow]
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, warnings, profection, firdaria, decennials
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case dailyProfection = "daily_profection"
        case zodiacalReleasing = "zodiacal_releasing"
        case revolutionsConcordance = "revolutions_concordance"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
