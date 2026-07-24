import Foundation

enum GMTOffset {
    static func timeZone(hours: Double) -> TimeZone {
        TimeZone(secondsFromGMT: Int((hours * 3600).rounded())) ?? .current
    }

    static func label(hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        let sign = totalMinutes >= 0 ? "+" : "-"
        let absoluteMinutes = abs(totalMinutes)
        let wholeHours = absoluteMinutes / 60
        let minutes = absoluteMinutes % 60
        if minutes == 0 {
            return "GMT\(sign)\(wholeHours)"
        }
        return String(format: "GMT%@%d:%02d", sign, wholeHours, minutes)
    }
}

struct ChartMoment: Codable {
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
    let timezone: String
}

struct AspectRequest: Codable {
    let id: String
    let name: String
    let angle: Double
    let orb: Double
}

/// One authoritative natal midpoint axis selection. Only endpoint IDs cross
/// the wire; the backend recomputes both axis branches from the birth chart.
struct MidpointPairRequest: Codable, Hashable {
    let pointAID: String
    let pointBID: String

    init(pointAID: String, pointBID: String) {
        let ordered = [pointAID, pointBID].sorted()
        self.pointAID = ordered[0]
        self.pointBID = ordered[1]
    }

    var axisID: String { "midpoint|\(pointAID)|\(pointBID)" }

    enum CodingKeys: String, CodingKey {
        case pointAID = "point_a_id"
        case pointBID = "point_b_id"
    }
}

struct ModernPointSet: Codable {
    let bodyIDs: [String]
    let includeNodes: Bool
    let nodeMode: String
    let customAsteroids: [Int]
    let angleIDs: [String]
    let houseCusps: [Int]
    let lotIDs: [String]
    let midpointPairs: [MidpointPairRequest]?
    let resolvedBodyIDs: [String]?

    init(
        bodyIDs: [String],
        includeNodes: Bool,
        nodeMode: String,
        customAsteroids: [Int],
        angleIDs: [String],
        houseCusps: [Int] = [],
        lotIDs: [String] = [],
        midpointPairs: [MidpointPairRequest]? = nil,
        resolvedBodyIDs: [String]? = nil
    ) {
        self.bodyIDs = bodyIDs
        self.includeNodes = includeNodes
        self.nodeMode = nodeMode
        self.customAsteroids = customAsteroids
        self.angleIDs = angleIDs
        self.houseCusps = houseCusps
        self.lotIDs = lotIDs
        self.midpointPairs = midpointPairs
        self.resolvedBodyIDs = resolvedBodyIDs
    }

    enum CodingKeys: String, CodingKey {
        case bodyIDs = "body_ids"
        case includeNodes = "include_nodes"
        case nodeMode = "node_mode"
        case customAsteroids = "custom_asteroids"
        case angleIDs = "angle_ids"
        case houseCusps = "house_cusps"
        case lotIDs = "lot_ids"
        case midpointPairs = "midpoint_pairs"
        case resolvedBodyIDs = "resolved_body_ids"
    }
}

/// Request contract for standalone 360° midpoint axes, trees and reference
/// snapshot activations. Reference remains optional by contract.
struct MidpointRequest: Codable {
    let mode: String
    let birth: BirthSettings
    let reference: ChartMoment?
    let pointSet: ModernPointSet
    let focusPointIDs: [String]
    let activationSources: [String]
    let activationOrb: Double
    let modulus: Int
    let includeOppositeAxis: Bool
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "midpoint",
        birth: BirthSettings,
        reference: ChartMoment?,
        pointSet: ModernPointSet,
        focusPointIDs: [String],
        activationSources: [String],
        activationOrb: Double = 1.0,
        modulus: Int = 360,
        includeOppositeAxis: Bool = true,
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.birth = birth
        self.reference = reference
        self.pointSet = pointSet
        self.focusPointIDs = focusPointIDs
        self.activationSources = activationSources
        self.activationOrb = activationOrb
        self.modulus = modulus
        self.includeOppositeAxis = includeOppositeAxis
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode, birth, reference, modulus
        case pointSet = "point_set"
        case focusPointIDs = "focus_point_ids"
        case activationSources = "activation_sources"
        case activationOrb = "activation_orb"
        case includeOppositeAxis = "include_opposite_axis"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

struct TransitRequest: Codable {
    let mode: String
    let natal: ChartMoment
    let transit: ChartMoment
    let birth: BirthSettings?
    let natalBodies: [String]
    let transitBodies: [String]
    let customAsteroids: [Int]
    let aspects: [AspectRequest]
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String
    let sameChart: Bool
    let nodeMode: String?
    let pointSet: ModernPointSet?
    let patternsEnabled: Bool?

