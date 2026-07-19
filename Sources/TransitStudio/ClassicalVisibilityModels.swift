import Foundation

struct ClassicalVisibilityRequest: Codable {
    let mode: String
    let moment: ChartMoment
    let location: GeoPlace
    let displayTimezone: String
    let bodyIDs: [String]
    let heliacalEventTypes: [String]
    let include: [String]
    let observerAge: Double
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "classical_visibility",
        moment: ChartMoment,
        location: GeoPlace,
        displayTimezone: String,
        bodyIDs: [String],
        heliacalEventTypes: [String] = ["heliacal_rising", "heliacal_setting"],
        include: [String] = ["heliacal", "rise_set", "planetary_hours"],
        observerAge: Double = 36,
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.moment = moment
        self.location = location
        self.displayTimezone = displayTimezone
        self.bodyIDs = bodyIDs
        self.heliacalEventTypes = heliacalEventTypes
        self.include = include
        self.observerAge = observerAge
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode, moment, location, include
        case displayTimezone = "display_timezone"
        case bodyIDs = "body_ids"
        case heliacalEventTypes = "heliacal_event_types"
        case observerAge = "observer_age"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

struct ClassicalVisibilityMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let referenceUTC: String?
    let displayTimezone: String?
    let location: GeoPlace?
    let bodyIDs: [String]?
    let heliacalEventTypes: [String]?
    let include: [String]?
    let ephemeris: String?

    enum CodingKeys: String, CodingKey {
        case mode, method, location, include, ephemeris
        case schemaVersion = "schema_version"
        case referenceUTC = "reference_utc"
        case displayTimezone = "display_timezone"
        case bodyIDs = "body_ids"
        case heliacalEventTypes = "heliacal_event_types"
    }
}

struct HeliacalEventRow: Codable, Identifiable {
    let id: String
    let bodyID: String
    let bodyName: String?
    let eventType: String
    let exactUTC: String?
    let exactLocal: String?
    let status: String?
    let methodKey: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id, status, error
        case bodyID = "body_id"
        case bodyName = "body_name"
        case eventType = "event_type"
        case exactUTC = "exact_utc"
        case exactLocal = "exact_local"
        case methodKey = "method_key"
    }
}

struct RiseSetRow: Codable, Identifiable {
    let bodyID: String
    let bodyName: String?
    let riseUTC: String?
    let setUTC: String?
    let riseLocal: String?
    let setLocal: String?
    let methodKey: String?
    let riseError: String?
    let setError: String?

    var id: String { bodyID }

    enum CodingKeys: String, CodingKey {
        case bodyID = "body_id"
        case bodyName = "body_name"
        case riseUTC = "rise_utc"
        case setUTC = "set_utc"
        case riseLocal = "rise_local"
        case setLocal = "set_local"
        case methodKey = "method_key"
        case riseError = "rise_error"
        case setError = "set_error"
    }
}

struct PlanetaryHourRow: Codable, Identifiable {
    let hourIndex: Int
    let period: String
    let rulerID: String
    let rulerName: String?
    let startUTC: String
    let endUTC: String
    let startLocal: String?
    let endLocal: String?
    let durationMinutes: Double?

    var id: String { "\(period)|\(hourIndex)|\(startUTC)" }

    enum CodingKeys: String, CodingKey {
        case period
        case hourIndex = "hour_index"
        case rulerID = "ruler_id"
        case rulerName = "ruler_name"
        case startUTC = "start_utc"
        case endUTC = "end_utc"
        case startLocal = "start_local"
        case endLocal = "end_local"
        case durationMinutes = "duration_minutes"
    }
}

struct PlanetaryHoursBlock: Codable {
    let status: String?
    let reason: String?
    let methodKey: String?
    let weekdayLocal: String?
    let dayRulerID: String?
    let dayRulerName: String?
    let sunriseUTC: String?
    let sunsetUTC: String?
    let nextSunriseUTC: String?
    let sunriseLocal: String?
    let sunsetLocal: String?
    let nextSunriseLocal: String?
    let dayHourMinutes: Double?
    let nightHourMinutes: Double?
    let currentHour: PlanetaryHourRow?
    let hours: [PlanetaryHourRow]?

    enum CodingKeys: String, CodingKey {
        case status, reason, hours
        case methodKey = "method_key"
        case weekdayLocal = "weekday_local"
        case dayRulerID = "day_ruler_id"
        case dayRulerName = "day_ruler_name"
        case sunriseUTC = "sunrise_utc"
        case sunsetUTC = "sunset_utc"
        case nextSunriseUTC = "next_sunrise_utc"
        case sunriseLocal = "sunrise_local"
        case sunsetLocal = "sunset_local"
        case nextSunriseLocal = "next_sunrise_local"
        case dayHourMinutes = "day_hour_minutes"
        case nightHourMinutes = "night_hour_minutes"
        case currentHour = "current_hour"
    }
}

struct ClassicalVisibilityResult: Codable {
    let meta: ClassicalVisibilityMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let heliacalEvents: [HeliacalEventRow]
    let riseSet: [RiseSetRow]
    let planetaryHours: PlanetaryHoursBlock?
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, warnings
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case heliacalEvents = "heliacal_events"
        case riseSet = "rise_set"
        case planetaryHours = "planetary_hours"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
