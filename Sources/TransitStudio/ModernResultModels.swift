import Foundation

enum ModernSubMode: String, CaseIterable, Identifiable {
    case natal = "natal"
    case synastry = "synastry"
    case composite = "composite"
    case davison = "davison"
    case progression = "progression"
    case solarArc = "solar_arc"
    case harmonic = "harmonic"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .natal: return "本命盘"
        case .synastry: return "合盘"
        case .composite: return "组合盘"
        case .davison: return "戴维森盘"
        case .progression: return "次限推进"
        case .solarArc: return "太阳弧"
        case .harmonic: return "调和盘"
        }
    }

    var icon: String {
        switch self {
        case .natal: return "person.crop.circle"
        case .synastry: return "person.2"
        case .composite: return "circle.hexagongrid"
        case .davison: return "arrow.triangle.merge"
        case .progression: return "forward.fill"
        case .solarArc: return "sun.max"
        case .harmonic: return "music.note.list"
        }
    }

    /// Default result-pane tab for this sub-mode. Shared `modernSelectedTab`
    /// must reset to this when switching modes so stale IDs do not fall through
    /// to `default` with an empty toolbar title.
    var defaultResultTab: String {
        switch self {
        case .natal: return "natal_positions"
        case .synastry: return "cross_aspects"
        case .composite, .davison, .harmonic: return "planets"
        case .progression: return "progressed_planets"
        case .solarArc: return "sa_planets"
        }
    }
}

enum ModernResultData {
    case synastry(SynastryResult)
    case composite(CompositeResult)
    case davison(DavisonResult)
    case progression(ProgressionResult)
    case solarArc(SolarArcResult)
    case harmonic(HarmonicResult)
}

struct PatternResult: Codable, Identifiable {
    let id: String
    let type: String
    let typeName: String
    let members: [String]
    let aspectTypes: [String]
    let orbSummary: String
    let confidence: String
    let stelliumSign: Int?
    let stelliumHouse: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case typeName = "type_name"
        case members
        case aspectTypes = "aspect_types"
        case orbSummary = "orb_summary"
        case confidence
        case stelliumSign = "stellium_sign"
        case stelliumHouse = "stellium_house"
    }
}

struct ChartProfile: Codable {
    let pointIDs: [String]
    let elements: [String: Int]
    let modalities: [String: Int]
    let polarities: [String: Int]
    let hemispheres: [String: Int]
    let quadrants: [String: Int]
    let omittedSections: [String]

    enum CodingKeys: String, CodingKey {
        case pointIDs = "point_ids"
        case elements, modalities, polarities, hemispheres, quadrants
        case omittedSections = "omitted_sections"
    }
}

struct ModernMeta: Codable {
    let method: String
    let personAUTC: String?
    let personBUTC: String?
    let natalUTC: String?
    let progressedUTC: String?
    let ephemeris: String?
    let schemaVersion: Int?
    let zodiac: String?
    let houseSystemRequested: String?
    let houseSystemEffective: String?
    let nodeMode: String?
    let displayTimezone: String?
    let effectivePointSet: ModernPointSet?
    let calculationAssumptions: [String: String]?

    init(
        method: String,
        personAUTC: String?,
        personBUTC: String?,
        natalUTC: String?,
        progressedUTC: String?,
        ephemeris: String?,
        schemaVersion: Int? = nil,
        zodiac: String? = nil,
        houseSystemRequested: String? = nil,
        houseSystemEffective: String? = nil,
        nodeMode: String? = nil,
        displayTimezone: String? = nil,
        effectivePointSet: ModernPointSet? = nil,
        calculationAssumptions: [String: String]? = nil
    ) {
        self.method = method
        self.personAUTC = personAUTC
        self.personBUTC = personBUTC
        self.natalUTC = natalUTC
        self.progressedUTC = progressedUTC
        self.ephemeris = ephemeris
        self.schemaVersion = schemaVersion
        self.zodiac = zodiac
        self.houseSystemRequested = houseSystemRequested
        self.houseSystemEffective = houseSystemEffective
        self.nodeMode = nodeMode
        self.displayTimezone = displayTimezone
        self.effectivePointSet = effectivePointSet
        self.calculationAssumptions = calculationAssumptions
    }

