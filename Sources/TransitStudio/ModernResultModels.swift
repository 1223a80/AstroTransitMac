import Foundation

enum ModernSubMode: String, CaseIterable, Identifiable {
    case natal = "natal"
    case synastry = "synastry"
    case composite = "composite"
    case davison = "davison"
    case progression = "progression"
    case solarArc = "solar_arc"
    case harmonic = "harmonic"
    case returnChart = "return"
    case midpoint = "midpoint"
    case progressedComposite = "progressed_composite"
    case relocation = "relocation"
    case modernCycles = "modern_cycles"
    case declinationTiming = "declination_timing"
    case astrocartography = "astrocartography"
    case localSpace = "local_space"

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
        case .returnChart: return "返照盘"
        case .midpoint: return "中点"
        case .progressedComposite: return "推进组合盘"
        case .relocation: return "迁移盘"
        case .modernCycles: return "朔望食相"
        case .declinationTiming: return "赤纬事件"
        case .astrocartography: return "天体地图"
        case .localSpace: return "Local Space"
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
        case .returnChart: return "arrow.clockwise.circle"
        case .midpoint: return "circle.grid.cross"
        case .progressedComposite: return "arrow.triangle.2.circlepath.circle"
        case .relocation: return "airplane.departure"
        case .modernCycles: return "moon.stars"
        case .declinationTiming: return "arrow.up.and.down.circle"
        case .astrocartography: return "globe.americas"
        case .localSpace: return "location.north.line"
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
        case .returnChart: return "current_return"
        case .midpoint: return "axes"
        case .progressedComposite: return "radix_composite_planets"
        case .relocation: return "biwheel"
        case .modernCycles: return "events"
        case .declinationTiming: return "events"
        case .astrocartography: return "lines"
        case .localSpace: return "directions"
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
    case returnChart(ModernReturnResult)
    case midpoint(MidpointResult)
    case progressedComposite(ProgressedCompositeResult)
    case relocation(RelocationResult)
    case modernCycles(ModernCyclesResult)
    case declinationTiming(DeclinationTimingResult)
    case astrocartography(AstrocartographyResult)
    case localSpace(LocalSpaceResult)
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
    let birthUTC: String?
    let referenceUTC: String?
    let ephemeris: String?
    let schemaVersion: Int?
    let zodiac: String?
    let houseSystemRequested: String?
    let houseSystemEffective: String?
    let nodeMode: String?
    let displayTimezone: String?
    let effectivePointSet: ModernPointSet?
    let calculationAssumptions: [String: String]?
    let returnBodyID: String?
    let targetLongitude: Double?
    let locationSource: String?
    let location: ModernReturnLocation?
    let precessionCorrection: String?

    init(
        method: String,
        personAUTC: String?,
        personBUTC: String?,
        natalUTC: String?,
        progressedUTC: String?,
        birthUTC: String? = nil,
        referenceUTC: String? = nil,
        ephemeris: String?,
        schemaVersion: Int? = nil,
        zodiac: String? = nil,
        houseSystemRequested: String? = nil,
        houseSystemEffective: String? = nil,
        nodeMode: String? = nil,
        displayTimezone: String? = nil,
        effectivePointSet: ModernPointSet? = nil,
        calculationAssumptions: [String: String]? = nil,
        returnBodyID: String? = nil,
        targetLongitude: Double? = nil,
        locationSource: String? = nil,
        location: ModernReturnLocation? = nil,
        precessionCorrection: String? = nil
    ) {
        self.method = method
        self.personAUTC = personAUTC
        self.personBUTC = personBUTC
        self.natalUTC = natalUTC
        self.progressedUTC = progressedUTC
        self.birthUTC = birthUTC
        self.referenceUTC = referenceUTC
        self.ephemeris = ephemeris
        self.schemaVersion = schemaVersion
        self.zodiac = zodiac
        self.houseSystemRequested = houseSystemRequested
        self.houseSystemEffective = houseSystemEffective
        self.nodeMode = nodeMode
        self.displayTimezone = displayTimezone
        self.effectivePointSet = effectivePointSet
        self.calculationAssumptions = calculationAssumptions
        self.returnBodyID = returnBodyID
        self.targetLongitude = targetLongitude
        self.locationSource = locationSource
        self.location = location
        self.precessionCorrection = precessionCorrection
    }

