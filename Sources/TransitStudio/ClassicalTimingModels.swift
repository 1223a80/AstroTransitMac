import Foundation

struct TimingSummary: Codable {
    let profection: ProfectionSummary
    let firdaria: PeriodSummary
    let decennials: PeriodSummary
    let zodiacalReleasing: [ZRSummary]
    let timeline: [TimingTimelineItem]

    enum CodingKeys: String, CodingKey {
        case profection
        case firdaria
        case decennials
        case zodiacalReleasing = "zodiacal_releasing"
        case timeline
    }
}

struct ProfectionSummary: Codable {
    let age: Int
    let house: Int
    let sign: String
    let lord: String
    let lordCondition: String
    let startLocal: String
    let endLocal: String
    let startUTC: String?
    let endUTC: String?
    let activatedPlanets: [String]
    let logicSteps: [String]
    let monthly: MonthlyProfection?
    let profectedAscLongitude: Double?
    let profectedAscSign: String?

    enum CodingKeys: String, CodingKey {
        case age
        case house
        case sign
        case lord
        case lordCondition = "lord_condition"
        case startLocal = "start_local"
        case endLocal = "end_local"
        case startUTC = "start_utc"
        case endUTC = "end_utc"
        case activatedPlanets = "activated_planets"
        case logicSteps = "logic_steps"
        case monthly
        case profectedAscLongitude = "profected_asc_longitude"
        case profectedAscSign = "profected_asc_sign"
    }
}

struct MonthlyProfection: Codable {
    let month: Int
    let house: Int?
    let sign: String
    let lord: String
    let lordId: String?
    let lordCondition: String?
    let startLocal: String?
    let endLocal: String?

    enum CodingKeys: String, CodingKey {
        case month
        case house
        case sign
        case lord
        case lordId = "lord_id"
        case lordCondition = "lord_condition"
        case startLocal = "start_local"
        case endLocal = "end_local"
    }
}

struct PeriodSummary: Codable, Identifiable {
    let id: String
    let technique: String
    let level: String
    let ruler: String
    let sign: String?
    let startLocal: String
    let endLocal: String
    let nextTransition: String?
    let activatedHouses: [Int]?
    let notes: [String]
    let subPeriods: [FirdariaSubPeriod]?
    let currentSubPeriod: FirdariaSubPeriod?
    let planetaryYears: [String: Int]?
    let method: String?
    let sourceTradition: String?

    enum CodingKeys: String, CodingKey {
        case id
        case technique
        case level
        case ruler
        case sign
        case startLocal = "start_local"
        case endLocal = "end_local"
        case nextTransition = "next_transition"
        case activatedHouses = "activated_houses"
        case notes
        case subPeriods = "sub_periods"
        case currentSubPeriod = "current_sub_period"
        case planetaryYears = "planetary_years"
        case method = "_method"
        case sourceTradition = "_source_tradition"
    }
}

struct FirdariaSubPeriod: Codable, Identifiable {
    let id: String
    let ruler: String
    let startLocal: String
    let endLocal: String
    let fraction: Double

    enum CodingKeys: String, CodingKey {
        case id
        case ruler
        case startLocal = "start_local"
        case endLocal = "end_local"
        case fraction
    }
}

struct ZRSummary: Codable, Identifiable {
    let id: String
    let technique: String
    let level: String
    let ruler: String
    let sign: String?
    let startLocal: String
    let endLocal: String
    let nextTransition: String?
    let importanceScore: Int?
    let notes: [String]
    let currentActiveLevel: String?
    let lotAngularity: String?
    let l1Periods: [ZRPeriod]?
    let l2Periods: [ZRPeriod]?
    let l3Periods: [ZRPeriod]?
    let loosingOfBond: Bool?
    let loosingOfBondDetail: String?
    let loosingOfBondLevel: String?
    let method: String?
    let sourceTradition: String?

    enum CodingKeys: String, CodingKey {
        case id
        case technique
        case level
        case ruler
        case sign
        case startLocal = "start_local"
        case endLocal = "end_local"
        case nextTransition = "next_transition"
        case importanceScore = "importance_score"
        case notes
        case currentActiveLevel = "current_active_level"
        case lotAngularity = "lot_angularity"
        case l1Periods = "l1_periods"
        case l2Periods = "l2_periods"
        case l3Periods = "l3_periods"
        case loosingOfBond = "loosing_of_bond"
        case loosingOfBondDetail = "loosing_of_bond_detail"
        case loosingOfBondLevel = "loosing_of_bond_level"
        case method = "_method"
        case sourceTradition = "_source_tradition"
    }
}

struct ZRPeriod: Codable, Identifiable {
    let level: String
    let sign: String
    let signIndex: Int?
    let ruler: String
    let years: Double
    let startLocal: String
    let endLocal: String
    let isActive: Bool?
    let subPeriods: [ZRPeriod]?

