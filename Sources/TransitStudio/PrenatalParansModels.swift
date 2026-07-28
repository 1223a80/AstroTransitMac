import Foundation

struct PrenatalParansMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let ephemeris: String?
    let paranCount: Int?
    let legacyParanCount: Int?
    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris
        case schemaVersion = "schema_version"
        case paranCount = "paran_count"
        case legacyParanCount = "legacy_paran_count"
    }
}

struct FixedStarParanRow: Codable, Identifiable {
    let planetId: String?
    let planetName: String?
    let starName: String?
    let starId: String?
    let planetEventType: String?
    let starEventType: String?
    let planetEventUtc: String?
    let planetEventLocal: String?
    let starEventUtc: String?
    let starEventLocal: String?
    let planetEventJd: Double?
    let starEventJd: Double?
    let eventDeltaSeconds: Double?
    let eventOrbSeconds: Double?
    let planetRa: Double?
    let starRa: Double?
    let raDeltaDeg: Double?
    let paranClass: String?
    let methodKey: String?
    let methodKeyLegacy: String?
    let proxy: Bool?
    let fullParan: Bool?
    let methodTrace: [String: NestedJSON]?
    let note: String?
    var id: String {
        let raPart = raDeltaDeg.map { String($0) } ?? ""
        return "\(planetId ?? "")|\(starId ?? starName ?? "")|\(planetEventType ?? "")"
            + "|\(starEventType ?? "")|\(planetEventUtc ?? "")|\(starEventUtc ?? "")|\(raPart)"
    }
    enum CodingKeys: String, CodingKey {
        case note, proxy
        case planetId = "planet_id"
        case planetName = "planet_name"
        case starId = "star_id"
        case starName = "star_name"
        case planetEventType = "planet_event_type"
        case starEventType = "star_event_type"
        case planetEventUtc = "planet_event_utc"
        case planetEventLocal = "planet_event_local"
        case starEventUtc = "star_event_utc"
        case starEventLocal = "star_event_local"
        case planetEventJd = "planet_event_jd"
        case starEventJd = "star_event_jd"
        case eventDeltaSeconds = "event_delta_seconds"
        case eventOrbSeconds = "event_orb_seconds"
        case planetRa = "planet_ra"
        case starRa = "star_ra"
        case raDeltaDeg = "ra_delta_deg"
        case paranClass = "paran_class"
        case methodKey = "method_key"
        case methodKeyLegacy = "method_key_legacy"
        case fullParan = "full_paran"
        case methodTrace = "method_trace"
    }
}

struct ParanMethodTrace: Codable {
    let provider: String?
    let function: String?
    let localDayBasis: String?
    let localDayStart: String?
    let localDayEnd: String?
    let utcDayStart: String?
    let utcDayEnd: String?
    let pairingRule: String?

    enum CodingKeys: String, CodingKey {
        case provider, function
        case localDayBasis = "local_day_basis"
        case localDayStart = "local_day_start"
        case localDayEnd = "local_day_end"
        case utcDayStart = "utc_day_start"
        case utcDayEnd = "utc_day_end"
        case pairingRule = "pairing_rule"
    }
}

struct ParanPolarDegradation: Codable {
    let active: Bool
    let strategy: String?
    let affectedObjectCount: Int?

    enum CodingKeys: String, CodingKey {
        case active, strategy
        case affectedObjectCount = "affected_object_count"
    }
}

struct PrenatalParansResult: Codable {
    let meta: PrenatalParansMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let methodTrace: ParanMethodTrace?
    let prenatalPacket: NestedJSON?
    let fixedStarParans: [FixedStarParanRow]
    let legacyFixedStarParans: [FixedStarParanRow]
    let eventDiagnostics: [NestedJSON]?
    let polarDegradation: ParanPolarDegradation?
    let migration: [String: NestedJSON]?
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, warnings
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case methodTrace = "method_trace"
        case prenatalPacket = "prenatal_packet"
        case fixedStarParans = "fixed_star_parans"
        case legacyFixedStarParans = "legacy_fixed_star_parans"
        case eventDiagnostics = "event_diagnostics"
        case polarDegradation = "polar_degradation"
        case migration
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
