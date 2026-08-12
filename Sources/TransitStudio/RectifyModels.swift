import Foundation

// MARK: - Request

struct RectifyRequest: Encodable {
    let mode = "rectify"
    let birthDate: String
    let centerTime: String
    let timezone: String
    let latitude: Double
    let longitude: Double
    let houseSystem: String
    let zodiac: String
    let boundsSystem: String
    let triplicitySystem: String
    let maxAge: Int
    let windowMinutes: Int
    let stepMinutes: Int

    enum CodingKeys: String, CodingKey {
        case mode
        case birthDate = "birth_date"
        case centerTime = "center_time"
        case timezone
        case latitude
        case longitude
        case houseSystem = "house_system"
        case zodiac
        case boundsSystem = "bounds_system"
        case triplicitySystem = "triplicity_system"
        case maxAge = "max_age"
        case windowMinutes = "window_minutes"
        case stepMinutes = "step_minutes"
    }
}

struct RectifyLevel2Request: Encodable {
    let mode = "rectify"
    let birthDate: String
    let centerTime: String
    let timezone: String
    let latitude: Double
    let longitude: Double
    let houseSystem: String
    let zodiac: String
    let boundsSystem: String
    let triplicitySystem: String
    let maxAge: Int
    let centerOffsetSeconds: Int
    let windowSeconds: Int
    let stepSeconds: Int

    enum CodingKeys: String, CodingKey {
        case mode
        case birthDate = "birth_date"
        case centerTime = "center_time"
        case timezone
        case latitude
        case longitude
        case houseSystem = "house_system"
        case zodiac
        case boundsSystem = "bounds_system"
        case triplicitySystem = "triplicity_system"
        case maxAge = "max_age"
        case centerOffsetSeconds = "center_offset_seconds"
        case windowSeconds = "window_seconds"
        case stepSeconds = "step_seconds"
    }
}

// MARK: - Response

struct RectifyResponse: Decodable {
    let centerOffsetIndex: Int
    let totalCandidates: Int
    let windowMinutes: Int?
    let windowSeconds: Int?
    let candidates: [Candidate]
    let warnings: [String]?

    enum CodingKeys: String, CodingKey {
        case centerOffsetIndex = "center_offset_index"
        case totalCandidates = "total_candidates"
        case windowMinutes = "window_minutes"
        case windowSeconds = "window_seconds"
        case candidates, warnings
    }
}

extension RectifyResponse {
    struct Candidate: Decodable {
        let offsetMinutes: Int
        let offsetSeconds: Int?
        let birthLocal: String
        let angles: [String: AngleInfo]
        let planetsSummary: [PlanetSummary]?
        let primaryDirections: [Direction]

        enum CodingKeys: String, CodingKey {
            case offsetMinutes = "offset_minutes"
            case offsetSeconds = "offset_seconds"
            case birthLocal = "birth_local"
            case angles
            case planetsSummary = "planets_summary"
            case primaryDirections = "primary_directions"
        }
    }

    struct AngleInfo: Decodable {
        let longitude: Double
    }

    struct PlanetSummary: Decodable {
        let id: String
        let name: String
        let longitude: Double
        let sign: String
        let house: Int
    }

    struct Direction: Decodable, Identifiable {
        let id: String
        let promissor: String
        let significator: String
        let aspectName: String
        let directionType: String
        let ageFromAbsArc: Double
        let eventDateAfterBirth: String
        let note: String
        let tags: [String]
        let housesInvolved: [Int]
        let shiftVsCenterDays: Double

        enum CodingKeys: String, CodingKey {
            case id, promissor, significator, note, tags
            case aspectName = "aspect_name"
            case directionType = "direction_type"
            case ageFromAbsArc = "age_from_abs_arc"
            case eventDateAfterBirth = "event_date_after_birth"
            case housesInvolved = "houses_involved"
            case shiftVsCenterDays = "shift_vs_center_days"
        }
    }
}

