import Foundation

struct DraconicHeliocentricRequest: Codable {
    let mode: String
    let birth: BirthSettings
    let nodeMode: String
    let pointSet: ModernPointSet?
    let zodiac: String?
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(mode: String = "draconic_heliocentric", birth: BirthSettings, nodeMode: String = "true_node", pointSet: ModernPointSet? = nil, zodiac: String? = nil, ephemerisPath: String? = nil, noAsteroids: Bool = false, requireEphemeris: String = "warn") {
        self.mode = mode; self.birth = birth; self.nodeMode = nodeMode; self.pointSet = pointSet; self.zodiac = zodiac
        self.ephemerisPath = ephemerisPath; self.noAsteroids = noAsteroids; self.requireEphemeris = requireEphemeris
    }
    enum CodingKeys: String, CodingKey {
        case mode, birth, zodiac
        case nodeMode = "node_mode"; case pointSet = "point_set"
        case ephemerisPath = "ephemeris_path"; case noAsteroids = "no_asteroids"; case requireEphemeris = "require_ephemeris"
    }
}

struct CoordinatePlanetRow: Codable, Identifiable {
    let bodyID: String
    let name: String?
    let longitude: Double
    let coordinateCenter: String?
    let coordinateSystem: String?
    var id: String { bodyID }
    enum CodingKeys: String, CodingKey {
        case name, longitude
        case bodyID = "body_id"
        case coordinateCenter = "coordinate_center"
        case coordinateSystem = "coordinate_system"
    }
}

struct GeoHelioComparisonRow: Codable, Identifiable {
    let bodyID: String
    let name: String?
    let geocentricLongitude: Double?
    let heliocentricLongitude: Double?
    let deltaDeg: Double?
    var id: String { bodyID }
    enum CodingKeys: String, CodingKey {
        case name
        case bodyID = "body_id"
        case geocentricLongitude = "geocentric_longitude"
        case heliocentricLongitude = "heliocentric_longitude"
        case deltaDeg = "delta_deg"
    }
}

struct DraconicPacket: Codable {
    let shiftDeg: Double?
    let nodeID: String?
    let nodeLongitude: Double?
    let planets: [CoordinatePlanetRow]?
    let coordinateSystem: String?
    let coordinateCenter: String?
    enum CodingKeys: String, CodingKey {
        case planets
        case shiftDeg = "shift_deg"
        case nodeID = "node_id"
        case nodeLongitude = "node_longitude"
        case coordinateSystem = "coordinate_system"
        case coordinateCenter = "coordinate_center"
    }
}

struct HelioPacket: Codable {
    let planets: [CoordinatePlanetRow]?
    let coordinateSystem: String?
    let coordinateCenter: String?
    enum CodingKeys: String, CodingKey {
        case planets
        case coordinateSystem = "coordinate_system"
        case coordinateCenter = "coordinate_center"
    }
}

struct DraconicHeliocentricMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let birthUTC: String?
    let draconicShiftDeg: Double?
    let nodeMode: String?
    let ephemeris: String?
    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris
        case schemaVersion = "schema_version"
        case birthUTC = "birth_utc"
        case draconicShiftDeg = "draconic_shift_deg"
        case nodeMode = "node_mode"
    }
}

struct DraconicHeliocentricResult: Codable {
    let meta: DraconicHeliocentricMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let draconic: DraconicPacket?
    let heliocentric: HelioPacket?
    let geoHelioComparison: [GeoHelioComparisonRow]?
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?
    enum CodingKeys: String, CodingKey {
        case meta, draconic, heliocentric, warnings
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case geoHelioComparison = "geo_helio_comparison"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