    init(
        mode: String,
        natal: ChartMoment,
        transit: ChartMoment,
        birth: BirthSettings?,
        natalBodies: [String],
        transitBodies: [String],
        customAsteroids: [Int],
        aspects: [AspectRequest],
        ephemerisPath: String?,
        noAsteroids: Bool,
        requireEphemeris: String,
        sameChart: Bool,
        nodeMode: String? = nil,
        pointSet: ModernPointSet? = nil,
        patternsEnabled: Bool? = nil
    ) {
        self.mode = mode
        self.natal = natal
        self.transit = transit
        self.birth = birth
        self.natalBodies = natalBodies
        self.transitBodies = transitBodies
        self.customAsteroids = customAsteroids
        self.aspects = aspects
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
        self.sameChart = sameChart
        self.nodeMode = nodeMode
        self.pointSet = pointSet
        self.patternsEnabled = patternsEnabled
    }

    enum CodingKeys: String, CodingKey {
        case mode, natal, transit, birth
        case natalBodies, transitBodies, customAsteroids, aspects
        case ephemerisPath, noAsteroids, requireEphemeris, sameChart, nodeMode
        case pointSet = "point_set"
        case patternsEnabled = "patterns_enabled"
    }
}

struct ScanRequest: Codable {
    let mode: String
    let scanKind: String
    let label: String
    let start: ChartMoment
    let end: ChartMoment
    let transitBodies: [String]
    let customAsteroids: [Int]
    let aspects: [AspectRequest]
    let targetText: String
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String
    let moonFilter: String
    let confirmedHeavyScan: Bool
    let zodiac: String
}

/// One independently configured technique in a modern timing request.
/// Aspect/orb settings deliberately live here rather than at request level.
struct ModernTimingTechniqueRequest: Codable {
    let id: String
    let movingBodyIDs: [String]
    let eventTypes: [String]
    let aspects: [AspectRequest]

    enum CodingKeys: String, CodingKey {
        case id
        case movingBodyIDs = "moving_body_ids"
        case eventTypes = "event_types"
        case aspects
    }
}

/// Optional target chart for a `modern_timing` relationship query. Natal
/// timing keeps its existing top-level `target_point_set`; relationship
/// timing makes this nested point set authoritative.
struct ModernTimingTargetChart: Codable {
    let type: String
    let personA: PersonSettings
    let personB: PersonSettings
    let pointSet: ModernPointSet
    let houseSystem: String?
    let zodiac: String?

    init(
        type: String,
        personA: PersonSettings,
        personB: PersonSettings,
        pointSet: ModernPointSet,
        houseSystem: String? = nil,
        zodiac: String? = nil
    ) {
        self.type = type
        self.personA = personA
        self.personB = personB
        self.pointSet = pointSet
        self.houseSystem = houseSystem
        self.zodiac = zodiac
    }

    enum CodingKeys: String, CodingKey {
        case type
        case personA = "person_a"
        case personB = "person_b"
        case pointSet = "point_set"
        case houseSystem = "house_system"
        case zodiac
    }
}

/// Request contract for the independent `modern_timing` backend mode.
/// Birth/start/end remain exact chart moments for B3; uncertain birth-time
/// degradation is intentionally outside this batch.
struct ModernTimingRequest: Codable {
    let mode: String
    let birth: BirthSettings
    let start: ChartMoment
    let end: ChartMoment
    let displayTimezone: String
    let targetPointSet: ModernPointSet?
    let targetChart: ModernTimingTargetChart?
    let techniques: [ModernTimingTechniqueRequest]
    let confirmedHeavyScan: Bool
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "modern_timing",
        birth: BirthSettings,
        start: ChartMoment,
        end: ChartMoment,
        displayTimezone: String,
        targetPointSet: ModernPointSet? = nil,
        targetChart: ModernTimingTargetChart? = nil,
        techniques: [ModernTimingTechniqueRequest],
        confirmedHeavyScan: Bool = false,
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.birth = birth
        self.start = start
        self.end = end
        self.displayTimezone = displayTimezone
        self.targetPointSet = targetPointSet
        self.targetChart = targetChart
        self.techniques = techniques
        self.confirmedHeavyScan = confirmedHeavyScan
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case birth
        case start
        case end
        case displayTimezone = "display_timezone"
        case targetPointSet = "target_point_set"
        case targetChart = "target_chart"
        case techniques
        case confirmedHeavyScan = "confirmed_heavy_scan"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

struct BirthSettings: Codable {
    let moment: ChartMoment
    let latitude: Double
    let longitude: Double
    let houseSystem: String
    let zodiac: String
    let boundsSystem: String
    let triplicitySystem: String
}

/// Optional location used to build the return chart's houses and angles.
/// The exact return instant is always solved independently from this location.
struct ModernReturnLocation: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case name
        case latitude
        case longitude
        case timezone
    }
}

