import Foundation

struct OrbitalDialMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let ephemeris: String?
    let modulus: Int?
    let orbitalPointCount: Int?
    let dialHitCount: Int?
    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris, modulus
        case schemaVersion = "schema_version"
        case orbitalPointCount = "orbital_point_count"
        case dialHitCount = "dial_hit_count"
    }
}

struct OrbitalPointRow: Codable, Identifiable {
    let bodyId: String?
    let pointKind: String?
    let longitude: Double?
    let sign: String?
    let degreeText: String?
    let methodKey: String?
    let coordinateCenter: String?
    let coordinateSystem: String?
    var id: String { "\(bodyId ?? "")|\(pointKind ?? "")|\(longitude.map { String($0) } ?? "")" }
    enum CodingKeys: String, CodingKey {
        case longitude, sign
        case bodyId = "body_id"
        case pointKind = "point_kind"
        case degreeText = "degree_text"
        case methodKey = "method_key"
        case coordinateCenter = "coordinate_center"
        case coordinateSystem = "coordinate_system"
    }
}

struct DialPictureRow: Codable, Identifiable {
    let pointA: String?
    let pointB: String?
    let pointC: String?
    let midpointLongitude: Double?
    let modulus: Int?
    let foldedPosition: Double?
    let picture: String?
    let orb: Double?
    let methodKey: String?
    var id: String { "\(picture ?? "")|\(methodKey ?? "")|\(orb.map { String($0) } ?? "")" }
    enum CodingKeys: String, CodingKey {
        case modulus, picture, orb
        case pointA = "point_a"
        case pointB = "point_b"
        case pointC = "point_c"
        case midpointLongitude = "midpoint_longitude"
        case foldedPosition = "folded_position"
        case methodKey = "method_key"
    }
}

struct OrbitalDialResult: Codable {
    let meta: OrbitalDialMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let orbitalPoints: [OrbitalPointRow]
    let dialPictures: [DialPictureRow]
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, warnings
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case orbitalPoints = "orbital_points"
        case dialPictures = "dial_pictures"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
