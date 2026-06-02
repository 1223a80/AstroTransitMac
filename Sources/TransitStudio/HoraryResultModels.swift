import Foundation

struct HoraryResult: Codable {
    let meta: HoraryMeta
    let questionText: String
    let houseRulers: [HoraryHouseRuler]
    let machineSummary: [String]
    let moonStoryline: HoraryMoonStoryline
    let radicalityFlags: [HoraryFlag]
    let moonVocCriterion: String
    let significatorCandidates: [HorarySignificatorCandidate]
    let keySignificatorLinks: [HorarySignificatorLink]
    let degreeBasedKeyAspects: [HoraryKeyAspect]
    let planetarySpeeds: [HoraryPlanetSpeed]
    let solarCondition: [HorarySolarCondition]
    let negativeReceptions: [HoraryNegativeReception]
    let lotsSummary: [HoraryLotSummary]
    let advancedCandidates: [HoraryAdvancedCandidate]
    let angles: [ClassicalPoint]
    let houses: [HouseRow]
    let planets: [ClassicalPlanetRow]
    let lots: [ClassicalPoint]
    let aspects: [ClassicalAspectRow]
    let receptions: [ReceptionRow]
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case meta
        case questionText = "question_text"
        case houseRulers = "house_rulers"
        case machineSummary = "machine_summary"
        case moonStoryline = "moon_storyline"
        case radicalityFlags = "radicality_flags"
        case moonVocCriterion = "moon_voc_criterion"
        case significatorCandidates = "significator_candidates"
        case keySignificatorLinks = "key_significator_links"
        case degreeBasedKeyAspects = "degree_based_key_aspects"
        case planetarySpeeds = "planetary_speeds"
        case solarCondition = "solar_condition"
        case negativeReceptions = "negative_receptions"
        case lotsSummary = "lots_summary"
        case advancedCandidates = "advanced_candidates"
        case angles
        case houses
        case planets
        case lots
        case aspects
        case receptions
        case warnings
    }
}
struct HoraryHouseRuler: Codable, Identifiable {
    let house: Int
    let sign: String
    let ruler: String

    var id: Int { house }
}

struct HoraryAspectEvent: Codable, Identifiable {
    let id: String
    let targetID: String
    let targetName: String
    let aspectID: String
    let aspectName: String
    let exactLocal: String
    let moonLongitude: Double
    let targetLongitude: Double
    let moonHouse: Int
    let targetHouse: Int

    enum CodingKeys: String, CodingKey {
        case id
        case targetID = "target_id"
        case targetName = "target_name"
        case aspectID = "aspect_id"
        case aspectName = "aspect_name"
        case exactLocal = "exact_local"
        case moonLongitude = "moon_longitude"
        case targetLongitude = "target_longitude"
        case moonHouse = "moon_house"
        case targetHouse = "target_house"
    }
}

struct HoraryMoonStoryline: Codable {
    let currentPosition: String
    let currentHouse: Int
    let lastAspect: HoraryAspectEvent?
    let lastAspectTime: String
    let nextAspect: HoraryAspectEvent?
    let nextAspectTime: String
    let upcomingAspects: [HoraryAspectEvent]
    let beforeSignExitAspects: [HoraryAspectEvent]
    let voc: Bool
    let signExitLocal: String
    let nextSign: String
    let nextSignIngressTime: String
    let firstAfterIngress: HoraryAspectEvent?
    let firstAfterIngressTime: String

    enum CodingKeys: String, CodingKey {
        case currentPosition = "current_position"
        case currentHouse = "current_house"
        case lastAspect = "last_aspect"
        case lastAspectTime = "last_aspect_time"
        case nextAspect = "next_aspect"
        case nextAspectTime = "next_aspect_time"
        case upcomingAspects = "upcoming_aspects"
        case beforeSignExitAspects = "before_sign_exit_aspects"
        case voc
        case signExitLocal = "sign_exit_local"
        case nextSign = "next_sign"
        case nextSignIngressTime = "next_sign_ingress_time"
        case firstAfterIngress = "first_after_ingress"
        case firstAfterIngressTime = "first_after_ingress_time"
    }
}

struct HoraryFlag: Codable, Identifiable {
    let id: String
    let label: String
    let severity: String
}

struct HorarySignificatorCandidate: Codable, Identifiable {
    let id: String
    let role: String
    let planet: String
    let source: String
    let position: String
    let house: Int
    let condition: String
    let planetID: String

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case planet
        case source
        case position
        case house
        case condition
        case planetID = "planet_id"
    }
}

struct HorarySignificatorLink: Codable, Identifiable {
    let id: String
    let pair: String
    let aspect: String
    let type: String
    let orb: Double?
    let applying: String
    let perfectsBeforeSignExit: Bool
    let nextPerfection: String
    let perfectionReason: String
    let reception: String

    enum CodingKeys: String, CodingKey {
        case id
        case pair
        case aspect
        case type
        case orb
        case applying
        case perfectsBeforeSignExit = "perfects_before_sign_exit"
        case nextPerfection = "next_perfection"
        case perfectionReason = "perfection_reason"
        case reception
    }
}

struct HoraryKeyAspect: Codable, Identifiable {
    let id: String
    let bodyA: String
    let aspect: String
    let bodyB: String
    let orb: Double?
    let applying: String
    let exactTime: String

    enum CodingKeys: String, CodingKey {
        case id
        case bodyA = "body_a"
        case aspect
        case bodyB = "body_b"
        case orb
        case applying
        case exactTime = "exact_time"
    }
}

struct HoraryLotSummary: Codable, Identifiable {
    let id: String
    let lot: String
    let position: String
    let house: Int
    let ruler: String
    let rulerCondition: String
    let keyNotes: String

    enum CodingKeys: String, CodingKey {
        case id
        case lot
        case position
        case house
        case ruler
        case rulerCondition = "ruler_condition"
        case keyNotes = "key_notes"
    }
}

struct HoraryPlanetSpeed: Codable, Identifiable {
    let id: String
    let planet: String
    let speed: Double
    let speedState: String
    let station: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case planet
        case speed
        case speedState = "speed_state"
        case station
    }
}

struct HorarySolarCondition: Codable, Identifiable {
    let id: String
    let planet: String
    let condition: String
    let distanceFromSun: Double

    enum CodingKeys: String, CodingKey {
        case id
        case planet
        case condition
        case distanceFromSun = "distance_from_sun"
    }
}

struct HoraryNegativeReception: Codable, Identifiable {
    let id: String
    let receiver: String
    let received: String
    let debility: String
    let viaAspect: String
    let strength: String

    enum CodingKeys: String, CodingKey {
        case id
        case receiver
        case received
        case debility
        case viaAspect = "via_aspect"
        case strength
    }
}

struct HoraryAdvancedCandidate: Codable, Identifiable {
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
        case from
        case to
        case reason
    }
}