    enum CodingKeys: String, CodingKey {
        case method
        case personAUTC = "person_a_utc"
        case personBUTC = "person_b_utc"
        case natalUTC = "natal_utc"
        case progressedUTC = "progressed_utc"
        case ephemeris
        case schemaVersion = "schema_version"
        case zodiac
        case houseSystemRequested = "house_system_requested"
        case houseSystemEffective = "house_system_effective"
        case nodeMode = "node_mode"
        case displayTimezone = "display_timezone"
        case effectivePointSet = "effective_point_set"
        case calculationAssumptions = "calculation_assumptions"
    }
}

// MARK: - Synastry

struct SynastryRequest: Codable {
    let mode: String
    let personA: PersonSettings
    let personB: PersonSettings
    let houseSystem: String
    let zodiac: String
    let nodeMode: String
    let aspects: [AspectRequest]
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String
    let pointSet: ModernPointSet?

    init(
        mode: String, personA: PersonSettings, personB: PersonSettings,
        houseSystem: String, zodiac: String, nodeMode: String,
        aspects: [AspectRequest], ephemerisPath: String?, noAsteroids: Bool,
        requireEphemeris: String, pointSet: ModernPointSet? = nil
    ) {
        self.mode = mode; self.personA = personA; self.personB = personB
        self.houseSystem = houseSystem; self.zodiac = zodiac; self.nodeMode = nodeMode
        self.aspects = aspects; self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids; self.requireEphemeris = requireEphemeris
        self.pointSet = pointSet
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case personA = "person_a"
        case personB = "person_b"
        case houseSystem = "house_system"
        case zodiac
        case nodeMode = "node_mode"
        case aspects
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
        case pointSet = "point_set"
    }
}

struct PersonSettings: Codable {
    let name: String
    let moment: ChartMoment
    let latitude: Double
    let longitude: Double
}

struct SynastryResult: Codable {
    let meta: ModernMeta
    let personAPlanets: [PositionRow]
    let personBPlanets: [PositionRow]
    let personAAngles: [ClassicalPoint]
    let personBAngles: [ClassicalPoint]
    let personAHouses: [HouseRow]
    let personBHouses: [HouseRow]
    let crossAspects: [AspectHit]
    let aInBHouses: [HousePlacement]
    let bInAHouses: [HousePlacement]
    let patterns: [PatternResult]?
    let crossDeclinationAspects: [DeclinationAspect]?
    let warnings: [String]
    let sectionErrors: [String: String]?

    enum CodingKeys: String, CodingKey {
        case meta
        case personAPlanets = "person_a_planets"
        case personBPlanets = "person_b_planets"
        case personAAngles = "person_a_angles"
        case personBAngles = "person_b_angles"
        case personAHouses = "person_a_houses"
        case personBHouses = "person_b_houses"
        case crossAspects = "cross_aspects"
        case aInBHouses = "a_in_b_houses"
        case bInAHouses = "b_in_a_houses"
        case patterns
        case crossDeclinationAspects = "cross_declination_aspects"
        case warnings
        case sectionErrors = "section_errors"
    }
}

struct HousePlacement: Codable, Identifiable {
    let bodyID: String
    let bodyName: String
    let house: Int

    var id: String { "\(bodyID)_h\(house)" }

    enum CodingKeys: String, CodingKey {
        case bodyID = "body_id"
        case bodyName = "body_name"
        case house
    }
}

// MARK: - Composite

struct CompositeRequest: Codable {
    let mode: String
    let personA: PersonSettings
    let personB: PersonSettings
    let houseSystem: String
    let zodiac: String
    let nodeMode: String
    let aspects: [AspectRequest]
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String
    let pointSet: ModernPointSet?

    init(
        mode: String, personA: PersonSettings, personB: PersonSettings,
        houseSystem: String, zodiac: String, nodeMode: String,
        aspects: [AspectRequest], ephemerisPath: String?, noAsteroids: Bool,
        requireEphemeris: String, pointSet: ModernPointSet? = nil
    ) {
        self.mode = mode; self.personA = personA; self.personB = personB
        self.houseSystem = houseSystem; self.zodiac = zodiac; self.nodeMode = nodeMode
        self.aspects = aspects; self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids; self.requireEphemeris = requireEphemeris
        self.pointSet = pointSet
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case personA = "person_a"
        case personB = "person_b"
        case houseSystem = "house_system"
        case zodiac
        case nodeMode = "node_mode"
        case aspects
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
        case pointSet = "point_set"
    }
}

