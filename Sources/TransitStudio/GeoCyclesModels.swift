import Foundation

// MARK: - Place

struct GeoPlace: Codable, Hashable {
    let name: String?
    let latitude: Double
    let longitude: Double
    let timezone: String?
    let altitudeM: Double?

    init(name: String?, latitude: Double, longitude: Double, timezone: String? = nil, altitudeM: Double? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
        self.altitudeM = altitudeM
    }

    enum CodingKeys: String, CodingKey {
        case name, latitude, longitude, timezone
        case altitudeM = "altitude_m"
    }
}

// MARK: - Relocation

struct RelocationBirth: Codable {
    let name: String?
    let moment: ChartMoment
    let latitude: Double
    let longitude: Double
}

struct RelocationRequest: Codable {
    let mode: String
    let birth: RelocationBirth
    let relocation: GeoPlace
    let houseSystem: String
    let zodiac: String
    let nodeMode: String
    let pointSet: ModernPointSet
    let aspects: [AspectRequest]
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "relocation",
        birth: RelocationBirth,
        relocation: GeoPlace,
        houseSystem: String,
        zodiac: String,
        nodeMode: String,
        pointSet: ModernPointSet,
        aspects: [AspectRequest] = [],
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.birth = birth
        self.relocation = relocation
        self.houseSystem = houseSystem
        self.zodiac = zodiac
        self.nodeMode = nodeMode
        self.pointSet = pointSet
        self.aspects = aspects
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode, birth, relocation, zodiac, aspects
        case houseSystem = "house_system"
        case nodeMode = "node_mode"
        case pointSet = "point_set"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

struct RelocationChartSnapshot: Codable {
    let angles: [ClassicalPoint]
    let houses: [HouseRow]
    let planets: [PositionRow]
    let houseSystemRequested: String?
    let houseSystemEffective: String?
    let houseSystemLabel: String?
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case angles, houses, planets, latitude, longitude
        case houseSystemRequested = "house_system_requested"
        case houseSystemEffective = "house_system_effective"
        case houseSystemLabel = "house_system_label"
    }
}

struct PlanetHouseChangeRow: Codable, Identifiable {
    let bodyID: String
    let name: String
    let natalHouse: Int
    let relocatedHouse: Int
    let changed: Bool

    var id: String { bodyID }

    enum CodingKeys: String, CodingKey {
        case bodyID = "body_id"
        case name
        case natalHouse = "natal_house"
        case relocatedHouse = "relocated_house"
        case changed
    }
}

struct AngleOverlayRow: Codable, Identifiable {
    let id: String
    let angleID: String?
    let name: String?
    let longitude: Double
    let sign: String?
    let degreeText: String?
    let house: Int
    let sourceChart: String?
    let targetChart: String?

    enum CodingKeys: String, CodingKey {
        case id, name, longitude, house, sign
        case angleID = "angle_id"
        case degreeText = "degree_text"
        case sourceChart = "source_chart"
        case targetChart = "target_chart"
    }
}

struct RelocationMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let birthUTC: String
    let birthJD: Double?
    let relocationLocal: String
    let birthPlace: GeoPlace
    let relocation: GeoPlace
    let houseSystemRequested: String?
    let houseSystemEffectiveNatal: String?
    let houseSystemEffectiveRelocated: String?
    let zodiac: String?
    let nodeMode: String?
    let ephemeris: String?
    let effectivePointSet: ModernPointSet?

    enum CodingKeys: String, CodingKey {
        case mode, method, zodiac, ephemeris, relocation
        case schemaVersion = "schema_version"
        case birthUTC = "birth_utc"
        case birthJD = "birth_jd"
        case relocationLocal = "relocation_local"
        case birthPlace = "birth_place"
        case houseSystemRequested = "house_system_requested"
        case houseSystemEffectiveNatal = "house_system_effective_natal"
        case houseSystemEffectiveRelocated = "house_system_effective_relocated"
        case nodeMode = "node_mode"
        case effectivePointSet = "effective_point_set"
    }
}

struct RelocationResult: Codable {
    let meta: RelocationMeta
    let natalChart: RelocationChartSnapshot
    let relocatedChart: RelocationChartSnapshot
    let planetHouseChanges: [PlanetHouseChangeRow]
    let relocatedAnglesInNatalHouses: [AngleOverlayRow]
    let natalAnglesInRelocatedHouses: [AngleOverlayRow]
    let warnings: [String]
    let sectionErrors: [String: String]?

    enum CodingKeys: String, CodingKey {
        case meta, warnings
        case natalChart = "natal_chart"
        case relocatedChart = "relocated_chart"
        case planetHouseChanges = "planet_house_changes"
        case relocatedAnglesInNatalHouses = "relocated_angles_in_natal_houses"
        case natalAnglesInRelocatedHouses = "natal_angles_in_relocated_houses"
        case sectionErrors = "section_errors"
    }
}