// MARK: - Param hash for change detection

extension RectifyRequest {
    var paramHash: Int {
        var hasher = Hasher()
        hasher.combine(birthDate)
        hasher.combine(centerTime)
        hasher.combine(timezone)
        hasher.combine(latitude)
        hasher.combine(longitude)
        hasher.combine(houseSystem)
        hasher.combine(zodiac)
        hasher.combine(boundsSystem)
        hasher.combine(triplicitySystem)
        hasher.combine(maxAge)
        return hasher.finalize()
    }
}

// MARK: - Rectification evidence request

struct RectificationEvidenceRequest: Encodable {
    let mode = "rectify_evidence"
    let birth: BirthSettings
    let events: [RectificationEvidenceSourceEvent]
    let displayTimezone: String
    let candidateWindowSeconds: Int
    let candidateStepSeconds: Int
    let maxCandidates: Int
    let primaryDirectionKeys: [String]
    let targetAngleIDs: [String]
    let maxAge: Double
    let maxEvidenceRowsPerFamily: Int
    let confirmedHeavyScan: Bool

    enum CodingKeys: String, CodingKey {
        case mode, birth, events
        case displayTimezone = "display_timezone"
        case candidateWindowSeconds = "candidate_window_seconds"
        case candidateStepSeconds = "candidate_step_seconds"
        case maxCandidates = "max_candidates"
        case primaryDirectionKeys = "primary_direction_keys"
        case targetAngleIDs = "target_angle_ids"
        case maxAge = "max_age"
        case maxEvidenceRowsPerFamily = "max_evidence_rows_per_family"
        case confirmedHeavyScan = "confirmed_heavy_scan"
    }
}

struct RectificationEvidenceSourceEvent: Codable, Identifiable {
    let id: String
    let category: String
    let description: String
    let sourceQuality: String
    let confidence: Double
    let holdout: Bool
    let start: ChartMoment
    let end: ChartMoment

    enum CodingKeys: String, CodingKey {
        case id, category, description, confidence, holdout, start, end
        case sourceQuality = "source_quality"
    }
}

// MARK: - Rectification evidence response

struct RectificationEvidenceResponse: Decodable {
    let schema: SchemaInfo
    let meta: Meta
    let requestedConfig: RequestedConfig
    let methodProfiles: [MethodProfile]
    let events: [RectificationEvidenceSourceEvent]
    let candidates: [Candidate]
    let warnings: [String]
    let calculationAssumptions: [String]

    enum CodingKeys: String, CodingKey {
        case schema, meta, events, candidates, warnings
        case requestedConfig = "requested_config"
        case methodProfiles = "method_profiles"
        case calculationAssumptions = "calculation_assumptions"
    }
}

extension RectificationEvidenceResponse {
    struct SchemaInfo: Decodable {
        let name: String
        let version: String
        let schemaID: String

        enum CodingKeys: String, CodingKey {
            case name, version
            case schemaID = "schema_id"
        }
    }

    struct Meta: Decodable {
        let mode: String
        let candidateCount: Int
        let eventCount: Int
        let zodiac: String
        let houseSystemRequested: String
        let displayTimezone: String
        let scientificValidation: String
        let automaticBestTime: Bool

        enum CodingKeys: String, CodingKey {
            case mode, zodiac
            case candidateCount = "candidate_count"
            case eventCount = "event_count"
            case houseSystemRequested = "house_system_requested"
            case displayTimezone = "display_timezone"
            case scientificValidation = "scientific_validation"
            case automaticBestTime = "automatic_best_time"
        }
    }

    struct RequestedConfig: Decodable {
        let candidateWindowSeconds: Int
        let candidateStepSeconds: Int
        let maxCandidates: Int
        let primaryDirectionKeys: [String]
        let targetAngleIDs: [String]
        let maxAge: Double
        let maxEvidenceRowsPerFamily: Int
        let confirmedHeavyScan: Bool
        let timingTechniqueIDs: [String]