    enum CodingKeys: String, CodingKey {
        case method
        case personAUTC = "person_a_utc"
        case personBUTC = "person_b_utc"
        case natalUTC = "natal_utc"
        case progressedUTC = "progressed_utc"
        case birthUTC = "birth_utc"
        case referenceUTC = "reference_utc"
        case ephemeris
        case schemaVersion = "schema_version"
        case zodiac
        case houseSystemRequested = "house_system_requested"
        case houseSystemEffective = "house_system_effective"
        case nodeMode = "node_mode"
        case displayTimezone = "display_timezone"
        case effectivePointSet = "effective_point_set"
        case calculationAssumptions = "calculation_assumptions"
        case returnBodyID = "return_body_id"
        case targetLongitude = "target_longitude"
        case locationSource = "location_source"
        case location
        case precessionCorrection = "precession_correction"
    }
}

/// Return responses use the same common meta envelope as the other modern
/// modes, with return-specific fields carried as optional additions.
typealias ModernReturnMeta = ModernMeta

struct ModernReturnChartSnapshot: Codable {
    let planets: [PositionRow]
    let angles: [ClassicalPoint]
    let houses: [HouseRow]
    let natalPlanets: [PositionRow]?
    let natalAngles: [ClassicalPoint]?
    let natalHouses: [HouseRow]?
    let aspects: [AspectHit]
    let declinationAspects: [DeclinationAspect]?
    let fixedStarConjunctions: [FixedStarConjunction]?
    let patterns: [PatternResult]?
    let chartProfile: ChartProfile?
    let warnings: [String]?
    let sectionErrors: [String: String]?
    let houseSystem: String?
    let zodiac: String?

    /// Compatibility alias for callers that describe the same rows as
    /// positions. The wire contract remains `planets`.
    var positions: [PositionRow] { planets }

    init(
        planets: [PositionRow] = [],
        angles: [ClassicalPoint] = [],
        houses: [HouseRow] = [],
        natalPlanets: [PositionRow]? = nil,
        natalAngles: [ClassicalPoint]? = nil,
        natalHouses: [HouseRow]? = nil,
        aspects: [AspectHit] = [],
        declinationAspects: [DeclinationAspect]? = nil,
        fixedStarConjunctions: [FixedStarConjunction]? = nil,
        patterns: [PatternResult]? = nil,
        chartProfile: ChartProfile? = nil,
        warnings: [String]? = nil,
        sectionErrors: [String: String]? = nil,
        houseSystem: String? = nil,
        zodiac: String? = nil
    ) {
        self.planets = planets
        self.angles = angles
        self.houses = houses
        self.natalPlanets = natalPlanets
        self.natalAngles = natalAngles
        self.natalHouses = natalHouses
        self.aspects = aspects
        self.declinationAspects = declinationAspects
        self.fixedStarConjunctions = fixedStarConjunctions
        self.patterns = patterns
        self.chartProfile = chartProfile
        self.warnings = warnings
        self.sectionErrors = sectionErrors
        self.houseSystem = houseSystem
        self.zodiac = zodiac
    }

