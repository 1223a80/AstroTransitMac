import Foundation

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

struct NatalProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var moment: ChartMoment
    var latitude: String
    var longitude: String
    var gmtOffset: Int
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
