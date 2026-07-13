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

struct ModernPointSet: Codable {
    let bodyIDs: [String]
    let includeNodes: Bool
    let nodeMode: String
    let customAsteroids: [Int]
    let angleIDs: [String]
    let houseCusps: [Int]
    let lotIDs: [String]
    let resolvedBodyIDs: [String]?

    init(
        bodyIDs: [String],
        includeNodes: Bool,
        nodeMode: String,
        customAsteroids: [Int],
        angleIDs: [String],
        houseCusps: [Int] = [],
        lotIDs: [String] = [],
        resolvedBodyIDs: [String]? = nil
    ) {
        self.bodyIDs = bodyIDs
        self.includeNodes = includeNodes
        self.nodeMode = nodeMode
        self.customAsteroids = customAsteroids
        self.angleIDs = angleIDs
        self.houseCusps = houseCusps
        self.lotIDs = lotIDs
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
        case resolvedBodyIDs = "resolved_body_ids"
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

struct BirthSettings: Codable {
    let moment: ChartMoment
    let latitude: Double
    let longitude: Double
    let houseSystem: String
    let zodiac: String
    let boundsSystem: String
    let triplicitySystem: String
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
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String
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
