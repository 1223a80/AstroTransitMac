import Foundation

struct RetrogradeCyclesRequest: Codable {
    let mode: String
    let start: ChartMoment
    let end: ChartMoment
    let displayTimezone: String
    let bodyIDs: [String]
    let zodiac: String
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "retrograde_cycles",
        start: ChartMoment,
        end: ChartMoment,
        displayTimezone: String,
        bodyIDs: [String],
        zodiac: String = "tropical",
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.start = start
        self.end = end
        self.displayTimezone = displayTimezone
        self.bodyIDs = bodyIDs
        self.zodiac = zodiac
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode, start, end, zodiac
        case displayTimezone = "display_timezone"
        case bodyIDs = "body_ids"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

struct RetrogradeCyclesMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let startUTC: String?
    let endUTC: String?
    let displayTimezone: String?
    let bodyIDs: [String]?
    let cycleCount: Int?
    let stationCount: Int?
    let zodiac: String?
    let ephemeris: String?
    let searchPadDays: Int?

    enum CodingKeys: String, CodingKey {
        case mode, method, zodiac, ephemeris
        case schemaVersion = "schema_version"
        case startUTC = "start_utc"
        case endUTC = "end_utc"
        case displayTimezone = "display_timezone"
        case bodyIDs = "body_ids"
        case cycleCount = "cycle_count"
        case stationCount = "station_count"
        case searchPadDays = "search_pad_days"
    }
}

struct RetrogradeStationRow: Codable, Identifiable {
    let id: String
    let bodyID: String
    let bodyName: String?
    let stationKind: String
    let exactUTC: String
    let exactLocal: String?
    let longitude: Double?
    let speed: Double?
    let exactOrb: Double?
    let methodKey: String?

    enum CodingKeys: String, CodingKey {
        case id
        case bodyID = "body_id"
        case bodyName = "body_name"
        case stationKind = "station_kind"
        case exactUTC = "exact_utc"
        case exactLocal = "exact_local"
        case longitude, speed
        case exactOrb = "exact_orb"
        case methodKey = "method_key"
    }
}

struct RetrogradePhase: Codable, Identifiable {
    let phase: String
    let startUTC: String?
    let endUTC: String?
    let definition: String?

    var id: String { "\(phase)|\(startUTC ?? "")|\(endUTC ?? "")" }

    enum CodingKeys: String, CodingKey {
        case phase, definition
        case startUTC = "start_utc"
        case endUTC = "end_utc"
    }
}

struct RetrogradeCycleRow: Codable, Identifiable {
    let id: String
    let bodyID: String
    let bodyName: String?
    let cycleIndexInWindow: Int?
    let preShadowStartUTC: String?
    let preShadowStartLocal: String?
    let retrogradeStationUTC: String?
    let retrogradeStationLocal: String?
    let directStationUTC: String?
    let directStationLocal: String?
    let postShadowEndUTC: String?
    let postShadowEndLocal: String?
    let retrogradeStationLongitude: Double?
    let directStationLongitude: Double?
    let shadowLongitudePre: Double?
    let shadowLongitudePost: Double?
    let retrogradeDurationDays: Double?
    let methodKey: String?
    let phases: [RetrogradePhase]?

    enum CodingKeys: String, CodingKey {
        case id, phases
        case bodyID = "body_id"
        case bodyName = "body_name"
        case cycleIndexInWindow = "cycle_index_in_window"
        case preShadowStartUTC = "pre_shadow_start_utc"
        case preShadowStartLocal = "pre_shadow_start_local"
        case retrogradeStationUTC = "retrograde_station_utc"
        case retrogradeStationLocal = "retrograde_station_local"
        case directStationUTC = "direct_station_utc"
        case directStationLocal = "direct_station_local"
        case postShadowEndUTC = "post_shadow_end_utc"
        case postShadowEndLocal = "post_shadow_end_local"
        case retrogradeStationLongitude = "retrograde_station_longitude"
        case directStationLongitude = "direct_station_longitude"
        case shadowLongitudePre = "shadow_longitude_pre"
        case shadowLongitudePost = "shadow_longitude_post"
        case retrogradeDurationDays = "retrograde_duration_days"
        case methodKey = "method_key"
    }
}

struct RetrogradeCyclesResult: Codable {
    let meta: RetrogradeCyclesMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let stations: [RetrogradeStationRow]
    let cycles: [RetrogradeCycleRow]
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, stations, cycles, warnings
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