// MARK: - Modern Cycles

struct ModernCyclesRequest: Codable {
    let mode: String
    let start: ChartMoment
    let end: ChartMoment
    let displayTimezone: String
    let cycleTypes: [String]
    let visibility: String
    let location: GeoPlace?
    let birth: RelocationBirth?
    let targetPointSet: ModernPointSet?
    let contactAspects: [AspectRequest]?
    let zodiac: String
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "modern_cycles",
        start: ChartMoment,
        end: ChartMoment,
        displayTimezone: String,
        cycleTypes: [String],
        visibility: String = "global",
        location: GeoPlace? = nil,
        birth: RelocationBirth? = nil,
        targetPointSet: ModernPointSet? = nil,
        contactAspects: [AspectRequest]? = nil,
        zodiac: String = "tropical",
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.start = start
        self.end = end
        self.displayTimezone = displayTimezone
        self.cycleTypes = cycleTypes
        self.visibility = visibility
        self.location = location
        self.birth = birth
        self.targetPointSet = targetPointSet
        self.contactAspects = contactAspects
        self.zodiac = zodiac
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode, start, end, location, birth, visibility, zodiac
        case displayTimezone = "display_timezone"
        case cycleTypes = "cycle_types"
        case targetPointSet = "target_point_set"
        case contactAspects = "contact_aspects"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

struct CycleContact: Codable, Identifiable {
    let bodyID: String
    let bodyName: String?
    let natalLongitude: Double?
    let cycleLongitude: Double?
    let aspectID: String?
    let aspectName: String?
    let aspectAngle: Double?
    let orb: Double?
    let exactUTC: String

    var id: String { "\(bodyID)|\(aspectID ?? "")|\(exactUTC)" }

    enum CodingKeys: String, CodingKey {
        case orb
        case bodyID = "body_id"
        case bodyName = "body_name"
        case natalLongitude = "natal_longitude"
        case cycleLongitude = "cycle_longitude"
        case aspectID = "aspect_id"
        case aspectName = "aspect_name"
        case aspectAngle = "aspect_angle"
        case exactUTC = "exact_utc"
    }
}

struct CycleEvent: Codable, Identifiable {
    let id: String
    let cycleType: String
    let maximumUTC: String
    let maximumLocal: String?
    let sunLongitude: Double?
    let moonLongitude: Double?
    let separationDeg: Double?
    let eclipseType: String?
    let globalEvent: Bool?
    let visibleAtLocation: Bool?
    let visibilityDetails: [String: JSONValue]?
    let contacts: [CycleContact]?
    let methodKey: String?
    let retflag: Int?

    enum CodingKeys: String, CodingKey {
        case id, contacts
        case cycleType = "cycle_type"
        case maximumUTC = "maximum_utc"
        case maximumLocal = "maximum_local"
        case sunLongitude = "sun_longitude"
        case moonLongitude = "moon_longitude"
        case separationDeg = "separation_deg"
        case eclipseType = "eclipse_type"
        case globalEvent = "global_event"
        case visibleAtLocation = "visible_at_location"
        case visibilityDetails = "visibility_details"
        case methodKey = "method_key"
        case retflag
    }
}

/// Lightweight JSON leaf for optional visibility detail bags.
enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
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
        case .null: try container.encodeNil()
        }
    }
}

struct ModernCyclesMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let startUTC: String?
    let endUTC: String?
    let displayTimezone: String?
    let cycleTypes: [String]?
    let visibility: String?
    let location: GeoPlace?
    let zodiac: String?
    let ephemeris: String?

    enum CodingKeys: String, CodingKey {
        case mode, method, visibility, location, zodiac, ephemeris
        case schemaVersion = "schema_version"
        case startUTC = "start_utc"
        case endUTC = "end_utc"
        case displayTimezone = "display_timezone"
        case cycleTypes = "cycle_types"
    }
}

/// Timeline-registration row (compatible subset of modern_timing event IDs).
struct CycleTimingEvent: Codable, Identifiable {
    let id: String
    let groupID: String?
    let sourceType: String?
    let eventType: String?
    let exactUTC: String?
    let exactLocal: String?

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case sourceType = "source_type"
        case eventType = "event_type"
        case exactUTC = "exact_utc"
        case exactLocal = "exact_local"
    }
}

struct ModernCyclesResult: Codable {
    let meta: ModernCyclesMeta
    let events: [CycleEvent]
    let timingEvents: [CycleTimingEvent]?
    let warnings: [String]
    let sectionErrors: [String: String]?