    var id: String { "\(level)-\(sign)-\(startLocal)" }

    enum CodingKeys: String, CodingKey {
        case level
        case sign
        case signIndex = "sign_index"
        case ruler
        case years
        case startLocal = "start_local"
        case endLocal = "end_local"
        case isActive = "is_active"
        case subPeriods = "sub_periods"
    }
}

struct ReturnChartSnapshot: Codable, Identifiable {
    let label: String
    let exactLocal: String
    let exactUTC: String
    let ascendant: String
    let midheaven: String
    let sect: String
    let houseSystem: String
    let returnChartRuler: String?
    let returnChartRulerId: String?
    let angularPlanets: [String]?
    let activatedNatalPoints: [String]?
    let angles: [ClassicalPoint]
    let houses: [HouseRow]
    let planets: [ClassicalPlanetRow]
    let natalCrossAspects: [ReturnCrossAspect]
    let profectedAscSign: String?
    let profectedAscHouse: Int?
    let returnAscInNatalHouse: Int?
    let houseOverlay: [HouseOverlay]?

    var id: String { "\(label):\(exactLocal)" }

    enum CodingKeys: String, CodingKey {
        case label
        case exactLocal = "exact_local"
        case exactUTC = "exact_utc"
        case ascendant
        case midheaven
        case sect
        case houseSystem = "house_system"
        case returnChartRuler = "return_chart_ruler"
        case returnChartRulerId = "return_chart_ruler_id"
        case angularPlanets = "angular_planets"
        case activatedNatalPoints = "activated_natal_points"
        case angles
        case houses
        case planets
        case natalCrossAspects = "natal_cross_aspects"
        case profectedAscSign = "profected_asc_sign"
        case profectedAscHouse = "profected_asc_house"
        case returnAscInNatalHouse = "return_asc_in_natal_house"
        case houseOverlay = "house_overlay"
    }
}

struct SolarReturnSummary: Codable, Identifiable {
    let id: String
    let bodyID: String
    let bodyName: String
    let title: String
    let noHitInUserWindow: Bool?
    let suggestedWindow: String?
    let previousReturn: ReturnChartSnapshot?
    let currentCycleReturn: ReturnChartSnapshot?
    let nextReturn: ReturnChartSnapshot?
    let searchStartLocal: String
    let searchEndLocal: String

    enum CodingKeys: String, CodingKey {
        case id
        case bodyID = "body_id"
        case bodyName = "body_name"
        case title
        case noHitInUserWindow = "no_hit_in_user_window"
        case suggestedWindow = "suggested_window"
        case previousReturn = "previous_return"
        case currentCycleReturn = "current_cycle_return"
        case nextReturn = "next_return"
        case searchStartLocal = "search_start_local"
        case searchEndLocal = "search_end_local"
    }
}

struct HouseOverlay: Codable, Identifiable {
    let id: String
    let planet: String
    let returnHouse: Int
    let natalHouse: Int

    enum CodingKeys: String, CodingKey {
        case id
        case planet
        case returnHouse = "return_house"
        case natalHouse = "natal_house"
    }
}

struct TimingTimelineItem: Codable, Identifiable {
    let id: String
    let title: String
    let startLocal: String
    let endLocal: String
    let kind: String
    let technique: String?
    let layer: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startLocal = "start_local"
        case endLocal = "end_local"
        case kind
        case technique
        case layer
    }
}

struct ReturnCrossAspect: Codable, Identifiable {
    let id: String
    let leftBodyID: String
    let leftBodyName: String
    let rightBodyID: String
    let rightBodyName: String
    let leftLabel: String
    let rightLabel: String
    let aspect: String
    let aspectGeometry: String?
    let aspectKind: String?
    let orb: Double?
    let applying: String?
    let isDegreeAspect: Bool?
    let isWholeSignAspect: Bool?
    let isCoPresence: Bool?
    let displayLabelZh: String?
    let displayLabelEn: String?

    enum CodingKeys: String, CodingKey {
        case id
        case leftBodyID = "left_body_id"
        case leftBodyName = "left_body_name"
        case rightBodyID = "right_body_id"
        case rightBodyName = "right_body_name"
        case leftLabel = "left_label"
        case rightLabel = "right_label"
        case aspect
        case aspectGeometry = "aspect_geometry"
        case aspectKind = "aspect_kind"
        case orb
        case applying
        case isDegreeAspect = "is_degree_aspect"
        case isWholeSignAspect = "is_whole_sign_aspect"
        case isCoPresence = "is_co_presence"
        case displayLabelZh = "display_label_zh"
        case displayLabelEn = "display_label_en"
    }
}