    enum CodingKeys: String, CodingKey {
        case planets
        case positions
        case angles
        case houses
        case natalPlanets = "natal_planets"
        case natalAngles = "natal_angles"
        case natalHouses = "natal_houses"
        case aspects
        case declinationAspects = "declination_aspects"
        case fixedStarConjunctions = "fixed_star_conjunctions"
        case patterns
        case chartProfile = "chart_profile"
        case warnings
        case sectionErrors = "section_errors"
        case houseSystem = "house_system"
        case zodiac
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planets = try container.decodeIfPresent([PositionRow].self, forKey: .planets)
            ?? container.decodeIfPresent([PositionRow].self, forKey: .positions)
            ?? []
        angles = try container.decodeIfPresent([ClassicalPoint].self, forKey: .angles) ?? []
        houses = try container.decodeIfPresent([HouseRow].self, forKey: .houses) ?? []
        natalPlanets = try container.decodeIfPresent([PositionRow].self, forKey: .natalPlanets)
        natalAngles = try container.decodeIfPresent([ClassicalPoint].self, forKey: .natalAngles)
        natalHouses = try container.decodeIfPresent([HouseRow].self, forKey: .natalHouses)
        aspects = try container.decodeIfPresent([AspectHit].self, forKey: .aspects) ?? []
        declinationAspects = try container.decodeIfPresent([DeclinationAspect].self, forKey: .declinationAspects)
        fixedStarConjunctions = try container.decodeIfPresent([FixedStarConjunction].self, forKey: .fixedStarConjunctions)
        patterns = try container.decodeIfPresent([PatternResult].self, forKey: .patterns)
        chartProfile = try container.decodeIfPresent(ChartProfile.self, forKey: .chartProfile)
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings)
        sectionErrors = try container.decodeIfPresent([String: String].self, forKey: .sectionErrors)
        houseSystem = try container.decodeIfPresent(String.self, forKey: .houseSystem)
        zodiac = try container.decodeIfPresent(String.self, forKey: .zodiac)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(planets, forKey: .planets)
        try container.encode(angles, forKey: .angles)
        try container.encode(houses, forKey: .houses)
        try container.encodeIfPresent(natalPlanets, forKey: .natalPlanets)
        try container.encodeIfPresent(natalAngles, forKey: .natalAngles)
        try container.encodeIfPresent(natalHouses, forKey: .natalHouses)
        try container.encode(aspects, forKey: .aspects)
        try container.encodeIfPresent(declinationAspects, forKey: .declinationAspects)
        try container.encodeIfPresent(fixedStarConjunctions, forKey: .fixedStarConjunctions)
        try container.encodeIfPresent(patterns, forKey: .patterns)
        try container.encodeIfPresent(chartProfile, forKey: .chartProfile)
        try container.encodeIfPresent(warnings, forKey: .warnings)
        try container.encodeIfPresent(sectionErrors, forKey: .sectionErrors)
        try container.encodeIfPresent(houseSystem, forKey: .houseSystem)
        try container.encodeIfPresent(zodiac, forKey: .zodiac)
    }
}

struct ReturnHouseOverlay: Codable, Identifiable {
    let id: String
    let bodyID: String
    let bodyName: String
    let returnHouse: Int
    let natalHouse: Int

    /// Compatibility label for code that uses the classical overlay naming.
    var planet: String { bodyName }

    init(
        id: String,
        bodyID: String,
        bodyName: String,
        returnHouse: Int,
        natalHouse: Int
    ) {
        self.id = id
        self.bodyID = bodyID
        self.bodyName = bodyName
        self.returnHouse = returnHouse
        self.natalHouse = natalHouse
    }

    enum CodingKeys: String, CodingKey {
        case id
        case bodyID = "body_id"
        case bodyName = "body_name"
        case planet
        case returnHouse = "return_house"
        case natalHouse = "natal_house"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedBodyID = try container.decodeIfPresent(String.self, forKey: .bodyID)
        let decodedPlanet = try container.decodeIfPresent(String.self, forKey: .planet)
        let decodedID = try container.decodeIfPresent(String.self, forKey: .id)
        bodyID = decodedBodyID ?? decodedPlanet ?? decodedID ?? ""
        bodyName = try container.decodeIfPresent(String.self, forKey: .bodyName)
            ?? decodedPlanet
            ?? bodyID
        returnHouse = try container.decode(Int.self, forKey: .returnHouse)
        natalHouse = try container.decode(Int.self, forKey: .natalHouse)
        id = decodedID ?? "(bodyID):(returnHouse):(natalHouse)"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(bodyID, forKey: .bodyID)
        try container.encode(bodyName, forKey: .bodyName)
        try container.encode(returnHouse, forKey: .returnHouse)
        try container.encode(natalHouse, forKey: .natalHouse)
    }
}

