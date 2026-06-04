import Foundation

struct ClassicalResult: Codable {
    let meta: ClassicalMeta
    let angles: [ClassicalPoint]
    let houses: [HouseRow]
    let planets: [ClassicalPlanetRow]
    let lots: [ClassicalPoint]
    let experimentalLots: [ClassicalPoint]?
    let aspects: [ClassicalAspectRow]
    let receptions: [ReceptionRow]
    let antiscia: [AntisciaRow]?
    let primaryDirections: [PrimaryDirection]?
    let circumambulations: [Circumambulation]?
    let timing: TimingSummary
    let planetaryReturns: [SolarReturnSummary]
    let prenatalSyzygy: PrenatalSyzygy?
    let almutenFiguris: AlmutenFiguris?
    let hylegAlcocoden: HylegAlcocoden?
    let ambiguity: ClassicalAmbiguity?
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: CalculationAssumptions?
    let topSignatures: [TopSignature]?
    let birthdayTransition: BirthdayTransition?
    let activatedLordFocus: ActivatedLordFocus?

    enum CodingKeys: String, CodingKey {
        case meta
        case angles
        case houses
        case planets
        case lots
        case experimentalLots = "experimental_lots"
        case aspects
        case receptions
        case antiscia
        case primaryDirections = "primary_directions"
        case circumambulations
        case timing
        case planetaryReturns = "planetary_returns"
        case prenatalSyzygy = "prenatal_syzygy"
        case almutenFiguris = "almuten_figuris"
        case hylegAlcocoden = "hyleg_alcocoden"
        case ambiguity
        case warnings
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
        case topSignatures = "top_signatures"
        case birthdayTransition = "birthday_transition"
        case activatedLordFocus = "activated_lord_focus"
    }
}

struct TopSignature: Codable, Identifiable {
    let type: String
    let description: String
    let orb: Double?
    let strength: String?

    var id: String { "\(type):\(description)" }
}

struct BirthdayTransition: Codable {
    let detected: Bool
    let note: String
    let profectionAge: Int?
    let profectionStart: String?
    let currentSolarReturn: String?
    let nextSolarReturn: String?

    enum CodingKeys: String, CodingKey {
        case detected
        case note
        case profectionAge = "profection_age"
        case profectionStart = "profection_start"
        case currentSolarReturn = "current_solar_return"
        case nextSolarReturn = "next_solar_return"
    }
}

struct ActivatedLordFocus: Codable {
    let lordID: String
    let lordName: String
    let natalCondition: String?
    let natalScore: Int?
    let natalHouse: Int?
    let returnTitle: String?
    let returnExactLocal: String?
    let keywords: String?

    enum CodingKeys: String, CodingKey {
        case lordID = "lord_id"
        case lordName = "lord_name"
        case natalCondition = "natal_condition"
        case natalScore = "natal_score"
        case natalHouse = "natal_house"
        case returnTitle = "return_title"
        case returnExactLocal = "return_exact_local"
        case keywords
    }
}

struct CalculationAssumptions: Codable {
    let cazimiOrbArcmin: Double?
    let combustOrbDeg: Double?
    let underBeamsOrbDeg: Double?
    let naibodRate: Double?
    let primaryDirectionsMethod: String?
    let modernPlanetsExcludedFromScoring: Bool?
    let scoringIncludesConditioning: Bool?
    let signBasedReceptionsDowngraded: Bool?
    let lunarReturnIsNextAfterReference: Bool?
    let returnSchema: String?

    enum CodingKeys: String, CodingKey {
        case cazimiOrbArcmin = "cazimi_orb_arcmin"
        case combustOrbDeg = "combust_orb_deg"
        case underBeamsOrbDeg = "under_beams_orb_deg"
        case naibodRate = "naibod_rate"
        case primaryDirectionsMethod = "primary_directions_method"
        case modernPlanetsExcludedFromScoring = "modern_planets_excluded_from_scoring"
        case scoringIncludesConditioning = "scoring_includes_conditioning"
        case signBasedReceptionsDowngraded = "sign_based_receptions_downgraded"
        case lunarReturnIsNextAfterReference = "lunar_return_is_next_after_reference"
        case returnSchema = "return_schema"
    }
}

struct ClassicalMeta: Codable {
    let birthUTC: String
    let birthLocal: String?
    let referenceUTC: String
    let referenceLocal: String?
    let timezone: String?
    let latitude: Double?
    let longitude: Double?
    let sect: String
    let houseSystem: String
    let houseSystemNote: String?
    let zodiac: String
    let boundsSystem: String
    let triplicitySystem: String
    let aspectOrb: Double?
    let ephemeris: String

    enum CodingKeys: String, CodingKey {
        case birthUTC = "birth_utc"
        case birthLocal = "birth_local"
        case referenceUTC = "reference_utc"
        case referenceLocal = "reference_local"
        case timezone
        case latitude
        case longitude
        case sect
        case houseSystem = "house_system"
        case houseSystemNote = "house_system_note"
        case zodiac
        case boundsSystem = "bounds_system"
        case triplicitySystem = "triplicity_system"
        case aspectOrb = "aspect_orb"
        case ephemeris
    }
}

struct ClassicalAmbiguity: Codable {
    let techniqueRulers: [String: String]
    let conflictingSignals: [String]
    let confidence: String

    enum CodingKeys: String, CodingKey {
        case techniqueRulers = "technique_rulers"
        case conflictingSignals = "conflicting_signals"
        case confidence
    }
}