protocol ChartResultFields: Encodable {
    var meta: ModernMeta { get }
    var angles: [ClassicalPoint] { get }
    var houses: [HouseRow] { get }
    var planets: [PositionRow] { get }
    var aspects: [AspectHit] { get }
    var patterns: [PatternResult]? { get }
    var warnings: [String] { get }
    var sectionErrors: [String: String]? { get }
}

struct CompositeResult: Codable, ChartResultFields {
    let meta: ModernMeta
    let angles: [ClassicalPoint]
    let houses: [HouseRow]
    let planets: [PositionRow]
    let aspects: [AspectHit]
    let patterns: [PatternResult]?
    let warnings: [String]
    let sectionErrors: [String: String]?

    enum CodingKeys: String, CodingKey {
        case meta
        case angles
        case houses
        case planets
        case aspects
        case patterns
        case warnings
        case sectionErrors = "section_errors"
    }
}

// MARK: - Davison

struct DavisonRequest: Codable {
    let mode: String
    let personA: PersonSettings
    let personB: PersonSettings
    let houseSystem: String
    let zodiac: String
    let nodeMode: String
    let aspects: [AspectRequest]
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String
    let pointSet: ModernPointSet?

    init(
        mode: String, personA: PersonSettings, personB: PersonSettings,
        houseSystem: String, zodiac: String, nodeMode: String,
        aspects: [AspectRequest], ephemerisPath: String?, noAsteroids: Bool,
        requireEphemeris: String, pointSet: ModernPointSet? = nil
    ) {
        self.mode = mode; self.personA = personA; self.personB = personB
        self.houseSystem = houseSystem; self.zodiac = zodiac; self.nodeMode = nodeMode
        self.aspects = aspects; self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids; self.requireEphemeris = requireEphemeris
        self.pointSet = pointSet
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case personA = "person_a"
        case personB = "person_b"
        case houseSystem = "house_system"
        case zodiac
        case nodeMode = "node_mode"
        case aspects
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
        case pointSet = "point_set"
    }
}

struct DavisonResult: Codable, ChartResultFields {
    let meta: ModernMeta
    let angles: [ClassicalPoint]
    let houses: [HouseRow]
    let planets: [PositionRow]
    let aspects: [AspectHit]
    let patterns: [PatternResult]?
    let warnings: [String]
    let sectionErrors: [String: String]?

    enum CodingKeys: String, CodingKey {
        case meta
        case angles
        case houses
        case planets
        case aspects
        case patterns
        case warnings
        case sectionErrors = "section_errors"
    }
}

// MARK: - Secondary Progressions

struct ProgressionRequest: Codable {
    let mode: String
    let birth: BirthSettings
    let reference: ChartMoment
    let houseSystem: String
    let zodiac: String
    let nodeMode: String
    let aspects: [AspectRequest]
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String
    let pointSet: ModernPointSet?

    init(
        mode: String, birth: BirthSettings, reference: ChartMoment,
        houseSystem: String, zodiac: String, nodeMode: String,
        aspects: [AspectRequest], ephemerisPath: String?, noAsteroids: Bool,
        requireEphemeris: String, pointSet: ModernPointSet? = nil
    ) {
        self.mode = mode; self.birth = birth; self.reference = reference
        self.houseSystem = houseSystem; self.zodiac = zodiac; self.nodeMode = nodeMode
        self.aspects = aspects; self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids; self.requireEphemeris = requireEphemeris
        self.pointSet = pointSet
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case birth
        case reference
        case houseSystem = "house_system"
        case zodiac
        case nodeMode = "node_mode"
        case aspects
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
        case pointSet = "point_set"
    }
}

struct ProgressionResult: Codable {
    let meta: ModernMeta
    let natalPlanets: [PositionRow]
    let progressedPlanets: [PositionRow]
    let natalAngles: [ClassicalPoint]
    let progressedAngles: [ClassicalPoint]
    let natalHouses: [HouseRow]
    let progressedHouses: [HouseRow]
    let progressedToNatalAspects: [AspectHit]
    let progressedToProgressedAspects: [AspectHit]
    let progressedLunation: ProgressedLunation?
    let warnings: [String]
    let sectionErrors: [String: String]?

    enum CodingKeys: String, CodingKey {
        case meta
        case natalPlanets = "natal_planets"
        case progressedPlanets = "progressed_planets"
        case natalAngles = "natal_angles"
        case progressedAngles = "progressed_angles"
        case natalHouses = "natal_houses"
        case progressedHouses = "progressed_houses"
        case progressedToNatalAspects = "progressed_to_natal_aspects"
        case progressedToProgressedAspects = "progressed_to_progressed_aspects"
        case progressedLunation = "progressed_lunation"
        case warnings
        case sectionErrors = "section_errors"
    }
}