/// Request contract for the modern solar/lunar return backend mode.
/// `location` is sent only when `locationSource` is `custom`.
struct ModernReturnRequest: Codable {
    let mode: String
    let returnBodyID: String
    let birth: BirthSettings
    let reference: ChartMoment
    let locationSource: String
    let location: ModernReturnLocation?
    let houseSystem: String
    let zodiac: String
    let nodeMode: String
    let pointSet: ModernPointSet?
    let aspects: [AspectRequest]
    let precessionCorrection: String
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "modern_return",
        returnBodyID: String,
        birth: BirthSettings,
        reference: ChartMoment,
        locationSource: String,
        location: ModernReturnLocation? = nil,
        houseSystem: String,
        zodiac: String,
        nodeMode: String,
        pointSet: ModernPointSet? = nil,
        aspects: [AspectRequest],
        precessionCorrection: String = "none",
        ephemerisPath: String?,
        noAsteroids: Bool,
        requireEphemeris: String
    ) {
        self.mode = mode
        self.returnBodyID = returnBodyID
        self.birth = birth
        self.reference = reference
        self.locationSource = locationSource
        self.location = location
        self.houseSystem = houseSystem
        self.zodiac = zodiac
        self.nodeMode = nodeMode
        self.pointSet = pointSet
        self.aspects = aspects
        self.precessionCorrection = precessionCorrection
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case returnBodyID = "return_body_id"
        case birth
        case reference
        case locationSource = "location_source"
        case location
        case houseSystem = "house_system"
        case zodiac
        case nodeMode = "node_mode"
        case pointSet = "point_set"
        case aspects
        case precessionCorrection = "precession_correction"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

struct HoraryChartSettings: Codable {
    let moment: ChartMoment
    let latitude: Double
    let longitude: Double
    let houseSystem: String
    let zodiac: String
    let boundsSystem: String
    let triplicitySystem: String
}

struct ClassicalRequest: Codable {
    let mode: String
    let birth: BirthSettings
    let reference: ChartMoment
    let aspectOrb: Double
    let returnMode: String?
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    enum CodingKeys: String, CodingKey {
        case mode
        case birth
        case reference
        case aspectOrb = "aspectOrb"
        case returnMode = "returnMode"
        case ephemerisPath = "ephemerisPath"
        case noAsteroids = "noAsteroids"
        case requireEphemeris = "requireEphemeris"
    }
}

struct HoraryRequest: Codable {
    let mode: String
    let chart: HoraryChartSettings
    let placeName: String
    let questionText: String
    let aspectOrb: Double
    /// Canonical packet is v2 (`"2"`). Use `"1"` / `"legacy"` only for the deprecated interpretive adapter.
    let packetVersion: String
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    enum CodingKeys: String, CodingKey {
        case mode, chart, placeName, questionText, aspectOrb
        case packetVersion
        case ephemerisPath, noAsteroids, requireEphemeris
    }

    init(
        mode: String,
        chart: HoraryChartSettings,
        placeName: String,
        questionText: String,
        aspectOrb: Double,
        packetVersion: String = "2",
        ephemerisPath: String?,
        noAsteroids: Bool,
        requireEphemeris: String
    ) {
        self.mode = mode
        self.chart = chart
        self.placeName = placeName
        self.questionText = questionText
        self.aspectOrb = aspectOrb
        self.packetVersion = packetVersion
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }
}

struct VedicRequest: Codable {
    let mode: String
    let birth: BirthSettings
    let reference: ChartMoment?
    let full: Bool
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    enum CodingKeys: String, CodingKey {
        case mode, birth, reference, full
        case ephemerisPath = "ephemerisPath"
        case noAsteroids = "noAsteroids"
        case requireEphemeris = "requireEphemeris"
    }
}

struct NatalProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var moment: ChartMoment
    var latitude: String
    var longitude: String
    var gmtOffset: Double
    var chartStyle: String
    var houseSystem: String
    var zodiac: String
    var boundsSystem: String
    var triplicitySystem: String
}

struct MomentPreset: Codable, Identifiable {
    let id: UUID
    var name: String
    var templateText: String
}

struct ScanPreset: Codable, Identifiable {
    let id: UUID
    var name: String
    var templateText: String
}
