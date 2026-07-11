import Foundation

struct HoraryMeta: Codable {
    let askedLocal: String
    let askedUTC: String
    let placeName: String
    let latitude: Double
    let longitude: Double
    let sect: String
    let sunHorizonStatus: String
    let houseSystem: String
    let zodiac: String
    let boundsSystem: String
    let triplicitySystem: String
    let aspectOrb: Double?
    let ephemeris: String

    enum CodingKeys: String, CodingKey {
        case askedLocal = "asked_local"
        case askedUTC = "asked_utc"
        case placeName = "place_name"
        case latitude
        case longitude
        case sect
        case sunHorizonStatus = "sun_horizon_status"
        case houseSystem = "house_system"
        case zodiac
        case boundsSystem = "bounds_system"
        case triplicitySystem = "triplicity_system"
        case aspectOrb = "aspect_orb"
        case ephemeris
    }
}

struct HoraryAdvancedResult: Codable, Identifiable {
    let id: String
    let type: String
    let status: String
    let details: String
    let planets: [String]
    let exactTime: String?
    let translator: String?
    let collector: String?
    let prohibitor: String?
    let frustratedPlanet: String?
    let frustratingPlanet: String?
    let from: String?
    let to: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case status
        case details
        case planets
        case exactTime = "exact_time"
        case translator
        case collector
        case prohibitor
        case frustratedPlanet = "frustrated_planet"
        case frustratingPlanet = "frustrating_planet"
        case from
        case to
        case reason
    }
}
