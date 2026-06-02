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