    enum CodingKeys: String, CodingKey {
        case meta, events, warnings
        case timingEvents = "timing_events"
        case sectionErrors = "section_errors"
    }
}

// MARK: - Astrocartography / Local Space

struct AstrocartographyRequest: Codable {
    let mode: String
    let moment: ChartMoment
    let bodyIDs: [String]
    let angleKinds: [String]
    let zodiac: String
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "astrocartography",
        moment: ChartMoment,
        bodyIDs: [String],
        angleKinds: [String] = ["ASC", "DSC", "MC", "IC"],
        zodiac: String = "tropical",
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.moment = moment
        self.bodyIDs = bodyIDs
        self.angleKinds = angleKinds
        self.zodiac = zodiac
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode, moment, zodiac
        case bodyIDs = "body_ids"
        case angleKinds = "angle_kinds"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

struct MapPoint: Codable, Hashable {
    let latitude: Double
    let longitude: Double
}

struct ACGLine: Codable, Identifiable {
    let id: String
    let bodyID: String
    let bodyName: String?
    let angleKind: String
    let geometry: String?
    let longitude: Double?
    let points: [MapPoint]?
    let segments: [[MapPoint]]?
    let methodKey: String?
    let trace: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case id, geometry, longitude, points, segments, trace
        case bodyID = "body_id"
        case bodyName = "body_name"
        case angleKind = "angle_kind"
        case methodKey = "method_key"
    }
}

struct AstrocartographyMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let momentUTC: String?
    let momentJD: Double?
    let zodiac: String?
    let zodiacRequested: String?
    let coordinateFrame: String?
    let bodyIDs: [String]?
    let angleKinds: [String]?
    let ephemeris: String?
    let unverified: [String]?

    enum CodingKeys: String, CodingKey {
        case mode, method, zodiac, ephemeris, unverified
        case zodiacRequested = "zodiac_requested"
        case coordinateFrame = "coordinate_frame"
        case schemaVersion = "schema_version"
        case momentUTC = "moment_utc"
        case momentJD = "moment_jd"
        case bodyIDs = "body_ids"
        case angleKinds = "angle_kinds"
    }
}

struct AstrocartographyResult: Codable {
    let meta: AstrocartographyMeta
    let lines: [ACGLine]
    let warnings: [String]
    let sectionErrors: [String: String]?

    enum CodingKeys: String, CodingKey {
        case meta, lines, warnings
        case sectionErrors = "section_errors"
    }
}

struct LocalSpaceRequest: Codable {
    let mode: String
    let moment: ChartMoment
    let location: GeoPlace
    let bodyIDs: [String]
    let zodiac: String
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "local_space",
        moment: ChartMoment,
        location: GeoPlace,
        bodyIDs: [String],
        zodiac: String = "tropical",
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.moment = moment
        self.location = location
        self.bodyIDs = bodyIDs
        self.zodiac = zodiac
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode, moment, location, zodiac
        case bodyIDs = "body_ids"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

struct LocalSpaceDirection: Codable, Identifiable {
    let id: String
    let bodyID: String
    let bodyName: String?
    let azimuthDeg: Double
    let altitudeDeg: Double?
    let eclipticLongitude: Double?
    let eclipticLatitude: Double?
    let greatCirclePoints: [MapPoint]?
    let methodKey: String?
    let trace: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case id, trace
        case bodyID = "body_id"
        case bodyName = "body_name"
        case azimuthDeg = "azimuth_deg"
        case altitudeDeg = "altitude_deg"
        case eclipticLongitude = "ecliptic_longitude"
        case eclipticLatitude = "ecliptic_latitude"
        case greatCirclePoints = "great_circle_points"
        case methodKey = "method_key"
    }
}

struct LocalSpaceMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let momentUTC: String?
    let location: GeoPlace?
    let zodiac: String?
    let zodiacRequested: String?
    let coordinateFrame: String?
    let bodyIDs: [String]?
    let ephemeris: String?
    let unverified: [String]?

    enum CodingKeys: String, CodingKey {
        case mode, method, location, zodiac, ephemeris, unverified
        case zodiacRequested = "zodiac_requested"
        case coordinateFrame = "coordinate_frame"
        case schemaVersion = "schema_version"
        case momentUTC = "moment_utc"
        case bodyIDs = "body_ids"
    }
}

struct LocalSpaceResult: Codable {
    let meta: LocalSpaceMeta
    let directions: [LocalSpaceDirection]
    let warnings: [String]
    let sectionErrors: [String: String]?

    enum CodingKeys: String, CodingKey {
        case meta, directions, warnings
        case sectionErrors = "section_errors"
    }
}