struct ProgressedLunation: Codable {
    let sunMoonSeparation: Double
    let phaseAngle: Double
    let phaseName: String
    let directedPhase: Double?

    enum CodingKeys: String, CodingKey {
        case sunMoonSeparation = "sun_moon_separation"
        case phaseAngle = "phase_angle"
        case phaseName = "phase_name"
        case directedPhase = "directed_phase"
    }
}

// MARK: - Solar Arc

struct SolarArcRequest: Codable {
    let mode: String
    let birth: BirthSettings
    let reference: ChartMoment
    let houseSystem: String
    let zodiac: String
    let nodeMode: String
    let aspects: [AspectRequest]
    let patternsEnabled: Bool?
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String
    let pointSet: ModernPointSet?

    init(
        mode: String, birth: BirthSettings, reference: ChartMoment,
        houseSystem: String, zodiac: String, nodeMode: String,
        aspects: [AspectRequest], patternsEnabled: Bool?, ephemerisPath: String?,
        noAsteroids: Bool, requireEphemeris: String, pointSet: ModernPointSet? = nil
    ) {
        self.mode = mode; self.birth = birth; self.reference = reference
        self.houseSystem = houseSystem; self.zodiac = zodiac; self.nodeMode = nodeMode
        self.aspects = aspects; self.patternsEnabled = patternsEnabled
        self.ephemerisPath = ephemerisPath; self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris; self.pointSet = pointSet
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case birth
        case reference
        case houseSystem = "house_system"
        case zodiac
        case nodeMode = "node_mode"
        case aspects
        case patternsEnabled = "patterns_enabled"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
        case pointSet = "point_set"
    }
}

// MARK: - Harmonic

struct HarmonicRequest: Codable {
    let mode: String
    let birth: BirthSettings
    let harmonicOrder: Int
    let houseSystem: String
    let zodiac: String
    let nodeMode: String
    let aspects: [AspectRequest]
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String
    let pointSet: ModernPointSet?

    init(
        mode: String, birth: BirthSettings, harmonicOrder: Int,
        houseSystem: String, zodiac: String, nodeMode: String,
        aspects: [AspectRequest], ephemerisPath: String?, noAsteroids: Bool,
        requireEphemeris: String, pointSet: ModernPointSet? = nil
    ) {
        self.mode = mode; self.birth = birth; self.harmonicOrder = harmonicOrder
        self.houseSystem = houseSystem; self.zodiac = zodiac; self.nodeMode = nodeMode
        self.aspects = aspects; self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids; self.requireEphemeris = requireEphemeris
        self.pointSet = pointSet
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case birth
        case harmonicOrder = "harmonic_order"
        case houseSystem = "house_system"
        case zodiac
        case nodeMode = "node_mode"
        case aspects
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
        case pointSet = "point_set"
    }
}

struct HarmonicResult: Codable {
    let meta: ModernMeta
    let planets: [PositionRow]
    let angles: [ClassicalPoint]
    let houses: [HouseRow]
    let housesExperimental: Bool?
    let aspects: [AspectHit]
    let warnings: [String]
    let harmonicOrder: Int
    let sectionErrors: [String: String]?

    enum CodingKeys: String, CodingKey {
        case meta
        case planets
        case angles
        case houses
        case housesExperimental = "houses_experimental"
        case aspects
        case warnings
        case harmonicOrder = "harmonic_order"
        case sectionErrors = "section_errors"
    }
}

struct SolarArcResult: Codable {
    let meta: ModernMeta
    let natalPlanets: [PositionRow]
    let solarArcPlanets: [PositionRow]
    let solarArcAngles: [ClassicalPoint]
    let solarArcHouses: [HouseRow]
    let solarArcToNatalAspects: [AspectHit]
    let arcValue: Double
    let patterns: [PatternResult]?
    let warnings: [String]
    let sectionErrors: [String: String]?

    enum CodingKeys: String, CodingKey {
        case meta
        case natalPlanets = "natal_planets"
        case solarArcPlanets = "solar_arc_planets"
        case solarArcAngles = "solar_arc_angles"
        case solarArcHouses = "solar_arc_houses"
        case solarArcToNatalAspects = "solar_arc_to_natal_aspects"
        case arcValue = "arc_value"
        case patterns
        case warnings
        case sectionErrors = "section_errors"
    }
}
