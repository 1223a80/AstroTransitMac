import Foundation

struct PrenatalSyzygy: Codable {
    let syzygyType: String?
    let exactUTC: String?
    let longitude: Double?
    let sunPosition: Double?
    let moonPosition: Double?
    let sign: String?
    let degree: Double?
    let ruler: String?
    let rulerId: String?
    let syzygyDegreeUsed: String?
    let method: String?
    let methodVariant: String?
    let sourceTradition: String?

    enum CodingKeys: String, CodingKey {
        case syzygyType = "syzygy_type"
        case exactUTC = "exact_utc"
        case longitude
        case sunPosition = "sun_position"
        case moonPosition = "moon_position"
        case sign
        case degree
        case ruler
        case rulerId = "ruler_id"
        case syzygyDegreeUsed = "syzygy_degree_used"
        case method = "_method"
        case methodVariant = "method_variant"
        case sourceTradition = "_source_tradition"
    }
}

struct AlmutenScoreEntry: Codable, Identifiable {
    let planet: String
    let total: Int
    let contributions: [AlmutenContribution]

    var id: String { planet }
}

struct AlmutenContribution: Codable, Identifiable {
    let point: String
    let dignity: String
    let weight: Int

    var id: String { "\(point):\(dignity):\(weight)" }
}

struct AlmutenFiguris: Codable {
    let winner: String?
    let winnerId: String?
    let scoreTable: [AlmutenScoreEntry]?
    let pointsUsed: [String]?
    let method: String?
    let methodVariant: String?
    let confidence: String?
    let sourceTradition: String?

    enum CodingKeys: String, CodingKey {
        case winner
        case winnerId = "winner_id"
        case scoreTable = "score_table"
        case pointsUsed = "points_used"
        case method
        case methodVariant = "method_variant"
        case confidence
        case sourceTradition = "_source_tradition"
    }
}

struct HylegCandidate: Codable, Identifiable {
    let name: String
    let eligible: Bool?
    let reason: String
    let house: Int?
    let hylegicalPlacePass: String?
    let sectRelevance: String?
    let visibility: String?
    let finalRank: Int?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case eligible
        case reason
        case house
        case hylegicalPlacePass = "hylegical_place_pass"
        case sectRelevance = "sect_relevance"
        case visibility
        case finalRank = "final_rank"
    }
}

struct AlcocodenCandidate: Codable, Identifiable {
    let planet: String
    let planetId: String
    let dignityAtHyleg: String
    let weight: Int
    let seesHyleg: Bool?
    let aspectToHyleg: Double?
    let ownConditionScore: Int
    let ownConditionSummary: String?
    let rank: Int?
    let reason: String?

    var id: String { planetId }

    enum CodingKeys: String, CodingKey {
        case planet
        case planetId = "planet_id"
        case dignityAtHyleg = "dignity_at_hyleg"
        case weight
        case seesHyleg = "sees_hyleg"
        case aspectToHyleg = "aspect_to_hyleg"
        case ownConditionScore = "own_condition_score"
        case ownConditionSummary = "own_condition_summary"
        case rank
        case reason
    }
}

struct HylegInfo: Codable {
    let selected: String?
    let selectedId: String?
    let longitude: Double?
    let reason: String?
    let candidates: [HylegCandidate]?

    enum CodingKeys: String, CodingKey {
        case selected
        case selectedId = "selected_id"
        case longitude
        case reason
        case candidates
    }
}

struct AlcocodenInfo: Codable {
    let selected: String?
    let selectedId: String?
    let dignity: String?
    let candidates: [AlcocodenCandidate]?

    enum CodingKeys: String, CodingKey {
        case selected
        case selectedId = "selected_id"
        case dignity
        case candidates
    }
}

struct HylegAlcocoden: Codable {
    let hyleg: HylegInfo?
    let alcocoden: AlcocodenInfo?
    let longevityYears: Int?
    let warning: String?
    let method: String?
    let methodVariant: String?
    let sourceTradition: String?

    enum CodingKeys: String, CodingKey {
        case hyleg
        case alcocoden
        case longevityYears = "longevity_years"
        case warning
        case method
        case methodVariant = "method_variant"
        case sourceTradition = "_source_tradition"
    }
}
