import Foundation

struct KPHoraryResult: Codable {
    let mode: String
    let schema: KPSchema
    let question: KPQuestion
    let timeAndLocation: KPTimeAndLocation
    let calculationConfig: KPCalculationConfig
    let horaryNumber: KPHoraryNumber
    let houseSolution: KPHouseSolution
    let angles: [KPAngle]
    let planets: [KPPlanet]
    let houses: [KPHouse]
    let rulingPlanets: [KPRulingPlanet]
    let planetSignificators: [KPPlanetSignificator]
    let houseSignificators: [KPHouseSignificator]
    let focusHouse: KPHouseSignificator
    let nodeRepresentations: [KPNodeRepresentation]
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case mode, schema, question, angles, planets, houses, warnings
        case timeAndLocation = "time_and_location"
        case calculationConfig = "calculation_config"
        case horaryNumber = "horary_number"
        case houseSolution = "house_solution"
        case rulingPlanets = "ruling_planets"
        case planetSignificators = "planet_significators"
        case houseSignificators = "house_significators"
        case focusHouse = "focus_house"
        case nodeRepresentations = "node_representations"
    }
}

struct KPSchema: Codable {
    let name: String
    let version: String
    let schemaID: String

    enum CodingKeys: String, CodingKey {
        case name, version
        case schemaID = "schema_id"
    }
}

struct KPQuestion: Codable {
    let text: String
    let horaryNumber: Int
    let focusHouse: Int
    let placeName: String

    enum CodingKeys: String, CodingKey {
        case text
        case horaryNumber = "horary_number"
        case focusHouse = "focus_house"
        case placeName = "place_name"
    }
}

struct KPTimeAndLocation: Codable {
    let questionLocal: String
    let questionUTC: String
    let houseSolutionUTC: String
    let timezone: String
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case questionLocal = "question_local"
        case questionUTC = "question_utc"
        case houseSolutionUTC = "house_solution_utc"
        case timezone, latitude, longitude
    }
}

struct KPCalculationConfig: Codable {
    let zodiac: String
    let ayanamsha: String
    let ayanamshaDegreesAtQuestion: Double
    let houseSystem: String
    let nodeMode: String
    let planetTimePolicy: String
    let houseTimePolicy: String
    let numberLongitudePolicy: String
    let automaticJudgment: Bool

    enum CodingKeys: String, CodingKey {
        case zodiac, ayanamsha
        case ayanamshaDegreesAtQuestion = "ayanamsha_degrees_at_question"
        case houseSystem = "house_system"
        case nodeMode = "node_mode"
        case planetTimePolicy = "planet_time_policy"
        case houseTimePolicy = "house_time_policy"
        case numberLongitudePolicy = "number_longitude_policy"
        case automaticJudgment = "automatic_judgment"
    }
}

struct KPLord: Codable, Hashable, Identifiable {
    let id: String
    let name: String
}

struct KPNakshatra: Codable {
    let index: Int
    let name: String
    let nameZH: String
    let lord: KPLord
    let pada: Int
    let startLongitude: Double
    let endLongitude: Double

    enum CodingKeys: String, CodingKey {
        case index, name, lord, pada
        case nameZH = "name_zh"
        case startLongitude = "start_longitude"
        case endLongitude = "end_longitude"
    }
}

struct KPSubLord: Codable {
    let id: String
    let name: String
    let startLongitude: Double
    let endLongitude: Double

    enum CodingKeys: String, CodingKey {
        case id, name
        case startLongitude = "start_longitude"
        case endLongitude = "end_longitude"
    }

    var lord: KPLord { KPLord(id: id, name: name) }
}

protocol KPPositionRepresentable {
    var longitude: Double { get }
    var sign: String { get }
    var degreeText: String { get }
    var signLord: KPLord { get }
    var nakshatra: KPNakshatra { get }
    var subLord: KPSubLord { get }
    var subSubLord: KPSubLord { get }
}

struct KPHoraryNumber: Codable, KPPositionRepresentable {
    let number: Int
    let intervalStartLongitude: Double
    let intervalEndLongitude: Double
    let representativeLongitude: Double
    let interiorOffsetDegrees: Double
    let longitude: Double
    let sign: String
    let degreeText: String
    let signLord: KPLord
    let nakshatra: KPNakshatra
    let subLord: KPSubLord
    let subSubLord: KPSubLord