struct ModernReturnOccurrence: Codable, Identifiable {
    let label: String
    let exactUTC: String
    let exactLocal: String
    let returnLongitude: Double
    let exactError: Double
    let chart: ModernReturnChartSnapshot?
    let returnToNatalAspects: [AspectHit]
    let houseOverlay: [ReturnHouseOverlay]
    let error: String?

    var id: String { "(label):(exactUTC)" }

    init(
        label: String,
        exactUTC: String,
        exactLocal: String,
        returnLongitude: Double,
        exactError: Double,
        chart: ModernReturnChartSnapshot? = nil,
        returnToNatalAspects: [AspectHit] = [],
        houseOverlay: [ReturnHouseOverlay] = [],
        error: String? = nil
    ) {
        self.label = label
        self.exactUTC = exactUTC
        self.exactLocal = exactLocal
        self.returnLongitude = returnLongitude
        self.exactError = exactError
        self.chart = chart
        self.returnToNatalAspects = returnToNatalAspects
        self.houseOverlay = houseOverlay
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case label
        case exactUTC = "exact_utc"
        case exactLocal = "exact_local"
        case returnLongitude = "return_longitude"
        case exactError = "exact_error"
        case chart
        case returnToNatalAspects = "return_to_natal_aspects"
        case houseOverlay = "house_overlay"
        case error
    }
}

struct ModernReturnResult: Codable {
    let meta: ModernReturnMeta
    let previousReturn: ModernReturnOccurrence?
    let currentCycleReturn: ModernReturnOccurrence?
    let nextReturn: ModernReturnOccurrence?
    let noHitInUserWindow: Bool?
    let suggestedWindow: String?
    let searchStartLocal: String?
    let searchEndLocal: String?
    let warnings: [String]
    let sectionErrors: [String: String]?

    init(
        meta: ModernReturnMeta,
        previousReturn: ModernReturnOccurrence? = nil,
        currentCycleReturn: ModernReturnOccurrence? = nil,
        nextReturn: ModernReturnOccurrence? = nil,
        noHitInUserWindow: Bool? = nil,
        suggestedWindow: String? = nil,
        searchStartLocal: String? = nil,
        searchEndLocal: String? = nil,
        warnings: [String] = [],
        sectionErrors: [String: String]? = nil
    ) {
        self.meta = meta
        self.previousReturn = previousReturn
        self.currentCycleReturn = currentCycleReturn
        self.nextReturn = nextReturn
        self.noHitInUserWindow = noHitInUserWindow
        self.suggestedWindow = suggestedWindow
        self.searchStartLocal = searchStartLocal
        self.searchEndLocal = searchEndLocal
        self.warnings = warnings
        self.sectionErrors = sectionErrors
    }