        enum CodingKeys: String, CodingKey {
            case candidateWindowSeconds = "candidate_window_seconds"
            case candidateStepSeconds = "candidate_step_seconds"
            case maxCandidates = "max_candidates"
            case primaryDirectionKeys = "primary_direction_keys"
            case targetAngleIDs = "target_angle_ids"
            case maxAge = "max_age"
            case maxEvidenceRowsPerFamily = "max_evidence_rows_per_family"
            case confirmedHeavyScan = "confirmed_heavy_scan"
            case timingTechniqueIDs = "timing_technique_ids"
        }
    }

    struct MethodProfile: Decodable, Identifiable {
        var id: String { profileID }
        let profileID: String
        let family: String
        let status: String
        let role: String
        let independenceGroup: String
        let note: String?
        let includes: [String]?
        let excludes: [String]?

        enum CodingKeys: String, CodingKey {
            case family, status, role, note, includes, excludes
            case profileID = "profile_id"
            case independenceGroup = "independence_group"
        }
    }

    struct Candidate: Decodable, Identifiable {
        var id: String { "candidate-\(offsetSeconds)" }
        let offsetSeconds: Int
        let birthLocal: String
        let birthUTC: String
        let houseSystem: String
        let angles: [String: Double]
        let familyHitCounts: FamilyHitCounts
        let evidenceByEvent: [EventEvidence]
        let warnings: [String]

        enum CodingKeys: String, CodingKey {
            case angles, warnings
            case offsetSeconds = "offset_seconds"
            case birthLocal = "birth_local"
            case birthUTC = "birth_utc"
            case houseSystem = "house_system"
            case familyHitCounts = "family_hit_counts"
            case evidenceByEvent = "evidence_by_event"
        }
    }

    struct FamilyHitCounts: Decodable {
        let primaryMotion: Int
        let transit: Int
        let secondaryProgression: Int
        let solarArc: Int

        enum CodingKeys: String, CodingKey {
            case transit
            case primaryMotion = "primary_motion"
            case secondaryProgression = "secondary_progression"
            case solarArc = "solar_arc"
        }
    }

    struct EventEvidence: Decodable, Identifiable {
        var id: String { eventID }
        let eventID: String
        let eventCategory: String
        let holdout: Bool
        let primaryMotion: PrimaryMotionFamily
        let families: TimingFamilies
        let sectionErrors: RectificationJSONValue?

        enum CodingKeys: String, CodingKey {
            case holdout, families
            case eventID = "event_id"
            case eventCategory = "event_category"
            case primaryMotion = "primary_motion"
            case sectionErrors = "section_errors"
        }
    }

    struct PrimaryMotionFamily: Decodable {
        let methodFamily: String
        let independenceGroup: String
        let windowHitCount: Int
        let nearestDistanceDays: Double?
        let evidence: [PrimaryMotionRow]
        let truncated: Bool

        enum CodingKeys: String, CodingKey {
            case evidence, truncated
            case methodFamily = "method_family"
            case independenceGroup = "independence_group"
            case windowHitCount = "window_hit_count"
            case nearestDistanceDays = "nearest_distance_days"
        }
    }

    struct PrimaryMotionRow: Decodable, Identifiable {
        let id: String
        let methodProfile: String
        let methodStatus: String
        let keyProfile: String
        let keyRateDegreesPerYear: Double
        let promissorID: String
        let promissor: String
        let significatorID: String
        let directionType: String
        let arcSigned: Double
        let arcAbsolute: Double
        let ageYears: Double
        let eventDateTimeAfterBirth: String
        let distanceToEventWindowDays: Double
        let insideEventWindow: Bool
        let completePrimaryDirectionsSuite: Bool
        let geometry: Geometry

