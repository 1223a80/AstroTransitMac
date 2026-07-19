import Foundation

// MARK: - Request

struct DeclinationTimingRequest: Codable {
    let mode: String
    let birth: BirthSettings
    let start: ChartMoment
    let end: ChartMoment
    let displayTimezone: String
    let movingBodyIDs: [String]
    let eventTypes: [String]
    let declinationOrb: Double
    let targetPointSet: ModernPointSet
    let zodiac: String
    let nodeMode: String?
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "declination_timing",
        birth: BirthSettings,
        start: ChartMoment,
        end: ChartMoment,
        displayTimezone: String,
        movingBodyIDs: [String],
        eventTypes: [String],
        declinationOrb: Double = 1.0,
        targetPointSet: ModernPointSet,
        zodiac: String = "tropical",
        nodeMode: String? = "true_node",
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.birth = birth
        self.start = start
        self.end = end
        self.displayTimezone = displayTimezone
        self.movingBodyIDs = movingBodyIDs
        self.eventTypes = eventTypes
        self.declinationOrb = declinationOrb
        self.targetPointSet = targetPointSet
        self.zodiac = zodiac
        self.nodeMode = nodeMode
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode, birth, start, end, zodiac
        case displayTimezone = "display_timezone"
        case movingBodyIDs = "moving_body_ids"
        case eventTypes = "event_types"
        case declinationOrb = "declination_orb"
        case targetPointSet = "target_point_set"
        case nodeMode = "node_mode"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

// MARK: - Result

struct DeclinationTimingMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let coordinateKind: String?
    let startUTC: String?
    let endUTC: String?
    let displayTimezone: String?
    let movingBodyIDs: [String]?
    let eventTypes: [String]?
    let declinationOrb: Double?
    let targetCount: Int?
    let eventCount: Int?
    let ephemeris: String?
    let effectivePointSet: ModernPointSet?
    let oobThresholdMethod: String?
    let oobThresholdSample: Double?
    let oobThresholdSampleMethod: String?
    let searchPrecisionSeconds: Double?
    let searchMethod: String?
    let zodiac: String?

    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris, zodiac
        case schemaVersion = "schema_version"
        case coordinateKind = "coordinate_kind"
        case startUTC = "start_utc"
        case endUTC = "end_utc"
        case displayTimezone = "display_timezone"
        case movingBodyIDs = "moving_body_ids"
        case eventTypes = "event_types"
        case declinationOrb = "declination_orb"
        case targetCount = "target_count"
        case eventCount = "event_count"
        case effectivePointSet = "effective_point_set"
        case oobThresholdMethod = "oob_threshold_method"
        case oobThresholdSample = "oob_threshold_sample"
        case oobThresholdSampleMethod = "oob_threshold_sample_method"
        case searchPrecisionSeconds = "search_precision_seconds"
        case searchMethod = "search_method"
    }
}

struct DeclinationTimingEvent: Codable, Identifiable {
    let id: String
    let groupID: String
    let coordinateKind: String?
    let sourceType: String
    let eventType: String
    let movingPointID: String
    let movingPointName: String
    let targetPointID: String?
    let targetPointName: String?
    let targetPointKind: String?
    let aspectID: String?
    let aspectName: String?
    let orbLimit: Double?
    let enteringUTC: String?
    let exactUTC: String
    let leavingUTC: String?
    let exactLocal: String
    let motion: String
    let movingDeclination: Double
    let movingDeclinationSpeed: Double?
    let targetDeclination: Double?
    let exactOrb: Double?
    let oobThreshold: Double?
    let thresholdMethod: String?
    let outOfBounds: Bool?
    let movingLongitude: Double?
    let targetLongitude: Double?
    let passIndexInWindow: Int
    let passCountInWindow: Int
    let windowClippedStart: Bool
    let windowClippedEnd: Bool
    let searchPrecisionSeconds: Double?
    let methodKey: String
    let targetMethod: String?

    var isWindowClipped: Bool {
        windowClippedStart || windowClippedEnd
    }

    enum CodingKeys: String, CodingKey {
        case id, motion
        case groupID = "group_id"
        case coordinateKind = "coordinate_kind"
        case sourceType = "source_type"
        case eventType = "event_type"
        case movingPointID = "moving_point_id"
        case movingPointName = "moving_point_name"
        case targetPointID = "target_point_id"
        case targetPointName = "target_point_name"
        case targetPointKind = "target_point_kind"
        case aspectID = "aspect_id"
        case aspectName = "aspect_name"
        case orbLimit = "orb_limit"
        case enteringUTC = "entering_utc"
        case exactUTC = "exact_utc"
        case leavingUTC = "leaving_utc"
        case exactLocal = "exact_local"
        case movingDeclination = "moving_declination"
        case movingDeclinationSpeed = "moving_declination_speed"
        case targetDeclination = "target_declination"
        case exactOrb = "exact_orb"
        case oobThreshold = "oob_threshold"
        case thresholdMethod = "threshold_method"
        case outOfBounds = "out_of_bounds"
        case movingLongitude = "moving_longitude"
        case targetLongitude = "target_longitude"
        case passIndexInWindow = "pass_index_in_window"
        case passCountInWindow = "pass_count_in_window"
        case windowClippedStart = "window_clipped_start"
        case windowClippedEnd = "window_clipped_end"
        case searchPrecisionSeconds = "search_precision_seconds"
        case methodKey = "method_key"
        case targetMethod = "target_method"
    }
}

/// Nested JSON bag used for requested/effective config provenance.
enum NestedJSON: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: NestedJSON])
    case array([NestedJSON])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: NestedJSON].self) {
            self = .object(value)
        } else if let value = try? container.decode([NestedJSON].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct DeclinationTimingResult: Codable {
    let meta: DeclinationTimingMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let events: [DeclinationTimingEvent]
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, events, warnings
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
