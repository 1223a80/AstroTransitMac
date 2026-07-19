import Foundation

struct ClassicalDerivativesMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let ephemeris: String?
    let dodekaCount: Int?
    let monomoiriaCount: Int?
    let topicalCount: Int?
    enum CodingKeys: String, CodingKey {
        case mode, method, ephemeris
        case schemaVersion = "schema_version"
        case dodekaCount = "dodeka_count"
        case monomoiriaCount = "monomoiria_count"
        case topicalCount = "topical_count"
    }
}

struct DodekatemorionRow: Codable, Identifiable {
    let sourceId: String?
    let sourceName: String?
    let sourceKind: String?
    let natalLongitude: Double?
    let dodekatemorionLongitude: Double?
    let dodekatemorionSignIndex: Int?
    let dodekatemorionRuler: String?
    let sign: String?
    let degreeText: String?
    let house: Int?
    let methodKey: String?
    var id: String { "\(sourceId ?? "")|\(dodekatemorionLongitude.map { String($0) } ?? "")" }
    enum CodingKeys: String, CodingKey {
        case sign, house
        case sourceId = "source_id"
        case sourceName = "source_name"
        case sourceKind = "source_kind"
        case natalLongitude = "natal_longitude"
        case dodekatemorionLongitude = "dodekatemorion_longitude"
        case dodekatemorionSignIndex = "dodekatemorion_sign_index"
        case dodekatemorionRuler = "dodekatemorion_ruler"
        case degreeText = "degree_text"
        case methodKey = "method_key"
    }
}

struct MonomoiriaRow: Codable, Identifiable {
    let sourceId: String?
    let sourceName: String?
    let sourceKind: String?
    let longitude: Double?
    let degreeIndex: Int?
    let monomoiriaRuler: String?
    let methodProfile: String?
    let methodKey: String?
    var id: String { "\(sourceId ?? "")|\(degreeIndex.map(String.init) ?? "")" }
    enum CodingKeys: String, CodingKey {
        case longitude
        case sourceId = "source_id"
        case sourceName = "source_name"
        case sourceKind = "source_kind"
        case degreeIndex = "degree_index"
        case monomoiriaRuler = "monomoiria_ruler"
        case methodProfile = "method_profile"
        case methodKey = "method_key"
    }
}

struct TopicalAlmutenRow: Codable, Identifiable {
    let topicId: String?
    let topicName: String?
    let longitude: Double?
    let winnerId: String?
    let winnerScore: Int?
    let methodKey: String?
    let note: String?
    var id: String { topicId ?? topicName ?? UUID().uuidString }
    enum CodingKeys: String, CodingKey {
        case longitude, note
        case topicId = "topic_id"
        case topicName = "topic_name"
        case winnerId = "winner_id"
        case winnerScore = "winner_score"
        case methodKey = "method_key"
    }
}

struct ClassicalDerivativesResult: Codable {
    let meta: ClassicalDerivativesMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let dodekatemoria: [DodekatemorionRow]
    let dodekatemoriaContacts: [NestedJSON]?
    let monomoiria: [MonomoiriaRow]
    let topicalAlmutens: [TopicalAlmutenRow]
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, warnings, dodekatemoria, monomoiria
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case dodekatemoriaContacts = "dodekatemoria_contacts"
        case topicalAlmutens = "topical_almutens"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