        enum CodingKeys: String, CodingKey {
            case id, promissor, geometry
            case methodProfile = "method_profile"
            case methodStatus = "method_status"
            case keyProfile = "key_profile"
            case keyRateDegreesPerYear = "key_rate_deg_per_year"
            case promissorID = "promissor_id"
            case significatorID = "significator_id"
            case directionType = "direction_type"
            case arcSigned = "arc_signed"
            case arcAbsolute = "arc_abs"
            case ageYears = "age_years"
            case eventDateTimeAfterBirth = "event_datetime_after_birth"
            case distanceToEventWindowDays = "distance_to_event_window_days"
            case insideEventWindow = "inside_event_window"
            case completePrimaryDirectionsSuite = "complete_primary_directions_suite"
        }
    }

    struct Geometry: Decodable {
        let rightAscension: Double?
        let declination: Double?
        let armc: Double?
        let ascensionalDifference: Double?
        let coordinate: String?
        let promissorCoordinate: Double?
        let targetCoordinate: Double?
        let arcSignConvention: String?

        enum CodingKeys: String, CodingKey {
            case coordinate, armc, declination
            case rightAscension = "right_ascension"
            case ascensionalDifference = "ascensional_difference"
            case promissorCoordinate = "promissor_coordinate"
            case targetCoordinate = "target_coordinate"
            case arcSignConvention = "arc_sign_convention"
        }
    }

    struct TimingFamilies: Decodable {
        let transit: TimingFamily
        let secondaryProgression: TimingFamily
        let solarArc: TimingFamily

        enum CodingKeys: String, CodingKey {
            case transit
            case secondaryProgression = "secondary_progression"
            case solarArc = "solar_arc"
        }
    }

    struct TimingFamily: Decodable {
        let methodFamily: String
        let independenceGroup: String
        let exactHitCount: Int
        let evidence: [TimingRow]
        let truncated: Bool

        enum CodingKeys: String, CodingKey {
            case evidence, truncated
            case methodFamily = "method_family"
            case independenceGroup = "independence_group"
            case exactHitCount = "exact_hit_count"
        }
    }

    struct TimingRow: Decodable, Identifiable {
        let id: String
        let sourceType: String
        let exactUTC: String
        let exactLocal: String?
        let movingPointID: String?
        let movingPointName: String?
        let targetPointID: String?
        let targetPointName: String?
        let aspectID: String?
        let aspectName: String?
        let motion: String?
        let exactOrb: Double?
        let orbLimit: Double?
        let passIndexInWindow: Int?
        let passCountInWindow: Int?
        let windowClippedStart: Bool?
        let windowClippedEnd: Bool?
        let methodKey: String?
        let distanceToEventMidpointDays: Double

        var isWindowClipped: Bool {
            windowClippedStart == true || windowClippedEnd == true
        }

        enum CodingKeys: String, CodingKey {
            case id, motion
            case sourceType = "source_type"
            case exactUTC = "exact_utc"
            case exactLocal = "exact_local"
            case movingPointID = "moving_point_id"
            case movingPointName = "moving_point_name"
            case targetPointID = "target_point_id"
            case targetPointName = "target_point_name"
            case aspectID = "aspect_id"
            case aspectName = "aspect_name"
            case exactOrb = "exact_orb"
            case orbLimit = "orb_limit"
            case passIndexInWindow = "pass_index_in_window"
            case passCountInWindow = "pass_count_in_window"
            case windowClippedStart = "window_clipped_start"
            case windowClippedEnd = "window_clipped_end"
            case methodKey = "method_key"
            case distanceToEventMidpointDays = "distance_to_event_midpoint_days"
        }
    }
}

indirect enum RectificationJSONValue: Decodable {
    case object([String: RectificationJSONValue])
    case array([RectificationJSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode([String: RectificationJSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([RectificationJSONValue].self) { self = .array(value) }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else { self = .string(try container.decode(String.self)) }
    }
}
