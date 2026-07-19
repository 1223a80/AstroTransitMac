
import Foundation

struct ExpansionGenericRequest: Codable {
    let mode: String
    let birth: BirthSettings?
    let reference: ChartMoment?
    let start: ChartMoment?
    let end: ChartMoment?
    let displayTimezone: String?
    let location: GeoPlace?
    let bodyIDs: [String]?
    let modulus: Int?
    let maxAge: Int?
    let topicHouse: Int?
    let scanStepHours: Double?
    let solarArcRateDegPerYear: Double?
    let aspectOrb: Double?
    let significators: [String]?
    let paranRaOrbDeg: Double?
    let pictureOrb: Double?
    let houseSystem: String?
    let zodiac: String?
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String,
        birth: BirthSettings? = nil,
        reference: ChartMoment? = nil,
        start: ChartMoment? = nil,
        end: ChartMoment? = nil,
        displayTimezone: String? = nil,
        location: GeoPlace? = nil,
        bodyIDs: [String]? = nil,
        modulus: Int? = nil,
        maxAge: Int? = nil,
        topicHouse: Int? = nil,
        scanStepHours: Double? = nil,
        solarArcRateDegPerYear: Double? = nil,
        aspectOrb: Double? = nil,
        significators: [String]? = nil,
        paranRaOrbDeg: Double? = nil,
        pictureOrb: Double? = nil,
        houseSystem: String? = nil,
        zodiac: String? = nil,
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.birth = birth
        self.reference = reference
        self.start = start
        self.end = end
        self.displayTimezone = displayTimezone
        self.location = location
        self.bodyIDs = bodyIDs
        self.modulus = modulus
        self.maxAge = maxAge
        self.topicHouse = topicHouse
        self.scanStepHours = scanStepHours
        self.solarArcRateDegPerYear = solarArcRateDegPerYear
        self.aspectOrb = aspectOrb
        self.significators = significators
        self.paranRaOrbDeg = paranRaOrbDeg
        self.pictureOrb = pictureOrb
        self.houseSystem = houseSystem
        self.zodiac = zodiac
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode, birth, reference, start, end, location, modulus, significators, zodiac
        case displayTimezone = "display_timezone"
        case bodyIDs = "body_ids"
        case maxAge = "max_age"
        case topicHouse = "topic_house"
        case scanStepHours = "scan_step_hours"
        case solarArcRateDegPerYear = "solar_arc_rate_deg_per_year"
        case aspectOrb = "aspect_orb"
        case paranRaOrbDeg = "paran_ra_orb_deg"
        case pictureOrb = "picture_orb"
        case houseSystem = "house_system"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}