    enum CodingKeys: String, CodingKey {
        case meta
        case previousReturn = "previous_return"
        case currentCycleReturn = "current_cycle_return"
        case nextReturn = "next_return"
        case noHitInUserWindow = "no_hit_in_user_window"
        case suggestedWindow = "suggested_window"
        case searchStartLocal = "search_start_local"
        case searchEndLocal = "search_end_local"
        case warnings
        case sectionErrors = "section_errors"
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

// MARK: - Progressed Composite

/// Request for the v1 progressed-composite method. The backend requires an
/// explicit planet point set and rejects angles, houses, Lots and midpoint
/// pairs for this mode.
struct ProgressedCompositeRequest: Codable {
    let mode: String
    let personA: PersonSettings
    let personB: PersonSettings
    let reference: ChartMoment
    let pointSet: ModernPointSet
    let zodiac: String
    let nodeMode: String
    let aspects: [AspectRequest]
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "progressed_composite",
        personA: PersonSettings,
        personB: PersonSettings,
        reference: ChartMoment,
        pointSet: ModernPointSet,
        zodiac: String,
        nodeMode: String,
        aspects: [AspectRequest],
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.personA = personA
        self.personB = personB
        self.reference = reference
        self.pointSet = pointSet
        self.zodiac = zodiac
        self.nodeMode = nodeMode
        self.aspects = aspects
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case personA = "person_a"
        case personB = "person_b"
        case reference
        case pointSet = "point_set"
        case zodiac
        case nodeMode = "node_mode"
        case aspects
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

struct ProgressedCompositeMeta: Codable {
    let method: String
    let personABirthUTC: String
    let personBBirthUTC: String
    let personAProgressedUTC: String
    let personBProgressedUTC: String
    let personAAgeYears: Double?
    let personBAgeYears: Double?
    let referenceUTC: String
    let effectivePointSet: ModernPointSet
    let ephemeris: String?
    let schemaVersion: Int?
    let zodiac: String?

    init(
        method: String = "progress_each_person_then_midpoint",
        personABirthUTC: String,
        personBBirthUTC: String,
        personAProgressedUTC: String,
        personBProgressedUTC: String,
        personAAgeYears: Double? = nil,
        personBAgeYears: Double? = nil,
        referenceUTC: String,
        effectivePointSet: ModernPointSet,
        ephemeris: String? = nil,
        schemaVersion: Int? = nil,
        zodiac: String? = nil
    ) {
        self.method = method
        self.personABirthUTC = personABirthUTC
        self.personBBirthUTC = personBBirthUTC
        self.personAProgressedUTC = personAProgressedUTC
        self.personBProgressedUTC = personBProgressedUTC
        self.personAAgeYears = personAAgeYears
        self.personBAgeYears = personBAgeYears
        self.referenceUTC = referenceUTC
        self.effectivePointSet = effectivePointSet
        self.ephemeris = ephemeris
        self.schemaVersion = schemaVersion
        self.zodiac = zodiac
    }

    enum CodingKeys: String, CodingKey {
        case method
        case personABirthUTC = "person_a_birth_utc"
        case personBBirthUTC = "person_b_birth_utc"
        case personAProgressedUTC = "person_a_progressed_utc"
        case personBProgressedUTC = "person_b_progressed_utc"
        case personAAgeYears = "person_a_age_years"
        case personBAgeYears = "person_b_age_years"
        case referenceUTC = "reference_utc"
        case effectivePointSet = "effective_point_set"
        case ephemeris
        case schemaVersion = "schema_version"
        case zodiac
    }
}

struct ProgressedCompositePersonTrace: Codable {
    let birthUTC: String
    let progressedUTC: String
    let inputLongitude: Double

    init(birthUTC: String, progressedUTC: String, inputLongitude: Double) {
        self.birthUTC = birthUTC
        self.progressedUTC = progressedUTC
        self.inputLongitude = inputLongitude
    }

    enum CodingKeys: String, CodingKey {
        case birthUTC = "birth_utc"
        case progressedUTC = "progressed_utc"
        case inputLongitude = "input_longitude"
    }
}

/// Per-planet audit trace. The nested person records mirror the backend
/// contract; the scalar aliases make CSV/export call sites explicit.
struct ProgressedCompositeTrace: Codable {
    let phase: String
    let midpointMethod: String
    let referenceUTC: String
    let personA: ProgressedCompositePersonTrace
    let personB: ProgressedCompositePersonTrace
    let compositeLongitude: Double

    var personABirthUTC: String { personA.birthUTC }
    var personBBirthUTC: String { personB.birthUTC }
    var personAProgressedUTC: String { personA.progressedUTC }
    var personBProgressedUTC: String { personB.progressedUTC }
    var personAInputLongitude: Double { personA.inputLongitude }
    var personBInputLongitude: Double { personB.inputLongitude }

