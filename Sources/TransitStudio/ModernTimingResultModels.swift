import Foundation

/// Metadata for one independent `modern_timing` query window.
struct ModernTimingMeta: Codable {
    let schemaVersion: Int
    let startUTC: String
    let endUTC: String
    let displayTimezone: String
    let techniqueIDs: [String]
    let techniqueConfigs: [ModernTimingTechniqueRequest]
    let targetCount: Int
    let estimatedWorkUnits: Int
    let ephemeris: String
    let effectivePointSet: ModernPointSet

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case startUTC = "start_utc"
        case endUTC = "end_utc"
        case displayTimezone = "display_timezone"
        case techniqueIDs = "technique_ids"
        case techniqueConfigs = "technique_configs"
        case targetCount = "target_count"
        case estimatedWorkUnits = "estimated_work_units"
        case ephemeris
        case effectivePointSet = "effective_point_set"
    }
}

/// A complete dynamic event pass. Fields that the contract permits to be
/// `null` are optional; exact time, motion, pass numbering, clipping flags and
/// method provenance remain required facts for every event type.
struct ModernTimingEvent: Codable, Identifiable {
    let id: String
    let groupID: String
    let sourceType: String
    let eventType: String
    let movingPointID: String
    let movingPointName: String
    let targetPointID: String?
    let targetPointName: String?
    let targetPointKind: String?
    let targetAxisBranch: String?
    let aspectID: String?
    let aspectName: String?
    let aspectAngle: Double?
    let orbLimit: Double?
    let enteringUTC: String?
    let exactUTC: String
    let leavingUTC: String?
    let exactLocal: String
    let motion: String
    let movingLongitude: Double
    let targetLongitude: Double?
    let exactOrb: Double?
    let passIndexInWindow: Int
    let passCountInWindow: Int
    let windowClippedStart: Bool
    let windowClippedEnd: Bool
    let methodKey: String

    var isWindowClipped: Bool {
        windowClippedStart || windowClippedEnd
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case sourceType = "source_type"
        case eventType = "event_type"
        case movingPointID = "moving_point_id"
        case movingPointName = "moving_point_name"
        case targetPointID = "target_point_id"
        case targetPointName = "target_point_name"
        case targetPointKind = "target_point_kind"
        case targetAxisBranch = "target_axis_branch"
        case aspectID = "aspect_id"
        case aspectName = "aspect_name"
        case aspectAngle = "aspect_angle"
        case orbLimit = "orb_limit"
        case enteringUTC = "entering_utc"
        case exactUTC = "exact_utc"
        case leavingUTC = "leaving_utc"
        case exactLocal = "exact_local"
        case motion
        case movingLongitude = "moving_longitude"
        case targetLongitude = "target_longitude"
        case exactOrb = "exact_orb"
        case passIndexInWindow = "pass_index_in_window"
        case passCountInWindow = "pass_count_in_window"
        case windowClippedStart = "window_clipped_start"
        case windowClippedEnd = "window_clipped_end"
        case methodKey = "method_key"
    }
}

struct ModernTimingResult: Codable {
    let meta: ModernTimingMeta
    let events: [ModernTimingEvent]
    let warnings: [String]
    let sectionErrors: [String: String]?

    enum CodingKeys: String, CodingKey {
        case meta
        case events
        case warnings
        case sectionErrors = "section_errors"
    }
}