    enum CodingKeys: String, CodingKey {
        case number, longitude, sign, nakshatra
        case intervalStartLongitude = "interval_start_longitude"
        case intervalEndLongitude = "interval_end_longitude"
        case representativeLongitude = "representative_longitude"
        case interiorOffsetDegrees = "interior_offset_degrees"
        case degreeText = "degree_text"
        case signLord = "sign_lord"
        case subLord = "sub_lord"
        case subSubLord = "sub_sub_lord"
    }
}

struct KPHouseSolution: Codable {
    let targetAscendant: Double
    let solvedAscendant: Double
    let residualDegrees: Double
    let evaluations: Int
    let searchWindowDays: Double

    enum CodingKeys: String, CodingKey {
        case targetAscendant = "target_ascendant"
        case solvedAscendant = "solved_ascendant"
        case residualDegrees = "residual_degrees"
        case evaluations
        case searchWindowDays = "search_window_days"
    }
}

struct KPAngle: Codable, Identifiable, KPPositionRepresentable {
    let id: String
    let name: String
    let longitude: Double
    let sign: String
    let degreeText: String
    let signLord: KPLord
    let nakshatra: KPNakshatra
    let subLord: KPSubLord
    let subSubLord: KPSubLord

    enum CodingKeys: String, CodingKey {
        case id, name, longitude, sign, nakshatra
        case degreeText = "degree_text"
        case signLord = "sign_lord"
        case subLord = "sub_lord"
        case subSubLord = "sub_sub_lord"
    }
}

struct KPPlanet: Codable, Identifiable, KPPositionRepresentable {
    let id: String
    let name: String
    let longitude: Double
    let sign: String
    let degreeText: String
    let signLord: KPLord
    let nakshatra: KPNakshatra
    let subLord: KPSubLord
    let subSubLord: KPSubLord
    let house: Int
    let latitude: Double
    let declination: Double
    let speed: Double
    let retrograde: Bool
    let ephemeris: String

    enum CodingKeys: String, CodingKey {
        case id, name, longitude, sign, house, latitude, declination, speed, retrograde, ephemeris, nakshatra
        case degreeText = "degree_text"
        case signLord = "sign_lord"
        case subLord = "sub_lord"
        case subSubLord = "sub_sub_lord"
    }
}

struct KPHouse: Codable, Identifiable, KPPositionRepresentable {
    let house: Int
    let longitude: Double
    let sign: String
    let degreeText: String
    let signLord: KPLord
    let nakshatra: KPNakshatra
    let subLord: KPSubLord
    let subSubLord: KPSubLord

    var id: Int { house }

    enum CodingKeys: String, CodingKey {
        case house, longitude, sign, nakshatra
        case degreeText = "degree_text"
        case signLord = "sign_lord"
        case subLord = "sub_lord"
        case subSubLord = "sub_sub_lord"
    }
}

struct KPRulingPlanet: Codable, Identifiable {
    let source: String
    let planet: KPLord
    var id: String { source }
}

struct KPSignificatorScope: Codable {
    let planet: KPLord
    let occupiedHouse: Int?
    let ownedHouses: [Int]

    enum CodingKeys: String, CodingKey {
        case planet
        case occupiedHouse = "occupied_house"
        case ownedHouses = "owned_houses"
    }
}

struct KPPlanetSignificator: Codable, Identifiable {
    let planet: KPLord
    let direct: KPSignificatorScope
    let starLordScope: KPSignificatorScope
    let subLordScope: KPSignificatorScope
    let candidateHouses: [Int]
    let policy: String

    var id: String { planet.id }

    enum CodingKeys: String, CodingKey {
        case planet, direct, policy
        case starLordScope = "star_lord_scope"
        case subLordScope = "sub_lord_scope"
        case candidateHouses = "candidate_houses"
    }
}

struct KPSignificatorTier: Codable, Identifiable {
    let tier: Int
    let source: String
    let planets: [KPLord]
    var id: String { "\(tier)-\(source)" }
}

struct KPHouseSignificator: Codable, Identifiable {
    let house: Int
    let cuspSignLord: KPLord
    let tiers: [KPSignificatorTier]
    let policy: String

    var id: Int { house }

    enum CodingKeys: String, CodingKey {
        case house, tiers, policy
        case cuspSignLord = "cusp_sign_lord"
    }
}

struct KPNodeRepresentation: Codable, Identifiable {
    let node: KPLord
    let occupiedHouse: Int
    let signLord: KPLord
    let starLord: KPLord
    let subLord: KPLord
    let policy: String

    var id: String { node.id }

    enum CodingKeys: String, CodingKey {
        case node, policy
        case occupiedHouse = "occupied_house"
        case signLord = "sign_lord"
        case starLord = "star_lord"
        case subLord = "sub_lord"
    }
}