    init(
        phase: String,
        midpointMethod: String,
        referenceUTC: String,
        personA: ProgressedCompositePersonTrace,
        personB: ProgressedCompositePersonTrace,
        compositeLongitude: Double
    ) {
        self.phase = phase
        self.midpointMethod = midpointMethod
        self.referenceUTC = referenceUTC
        self.personA = personA
        self.personB = personB
        self.compositeLongitude = compositeLongitude
    }

    enum CodingKeys: String, CodingKey {
        case phase
        case midpointMethod = "midpoint_method"
        case referenceUTC = "reference_utc"
        case personA = "person_a"
        case personB = "person_b"
        case compositeLongitude = "composite_longitude"
        case personABirthUTC = "person_a_birth_utc"
        case personBBirthUTC = "person_b_birth_utc"
        case personAProgressedUTC = "person_a_progressed_utc"
        case personBProgressedUTC = "person_b_progressed_utc"
        case personAInputLongitude = "person_a_input_longitude"
        case personBInputLongitude = "person_b_input_longitude"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phase = try container.decode(String.self, forKey: .phase)
        midpointMethod = try container.decode(String.self, forKey: .midpointMethod)
        referenceUTC = try container.decode(String.self, forKey: .referenceUTC)
        compositeLongitude = try container.decode(Double.self, forKey: .compositeLongitude)

        if let decodedA = try container.decodeIfPresent(ProgressedCompositePersonTrace.self, forKey: .personA),
           let decodedB = try container.decodeIfPresent(ProgressedCompositePersonTrace.self, forKey: .personB) {
            personA = decodedA
            personB = decodedB
        } else {
            personA = try ProgressedCompositePersonTrace(
                birthUTC: container.decode(String.self, forKey: .personABirthUTC),
                progressedUTC: container.decode(String.self, forKey: .personAProgressedUTC),
                inputLongitude: container.decode(Double.self, forKey: .personAInputLongitude)
            )
            personB = try ProgressedCompositePersonTrace(
                birthUTC: container.decode(String.self, forKey: .personBBirthUTC),
                progressedUTC: container.decode(String.self, forKey: .personBProgressedUTC),
                inputLongitude: container.decode(Double.self, forKey: .personBInputLongitude)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phase, forKey: .phase)
        try container.encode(midpointMethod, forKey: .midpointMethod)
        try container.encode(referenceUTC, forKey: .referenceUTC)
        try container.encode(personA, forKey: .personA)
        try container.encode(personB, forKey: .personB)
        try container.encode(compositeLongitude, forKey: .compositeLongitude)
    }
}

struct ProgressedCompositePlanet: Codable, Identifiable {
    let bodyID: String
    let name: String
    let longitude: Double
    let latitude: Double
    let declination: Double?
    let outOfBounds: Bool?
    let speed: Double
    let sign: String
    let degreeText: String
    let trace: ProgressedCompositeTrace

    var id: String { bodyID }

    init(
        bodyID: String,
        name: String,
        longitude: Double,
        latitude: Double = 0,
        declination: Double? = nil,
        outOfBounds: Bool? = nil,
        speed: Double = 0,
        sign: String = "",
        degreeText: String = "",
        trace: ProgressedCompositeTrace
    ) {
        self.bodyID = bodyID
        self.name = name
        self.longitude = longitude
        self.latitude = latitude
        self.declination = declination
        self.outOfBounds = outOfBounds
        self.speed = speed
        self.sign = sign
        self.degreeText = degreeText
        self.trace = trace
    }

    enum CodingKeys: String, CodingKey {
        case bodyID = "body_id"
        case bodyName = "body_name"
        case pointID = "point_id"
        case id
        case name
        case longitude
        case latitude
        case declination
        case outOfBounds = "out_of_bounds"
        case speed
        case sign
        case degreeText = "degree_text"
        case trace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bodyID = try container.decodeIfPresent(String.self, forKey: .bodyID)
            ?? container.decodeIfPresent(String.self, forKey: .pointID)
            ?? container.decodeIfPresent(String.self, forKey: .id)
            ?? ""
        guard !bodyID.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .bodyID,
                in: container,
                debugDescription: "Progressed composite planet requires body_id"
            )
        }
        self.bodyID = bodyID
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .bodyName)
            ?? bodyID
        self.longitude = try container.decode(Double.self, forKey: .longitude)
        self.latitude = try container.decodeIfPresent(Double.self, forKey: .latitude) ?? 0
        self.declination = try container.decodeIfPresent(Double.self, forKey: .declination)
        self.outOfBounds = try container.decodeIfPresent(Bool.self, forKey: .outOfBounds)
        self.speed = try container.decodeIfPresent(Double.self, forKey: .speed) ?? 0
        self.sign = try container.decodeIfPresent(String.self, forKey: .sign) ?? ""
        self.degreeText = try container.decodeIfPresent(String.self, forKey: .degreeText) ?? ""
        self.trace = try container.decode(ProgressedCompositeTrace.self, forKey: .trace)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bodyID, forKey: .bodyID)
        try container.encode(name, forKey: .name)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(latitude, forKey: .latitude)
        try container.encodeIfPresent(declination, forKey: .declination)
        try container.encodeIfPresent(outOfBounds, forKey: .outOfBounds)
        try container.encode(speed, forKey: .speed)
        try container.encode(sign, forKey: .sign)
        try container.encode(degreeText, forKey: .degreeText)
        try container.encode(trace, forKey: .trace)
    }
}

struct ProgressedCompositeResult: Codable {
    let meta: ProgressedCompositeMeta
    let radixCompositePlanets: [ProgressedCompositePlanet]
    let progressedCompositePlanets: [ProgressedCompositePlanet]
    let progressedToRadixAspects: [AspectHit]
    let warnings: [String]
    let sectionErrors: [String: String]?

    init(
        meta: ProgressedCompositeMeta,
        radixCompositePlanets: [ProgressedCompositePlanet],
        progressedCompositePlanets: [ProgressedCompositePlanet],
        progressedToRadixAspects: [AspectHit],
        warnings: [String] = [],
        sectionErrors: [String: String]? = nil
    ) {
        self.meta = meta
        self.radixCompositePlanets = radixCompositePlanets
        self.progressedCompositePlanets = progressedCompositePlanets
        self.progressedToRadixAspects = progressedToRadixAspects
        self.warnings = warnings
        self.sectionErrors = sectionErrors
    }

    enum CodingKeys: String, CodingKey {
        case meta
        case radixCompositePlanets = "radix_composite_planets"
        case progressedCompositePlanets = "progressed_composite_planets"
        case progressedToRadixAspects = "progressed_to_radix_aspects"
        case warnings
        case sectionErrors = "section_errors"
        case errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meta = try container.decode(ProgressedCompositeMeta.self, forKey: .meta)
        radixCompositePlanets = try container.decode([ProgressedCompositePlanet].self, forKey: .radixCompositePlanets)
        progressedCompositePlanets = try container.decode([ProgressedCompositePlanet].self, forKey: .progressedCompositePlanets)
        progressedToRadixAspects = try container.decode([AspectHit].self, forKey: .progressedToRadixAspects)
        warnings = try container.decode([String].self, forKey: .warnings)
        sectionErrors = try container.decodeIfPresent([String: String].self, forKey: .sectionErrors)
            ?? container.decodeIfPresent([String: String].self, forKey: .errors)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(meta, forKey: .meta)
        try container.encode(radixCompositePlanets, forKey: .radixCompositePlanets)
        try container.encode(progressedCompositePlanets, forKey: .progressedCompositePlanets)
        try container.encode(progressedToRadixAspects, forKey: .progressedToRadixAspects)
        try container.encode(warnings, forKey: .warnings)
        try container.encodeIfPresent(sectionErrors, forKey: .sectionErrors)
    }
}
