import Foundation

// MARK: - Horary Data Packet v2 (judgment-free)

struct HoraryDataPacket: Codable {
    /// Exact backend payload. JSON export re-encodes this value so typed UI
    /// projections cannot silently discard newly added evidence keys.
    let raw: HoraryV2JSONValue
    let schema: HoraryV2Schema
    let questionMetadata: HoraryV2QuestionMetadata
    /// Lossless config bag — numeric_precision, aspects_enabled, etc. survive round-trip.
    let calculationConfig: HoraryV2EvidenceRow
    /// Lossless provenance bag — aberration_light_time, precession_nutation, etc.
    let provenance: HoraryV2EvidenceRow
    /// Lossless time/location bag — geocoding, sect.evidence, iso fields, etc.
    let timeAndLocation: HoraryV2EvidenceRow
    let houses: HoraryV2Houses
    let angles: HoraryV2Angles
    /// Lossless body rows — full backend keys survive decode→encode.
    let bodies: [HoraryV2EvidenceRow]
    let dignities: [HoraryV2EvidenceRow]
    let pairwiseGeometry: [HoraryV2EvidenceRow]
    let aspects: [HoraryV2EvidenceRow]
    let aspectCandidates: [HoraryV2EvidenceRow]?
    let aspectsInDisplayOrb: [HoraryV2EvidenceRow]?
    let displayOrbDeg: Double?
    let receptions: [HoraryV2EvidenceRow]
    let lots: [HoraryV2EvidenceRow]
    let events: [HoraryV2EvidenceRow]
    let eventGraph: HoraryV2JSONValue?
    let moon: HoraryV2JSONValue?
    let visibility: [HoraryV2EvidenceRow]
    let planetaryDayHour: HoraryV2JSONValue?
    let considerationsEvidence: [HoraryV2JSONValue]?
    let nodes: HoraryV2JSONValue?
    let optionalModules: HoraryV2JSONValue?
    let validation: HoraryV2Validation
    let display: HoraryV2Display?

    enum CodingKeys: String, CodingKey {
        case schema
        case questionMetadata = "question_metadata"
        case calculationConfig = "calculation_config"
        case provenance
        case timeAndLocation = "time_and_location"
        case houses, angles, bodies, dignities
        case pairwiseGeometry = "pairwise_geometry"
        case aspects
        case aspectCandidates = "aspect_candidates"
        case aspectsInDisplayOrb = "aspects_in_display_orb"
        case displayOrbDeg = "display_orb_deg"
        case receptions, lots, events
        case eventGraph = "event_graph"
        case moon, visibility
        case planetaryDayHour = "planetary_day_hour"
        case considerationsEvidence = "considerations_evidence"
        case nodes
        case optionalModules = "optional_modules"
        case validation, display
    }

    init(from decoder: Decoder) throws {
        let rawContainer = try decoder.container(keyedBy: HoraryV2DynamicCodingKey.self)
        var rawObject: [String: HoraryV2JSONValue] = [:]
        for key in rawContainer.allKeys {
            rawObject[key.stringValue] = try rawContainer.decode(
                HoraryV2JSONValue.self,
                forKey: key
            )
        }
        raw = .object(rawObject)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decode(HoraryV2Schema.self, forKey: .schema)
        questionMetadata = try container.decode(HoraryV2QuestionMetadata.self, forKey: .questionMetadata)
        calculationConfig = try container.decode(HoraryV2EvidenceRow.self, forKey: .calculationConfig)
        provenance = try container.decode(HoraryV2EvidenceRow.self, forKey: .provenance)
        timeAndLocation = try container.decode(HoraryV2EvidenceRow.self, forKey: .timeAndLocation)
        houses = try container.decode(HoraryV2Houses.self, forKey: .houses)
        angles = try container.decode(HoraryV2Angles.self, forKey: .angles)
        bodies = try container.decode([HoraryV2EvidenceRow].self, forKey: .bodies)
        dignities = try container.decode([HoraryV2EvidenceRow].self, forKey: .dignities)
        pairwiseGeometry = try container.decode([HoraryV2EvidenceRow].self, forKey: .pairwiseGeometry)
        aspects = try container.decode([HoraryV2EvidenceRow].self, forKey: .aspects)
        aspectCandidates = try container.decodeIfPresent([HoraryV2EvidenceRow].self, forKey: .aspectCandidates)
        aspectsInDisplayOrb = try container.decodeIfPresent([HoraryV2EvidenceRow].self, forKey: .aspectsInDisplayOrb)
        displayOrbDeg = try container.decodeIfPresent(Double.self, forKey: .displayOrbDeg)
        receptions = try container.decode([HoraryV2EvidenceRow].self, forKey: .receptions)
        lots = try container.decode([HoraryV2EvidenceRow].self, forKey: .lots)
        events = try container.decode([HoraryV2EvidenceRow].self, forKey: .events)
        eventGraph = try container.decodeIfPresent(HoraryV2JSONValue.self, forKey: .eventGraph)
        moon = try container.decodeIfPresent(HoraryV2JSONValue.self, forKey: .moon)
        visibility = try container.decode([HoraryV2EvidenceRow].self, forKey: .visibility)
        planetaryDayHour = try container.decodeIfPresent(HoraryV2JSONValue.self, forKey: .planetaryDayHour)
        considerationsEvidence = try container.decodeIfPresent([HoraryV2JSONValue].self, forKey: .considerationsEvidence)
        nodes = try container.decodeIfPresent(HoraryV2JSONValue.self, forKey: .nodes)
        optionalModules = try container.decodeIfPresent(HoraryV2JSONValue.self, forKey: .optionalModules)
        validation = try container.decode(HoraryV2Validation.self, forKey: .validation)
        display = try container.decodeIfPresent(HoraryV2Display.self, forKey: .display)
    }

    func encode(to encoder: Encoder) throws {
        try raw.encode(to: encoder)
    }

    func rawValue(_ key: String) -> HoraryV2JSONValue? {
        raw[key]
    }
}

private struct HoraryV2DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Loose JSON passthrough for expanded v2.1 blocks still evolving in Swift UI.
enum HoraryV2JSONValue: Codable {
    case object([String: HoraryV2JSONValue])
    case array([HoraryV2JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([HoraryV2JSONValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: HoraryV2JSONValue].self) { self = .object(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    var objectValue: [String: HoraryV2JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    var arrayValue: [HoraryV2JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var numberValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    subscript(key: String) -> HoraryV2JSONValue? {
        objectValue?[key]
    }

    func string(_ key: String) -> String? { self[key]?.stringValue }
    func number(_ key: String) -> Double? { self[key]?.numberValue }
    func bool(_ key: String) -> Bool? { self[key]?.boolValue }
}

struct HoraryV2Schema: Codable {
    let name: String
    let version: String
    let schemaId: String

    enum CodingKeys: String, CodingKey {
        case name, version
        case schemaId = "schema_id"
    }
}

struct HoraryV2QuestionMetadata: Codable {
    let questionText: String
    let placeName: String

    enum CodingKeys: String, CodingKey {
        case questionText = "question_text"
        case placeName = "place_name"
    }
}

// Typed config/provenance/time removed: use HoraryV2EvidenceRow bags so
// geocoding, sect.evidence, numeric_precision, aspects_enabled,
// aberration_light_time, precession_nutation, etc. never drop on encode.

struct HoraryV2EventWindow {
    let pastDays: Double
    let futureDays: Double
}

/// Sect view over lossless time_and_location bag (not a Codable drop-path).
struct HoraryV2Sect {
    let isDay: Bool
    let ruleId: String
    let evidence: HoraryV2JSONValue?
}

struct HoraryV2SignDisplay: Codable {
    let signIndex: Int
    let signId: String
    let signEn: String
    let signZh: String
    let degreeInSign: Double?
    let displayZh: String
    let displayEn: String

    enum CodingKeys: String, CodingKey {
        case signIndex = "sign_index"
        case signId = "sign_id"
        case signEn = "sign_en"
        case signZh = "sign_zh"
        case degreeInSign = "degree_in_sign"
        case displayZh = "display_zh"
        case displayEn = "display_en"
    }
}

struct HoraryV2Houses: Codable {
    let system: String
    let systemLabel: String
    let cusps: [HoraryV2HouseCusp]
    let usesEclipticLongitudeForBodyHouses: Bool
    let fallbackApplied: Bool
    let fallbackReason: String?

    enum CodingKeys: String, CodingKey {
        case system
        case systemLabel = "system_label"
        case cusps
        case usesEclipticLongitudeForBodyHouses = "uses_ecliptic_longitude_for_body_houses"
        case fallbackApplied = "fallback_applied"
        case fallbackReason = "fallback_reason"
    }
}

struct HoraryV2HouseCusp: Codable, Identifiable {
    var id: Int { house }
    let house: Int
    let cuspLongitudeDeg: Double
    let spanDeg: Double?
    let sign: HoraryV2SignDisplay
    let domicileRulerId: String

    enum CodingKeys: String, CodingKey {
        case house
        case cuspLongitudeDeg = "cusp_longitude_deg"
        case spanDeg = "span_deg"
        case sign
        case domicileRulerId = "domicile_ruler_id"
    }
}

struct HoraryV2Angles: Codable {
    let points: [HoraryV2AnglePoint]
    let armc: HoraryV2Armc
}

struct HoraryV2AnglePoint: Codable, Identifiable {
    let id: String
    let longitudeDeg: Double
    let sign: HoraryV2SignDisplay
    enum CodingKeys: String, CodingKey {
        case id
        case longitudeDeg = "longitude_deg"
        case sign
    }
}

struct HoraryV2Armc: Codable {
    let id: String
    let longitudeDeg: Double?
    enum CodingKeys: String, CodingKey {
        case id
        case longitudeDeg = "longitude_deg"
    }
}

struct HoraryV2Body: Codable, Identifiable {
    var id: String { bodyId }
    let bodyId: String
    let names: HoraryV2Names
    let ecliptic: HoraryV2Ecliptic
    let sign: HoraryV2SignDisplay
    let equatorial: HoraryV2Equatorial
    let horizontal: HoraryV2Horizontal
    let house: HoraryV2BodyHouse
    let motion: HoraryV2Motion
    let ephemerisSource: String?
    let accidental: HoraryV2JSONValue?
    let distanceToAnglesDeg: HoraryV2JSONValue?
    let eventsIndex: HoraryV2JSONValue?
    let precision: HoraryV2JSONValue?
    let nodeMode: String?
    let nodeRole: String?
    let southDerivation: String?
    let participatesInDomicileRulership: Bool?
    let participatesInClassicalDignities: Bool?

    enum CodingKeys: String, CodingKey {
        case bodyId = "body_id"
        case names, ecliptic, sign, equatorial, horizontal, house, motion
        case ephemerisSource = "ephemeris_source"
        case accidental
        case distanceToAnglesDeg = "distance_to_angles_deg"
        case eventsIndex = "events_index"
        case precision
        case nodeMode = "node_mode"
        case nodeRole = "node_role"
        case southDerivation = "south_derivation"
        case participatesInDomicileRulership = "participates_in_domicile_rulership"
        case participatesInClassicalDignities = "participates_in_classical_dignities"
    }
}

struct HoraryV2Names: Codable {
    let en: String
    let zh: String
}

struct HoraryV2Ecliptic: Codable {
    let longitudeDeg: Double
    let latitudeDeg: Double?
    let distanceAu: Double?
    let longitudeSpeedDegPerDay: Double?
    enum CodingKeys: String, CodingKey {
        case longitudeDeg = "longitude_deg"
        case latitudeDeg = "latitude_deg"
        case distanceAu = "distance_au"
        case longitudeSpeedDegPerDay = "longitude_speed_deg_per_day"
    }
}

struct HoraryV2Equatorial: Codable {
    let rightAscensionDeg: Double?
    let declinationDeg: Double?
    let hourAngleDeg: Double?
    enum CodingKeys: String, CodingKey {
        case rightAscensionDeg = "right_ascension_deg"
        case declinationDeg = "declination_deg"
        case hourAngleDeg = "hour_angle_deg"
    }
}

struct HoraryV2Horizontal: Codable {
    let azimuthDeg: Double?
    let altitudeTrueDeg: Double?
    let aboveHorizon: Bool?
    enum CodingKeys: String, CodingKey {
        case azimuthDeg = "azimuth_deg"
        case altitudeTrueDeg = "altitude_true_deg"
        case aboveHorizon = "above_horizon"
    }
}

struct HoraryV2BodyHouse: Codable {
    let integerHouse: Int
    let continuousHouse: Double?
    let distanceFromPreviousCuspDeg: Double?
    let distanceToNextCuspDeg: Double?
    enum CodingKeys: String, CodingKey {
        case integerHouse = "integer_house"
        case continuousHouse = "continuous_house"
        case distanceFromPreviousCuspDeg = "distance_from_previous_cusp_deg"
        case distanceToNextCuspDeg = "distance_to_next_cusp_deg"
    }
}

struct HoraryV2Motion: Codable {
    let state: String
    let longitudeSpeedDegPerDay: Double?
    let meanLongitudeSpeedDegPerDay: Double?
    let speedToMeanRatio: Double?
    let ruleId: String?
    enum CodingKeys: String, CodingKey {
        case state
        case longitudeSpeedDegPerDay = "longitude_speed_deg_per_day"
        case meanLongitudeSpeedDegPerDay = "mean_longitude_speed_deg_per_day"
        case speedToMeanRatio = "speed_to_mean_ratio"
        case ruleId = "rule_id"
    }
}

struct HoraryV2Dignity: Codable, Identifiable {
    var id: String { bodyId }
    let bodyId: String
    let domicileRulerId: String
    let exaltationRulerId: String?
    let detrimentRulerId: String?
    let fallRulerId: String?
    let isPeregrine: Bool
    let isInOwnDomicile: Bool
    let isInOwnExaltation: Bool
    let isInDetriment: Bool
    let isInFall: Bool
    let bounds: HoraryV2IntervalRuler
    let decan: HoraryV2IntervalRuler
    let triplicity: HoraryV2Triplicity
    let ruleId: String?

    enum CodingKeys: String, CodingKey {
        case bodyId = "body_id"
        case domicileRulerId = "domicile_ruler_id"
        case exaltationRulerId = "exaltation_ruler_id"
        case detrimentRulerId = "detriment_ruler_id"
        case fallRulerId = "fall_ruler_id"
        case isPeregrine = "is_peregrine"
        case isInOwnDomicile = "is_in_own_domicile"
        case isInOwnExaltation = "is_in_own_exaltation"
        case isInDetriment = "is_in_detriment"
        case isInFall = "is_in_fall"
        case bounds, decan, triplicity
        case ruleId = "rule_id"
    }
}

struct HoraryV2IntervalRuler: Codable {
    let rulerId: String
    let startDegreeInSign: Double?
    let endDegreeInSign: Double?
    enum CodingKeys: String, CodingKey {
        case rulerId = "ruler_id"
        case startDegreeInSign = "start_degree_in_sign"
        case endDegreeInSign = "end_degree_in_sign"
    }
}

struct HoraryV2Triplicity: Codable {
    let system: String
    let element: String?
    let dayRulerId: String?
    let nightRulerId: String?
    let participatingRulerId: String?
    let activeRulerId: String?
    enum CodingKeys: String, CodingKey {
        case system, element
        case dayRulerId = "day_ruler_id"
        case nightRulerId = "night_ruler_id"
        case participatingRulerId = "participating_ruler_id"
        case activeRulerId = "active_ruler_id"
    }
}

struct HoraryV2PairGeometry: Codable, Identifiable {
    let id: String
    let bodyAId: String
    let bodyBId: String
    let minimumSeparationDeg: Double?
    let relativeSpeedDegPerDay: Double?
    let nearestAspect: HoraryV2NearestAspect?

    enum CodingKeys: String, CodingKey {
        case id
        case bodyAId = "body_a_id"
        case bodyBId = "body_b_id"
        case minimumSeparationDeg = "minimum_separation_deg"
        case relativeSpeedDegPerDay = "relative_speed_deg_per_day"
        case nearestAspect = "nearest_aspect"
    }
}

struct HoraryV2NearestAspect: Codable {
    let aspectId: String?
    let aspectAngleDeg: Double?
    let deltaToAspectDeg: Double?
    let withinOrb: Bool?
    enum CodingKeys: String, CodingKey {
        case aspectId = "aspect_id"
        case aspectAngleDeg = "aspect_angle_deg"
        case deltaToAspectDeg = "delta_to_aspect_deg"
        case withinOrb = "within_orb"
    }
}

struct HoraryV2Aspect: Codable, Identifiable {
    let id: String
    let bodyAId: String
    let bodyBId: String
    let aspectId: String
    let aspectAngleDeg: Double
    let orbDeg: Double?
    let absoluteOrbDeg: Double?
    let signedOrbDeg: Double?
    let application: String
    let applicationEvidence: HoraryV2JSONValue?
    let withinDisplayOrb: Bool?
    let withinOrb: Bool?
    let willPerfectInWindow: Bool?
    let nextExact: HoraryV2ExactInfo?
    let previousExact: HoraryV2ExactInfo?
    let refranationDetected: Bool?
    let signExitBeforeExact: HoraryV2JSONValue?

    enum CodingKeys: String, CodingKey {
        case id
        case bodyAId = "body_a_id"
        case bodyBId = "body_b_id"
        case aspectId = "aspect_id"
        case aspectAngleDeg = "aspect_angle_deg"
        case orbDeg = "orb_deg"
        case absoluteOrbDeg = "absolute_orb_deg"
        case signedOrbDeg = "signed_orb_deg"
        case application
        case applicationEvidence = "application_evidence"
        case withinDisplayOrb = "within_display_orb"
        case withinOrb = "within_orb"
        case willPerfectInWindow = "will_perfect_in_window"
        case nextExact = "next_exact"
        case previousExact = "previous_exact"
        case refranationDetected = "refranation_detected"
        case signExitBeforeExact = "sign_exit_before_exact"
    }
}

struct HoraryV2ExactInfo: Codable {
    let datetimeLocal: String?
    let datetimeUtc: String?
    let rootStatus: String?
    let rootReason: String?
    enum CodingKeys: String, CodingKey {
        case datetimeLocal = "datetime_local"
        case datetimeUtc = "datetime_utc"
        case rootStatus = "root_status"
        case rootReason = "root_reason"
    }
}

/// Lossless pure-data row: every JSON key survives decode→encode.
/// Stable typed fields for UI; all remaining keys live in `raw`.
struct HoraryV2EvidenceRow: Codable, Identifiable {
    let raw: HoraryV2JSONValue

    var id: String {
        // Prefer stable backend keys — never random UUID (ForEach identity thrash).
        if let id = string("id") { return id }
        if let bodyId = string("body_id") { return bodyId }
        if let a = string("body_a_id"), let b = string("body_b_id") {
            return "\(a)|\(b)"
        }
        if let a = string("receiver_id"), let b = string("received_body_id") {
            return "\(a)|\(b)"
        }
        // Deterministic fallback from sorted raw keys (stable across redraws).
        if case .object(let obj) = raw {
            let keys = obj.keys.sorted().joined(separator: ",")
            return "row|\(keys.hashValue)"
        }
        return "row|empty"
    }

    init(raw: HoraryV2JSONValue) {
        self.raw = raw
    }

    init(from decoder: Decoder) throws {
        raw = try HoraryV2JSONValue(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try raw.encode(to: encoder)
    }

    private var object: [String: HoraryV2JSONValue] {
        if case .object(let o) = raw { return o }
        return [:]
    }

    func string(_ key: String) -> String? {
        guard case .string(let s) = object[key] else { return nil }
        return s
    }

    func number(_ key: String) -> Double? {
        guard case .number(let n) = object[key] else { return nil }
        return n
    }

    func bool(_ key: String) -> Bool? {
        guard case .bool(let b) = object[key] else { return nil }
        return b
    }

    func value(_ key: String) -> HoraryV2JSONValue? {
        object[key]
    }

    // MARK: - Provenance conveniences
    var engineName: String { string("engine_name") ?? "" }
    var engineVersion: String { string("engine_version") ?? "" }
    var algorithmVersion: String { string("algorithm_version") ?? "" }
    var ephemerisProvider: String { string("ephemeris_provider") ?? "" }
    var ephemerisVersion: String { string("ephemeris_version") ?? "" }
    var inputHashSha256: String { string("input_hash_sha256") ?? "" }
    var configHashSha256: String { string("config_hash_sha256") ?? "" }

    // MARK: - Calculation config conveniences
    var houseSystem: String { string("house_system") ?? "" }
    var houseSystemLabel: String { string("house_system_label") ?? houseSystem }
    var zodiac: String { string("zodiac") ?? "" }
    var zodiacLabel: String { string("zodiac_label") ?? zodiac }
    var boundsSystem: String { string("bounds_system") ?? "" }
    var triplicitySystem: String { string("triplicity_system") ?? "" }
    var aspectOrbDeg: Double { number("aspect_orb_deg") ?? 0 }
    var configBodies: [String] {
        guard case .array(let arr) = object["bodies"] else { return [] }
        return arr.compactMap { if case .string(let s) = $0 { return s }; return nil }
    }
    var eventWindow: HoraryV2EventWindow {
        guard case .object(let o) = object["event_window"] else {
            return HoraryV2EventWindow(pastDays: 0, futureDays: 0)
        }
        let past: Double = { if case .number(let n) = o["past_days"] ?? .null { return n }; return 0 }()
        let future: Double = { if case .number(let n) = o["future_days"] ?? .null { return n }; return 0 }()
        return HoraryV2EventWindow(pastDays: past, futureDays: future)
    }

    // MARK: - Time & location conveniences
    var localDatetime: String { string("local_datetime") ?? "" }
    var utcDatetime: String { string("utc_datetime") ?? "" }
    var timezone: String { string("timezone") ?? "" }
    var utcOffsetSeconds: Int { number("utc_offset_seconds").map { Int($0) } ?? 0 }
    var dstActive: Bool { bool("dst_active") ?? false }
    var jdUt: Double? { number("jd_ut") }
    var jdTt: Double? { number("jd_tt") }
    var deltaTSeconds: Double? { number("delta_t_seconds") }
    var siderealTimeHours: Double? { number("sidereal_time_hours") }
    var armcDeg: Double? { number("armc_deg") }
    var obliquityDeg: Double? { number("obliquity_deg") }
    var latitudeDeg: Double { number("latitude_deg") ?? 0 }
    var locationLongitudeDeg: Double { number("longitude_deg") ?? 0 }
    var altitudeM: Double? { number("altitude_m") }
    var geocoding: HoraryV2JSONValue? { value("geocoding") }
    var sect: HoraryV2Sect {
        guard case .object(let o) = object["sect"] else {
            return HoraryV2Sect(isDay: false, ruleId: "", evidence: nil)
        }
        let isDay: Bool = { if case .bool(let b) = o["is_day"] ?? .null { return b }; return false }()
        let ruleId: String = { if case .string(let s) = o["rule_id"] ?? .null { return s }; return "" }()
        let evidence = o["evidence"]
        return HoraryV2Sect(isDay: isDay, ruleId: ruleId, evidence: evidence)
    }

    // Convenience for receptions / lots UI
    var receiverId: String? { string("receiver_id") }
    var receivedBodyId: String? { string("received_body_id") }
    var dignityType: String? { string("dignity_type") }
    var relatedAspectId: String? { string("related_aspect_id") }
    var relationKind: String? { string("relation_kind") }
    var bodyAId: String? { string("body_a_id") }
    var bodyBId: String? { string("body_b_id") }
    var formulaId: String? { string("formula_id") }
    var formulaUsed: String? { string("formula_used") }
    var formulaDay: String? { string("formula_day") }
    var formulaNight: String? { string("formula_night") }
    var sectUsed: String? { string("sect_used") }
    var domicileRulerId: String? { string("domicile_ruler_id") }
    var longitudeDeg: Double? { number("longitude_deg") }
    var longitudeBeforeNormalizeDeg: Double? { number("longitude_before_normalize_deg") }
    var inputPoints: HoraryV2JSONValue? { value("input_points") }
    var intermediates: HoraryV2JSONValue? { value("intermediates") }
    var relationAtNextAspectExact: HoraryV2JSONValue? { value("relation_at_next_aspect_exact") }
    var relationChangesIfSignExitBeforeExact: HoraryV2JSONValue? { value("relation_changes_if_sign_exit_before_exact") }

    // Aspect-candidate convenience
    var aspectId: String? { string("aspect_id") }
    var application: String? { string("application") }
    var absoluteOrbDeg: Double? { number("absolute_orb_deg") ?? number("orb_deg") }
    var orbDeg: Double? { number("orb_deg") }
    var withinDisplayOrb: Bool? { bool("within_display_orb") ?? bool("within_orb") }
    var withinOrb: Bool? { bool("within_orb") ?? bool("within_display_orb") }
    var willPerfectInWindow: Bool? { bool("will_perfect_in_window") }
    var refranationDetected: Bool? { bool("refranation_detected") }
    var nextExact: HoraryV2ExactInfo? {
        guard case .object(let o) = object["next_exact"] else { return nil }
        return HoraryV2ExactInfo(
            datetimeLocal: {
                if case .string(let s) = o["datetime_local"] ?? .null { return s }
                return nil
            }(),
            datetimeUtc: {
                if case .string(let s) = o["datetime_utc"] ?? .null { return s }
                return nil
            }(),
            rootStatus: {
                if case .string(let s) = o["root_status"] ?? .null { return s }
                return nil
            }(),
            rootReason: {
                if case .string(let s) = o["root_reason"] ?? .null { return s }
                return nil
            }()
        )
    }

    // Body convenience for wheel / tables
    var bodyId: String { string("body_id") ?? id }
    var eclipticLongitude: Double { numberFromPath(["ecliptic", "longitude_deg"]) ?? 0 }
    var eclipticLatitude: Double? { numberFromPath(["ecliptic", "latitude_deg"]) }
    var eclipticSpeed: Double? { numberFromPath(["ecliptic", "longitude_speed_deg_per_day"]) }
    var integerHouse: Int {
        if let n = numberFromPath(["house", "integer_house"]) { return Int(n) }
        return 0
    }
    var motionState: String {
        if case .object(let o) = object["motion"], case .string(let s) = o["state"] ?? .null { return s }
        return "-"
    }
    var displayZh: String {
        if case .object(let o) = object["sign"], case .string(let s) = o["display_zh"] ?? .null { return s }
        return "-"
    }
    var displayEn: String {
        if case .object(let o) = object["sign"], case .string(let s) = o["display_en"] ?? .null { return s }
        return "-"
    }
    var nameZh: String {
        if case .object(let o) = object["names"], case .string(let s) = o["zh"] ?? .null { return s }
        return bodyId
    }
    var accidental: HoraryV2JSONValue? { value("accidental") }
    var distanceToAnglesDeg: HoraryV2JSONValue? { value("distance_to_angles_deg") }
    var eventsIndex: HoraryV2JSONValue? { value("events_index") }
    var precision: HoraryV2JSONValue? { value("precision") }
    var datetimeUtc: String? { string("datetime_utc") }
    var datetimeLocal: String? { string("datetime_local") }
    var eventType: String? { string("event_type") }
    var offsetSecondsFromQuery: Int? {
        number("offset_seconds_from_query").map { Int($0) }
    }
    var bodyIds: [String] {
        guard case .array(let arr) = object["body_ids"] else { return [] }
        return arr.compactMap {
            if case .string(let s) = $0 { return s }
            return nil
        }
    }

    private func numberFromPath(_ path: [String]) -> Double? {
        var cur: HoraryV2JSONValue? = raw
        for (i, key) in path.enumerated() {
            guard case .object(let o) = cur else { return nil }
            if i == path.count - 1 {
                if case .number(let n) = o[key] ?? .null { return n }
                return nil
            }
            cur = o[key]
        }
        return nil
    }

    var names: HoraryV2Names {
        guard case .object(let o) = object["names"],
              case .string(let en) = o["en"] ?? .null,
              case .string(let zh) = o["zh"] ?? .null else {
            return HoraryV2Names(en: string("id") ?? "lot", zh: string("id") ?? "lot")
        }
        return HoraryV2Names(en: en, zh: zh)
    }

    var sign: HoraryV2SignDisplay {
        // Minimal fallback display if nested decode not available as typed
        if case .object(let o) = object["sign"],
           case .string(let displayEn) = o["display_en"] ?? .null,
           case .string(let displayZh) = o["display_zh"] ?? .null,
           case .number(let idx) = o["sign_index"] ?? .null,
           case .string(let signId) = o["sign_id"] ?? .null,
           case .string(let signEn) = o["sign_en"] ?? .null,
           case .string(let signZh) = o["sign_zh"] ?? .null {
            let deg: Double? = {
                if case .number(let d) = o["degree_in_sign"] ?? .null { return d }
                return nil
            }()
            return HoraryV2SignDisplay(
                signIndex: Int(idx),
                signId: signId,
                signEn: signEn,
                signZh: signZh,
                degreeInSign: deg,
                displayZh: displayZh,
                displayEn: displayEn
            )
        }
        return HoraryV2SignDisplay(
            signIndex: 0, signId: "aries", signEn: "Aries", signZh: "白羊",
            degreeInSign: 0, displayZh: "-", displayEn: "-"
        )
    }

    var house: HoraryV2BodyHouse {
        if case .object(let o) = object["house"],
           case .number(let ih) = o["integer_house"] ?? .null {
            let cont: Double? = {
                if case .number(let c) = o["continuous_house"] ?? .null { return c }
                return nil
            }()
            let fromPrev: Double? = {
                if case .number(let c) = o["distance_from_previous_cusp_deg"] ?? .null { return c }
                return nil
            }()
            let toNext: Double? = {
                if case .number(let c) = o["distance_to_next_cusp_deg"] ?? .null { return c }
                return nil
            }()
            return HoraryV2BodyHouse(
                integerHouse: Int(ih),
                continuousHouse: cont,
                distanceFromPreviousCuspDeg: fromPrev,
                distanceToNextCuspDeg: toNext
            )
        }
        return HoraryV2BodyHouse(integerHouse: 1, continuousHouse: nil, distanceFromPreviousCuspDeg: nil, distanceToNextCuspDeg: nil)
    }
}

typealias HoraryV2Reception = HoraryV2EvidenceRow
typealias HoraryV2Lot = HoraryV2EvidenceRow

struct HoraryV2Event: Codable, Identifiable {
    let id: String
    let eventType: String
    let bodyIds: [String]
    let aspectId: String?
    let datetimeUtc: String
    let datetimeLocal: String
    let offsetSecondsFromQuery: Int
    enum CodingKeys: String, CodingKey {
        case id
        case eventType = "event_type"
        case bodyIds = "body_ids"
        case aspectId = "aspect_id"
        case datetimeUtc = "datetime_utc"
        case datetimeLocal = "datetime_local"
        case offsetSecondsFromQuery = "offset_seconds_from_query"
    }
}

struct HoraryV2Moon: Codable {
    let phaseAngleDeg: Double?
    let illuminationFraction: Double?
    let ageDaysApprox: Double?
    let signExit: HoraryV2SignExit?
    let lastExactAspectInCurrentSign: HoraryV2MoonAspectRef?
    let nextExactAspectInCurrentSign: HoraryV2MoonAspectRef?
    let pastExactAspectsInCurrentSign: [HoraryV2MoonAspectRef]
    let futureExactAspectsInCurrentSign: [HoraryV2MoonAspectRef]
    let aspectsInNextSign: [HoraryV2MoonAspectRef]
    let voidOfCourseRules: [HoraryV2VocRule]

    enum CodingKeys: String, CodingKey {
        case phaseAngleDeg = "phase_angle_deg"
        case illuminationFraction = "illumination_fraction"
        case ageDaysApprox = "age_days_approx"
        case signExit = "sign_exit"
        case lastExactAspectInCurrentSign = "last_exact_aspect_in_current_sign"
        case nextExactAspectInCurrentSign = "next_exact_aspect_in_current_sign"
        case pastExactAspectsInCurrentSign = "past_exact_aspects_in_current_sign"
        case futureExactAspectsInCurrentSign = "future_exact_aspects_in_current_sign"
        case aspectsInNextSign = "aspects_in_next_sign"
        case voidOfCourseRules = "void_of_course_rules"
    }
}

struct HoraryV2SignExit: Codable {
    let datetimeLocal: String?
    let datetimeUtc: String?
    let remainingArcDeg: Double?
    let remainingSeconds: Int?
    enum CodingKeys: String, CodingKey {
        case datetimeLocal = "datetime_local"
        case datetimeUtc = "datetime_utc"
        case remainingArcDeg = "remaining_arc_deg"
        case remainingSeconds = "remaining_seconds"
    }
}

struct HoraryV2MoonAspectRef: Codable {
    let targetId: String?
    let aspectId: String?
    let datetimeLocal: String?
    let datetimeUtc: String?
    enum CodingKeys: String, CodingKey {
        case targetId = "target_id"
        case aspectId = "aspect_id"
        case datetimeLocal = "datetime_local"
        case datetimeUtc = "datetime_utc"
    }
}

struct HoraryV2VocRule: Codable, Identifiable {
    var id: String { ruleId }
    let ruleId: String
    let value: Bool
    let algorithmVersion: String?
    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case value
        case algorithmVersion = "algorithm_version"
    }
}

struct HoraryV2Visibility: Codable, Identifiable {
    var id: String { bodyId }
    let bodyId: String
    let eclipticSeparationFromSunDeg: Double?
    let sphericalSeparationFromSunDeg: Double?
    let morningEvening: String?
    let visible: Bool?
    let visibleReasonCode: String?
    let phaseAngleDeg: Double?
    let illuminationFraction: Double?
    let apparentMagnitude: Double?
    let angularDiameterArcsec: Double?
    let solarElongationDeg: Double?
    let sunAltitudeDeg: Double?
    let bodyAltitudeDeg: Double?
    let visibilityModelId: String?
    let atmosphere: HoraryV2JSONValue?
    let thresholds: HoraryV2JSONValue?
    let solarConditionFlags: HoraryV2JSONValue?
    let phenoSource: String?
    let morningEveningDefinition: String?
    let algorithmVersion: String?

    enum CodingKeys: String, CodingKey {
        case bodyId = "body_id"
        case eclipticSeparationFromSunDeg = "ecliptic_separation_from_sun_deg"
        case sphericalSeparationFromSunDeg = "spherical_separation_from_sun_deg"
        case morningEvening = "morning_evening"
        case visible
        case visibleReasonCode = "visible_reason_code"
        case phaseAngleDeg = "phase_angle_deg"
        case illuminationFraction = "illumination_fraction"
        case apparentMagnitude = "apparent_magnitude"
        case angularDiameterArcsec = "angular_diameter_arcsec"
        case solarElongationDeg = "solar_elongation_deg"
        case sunAltitudeDeg = "sun_altitude_deg"
        case bodyAltitudeDeg = "body_altitude_deg"
        case visibilityModelId = "visibility_model_id"
        case atmosphere
        case thresholds
        case solarConditionFlags = "solar_condition_flags"
        case phenoSource = "pheno_source"
        case morningEveningDefinition = "morning_evening_definition"
        case algorithmVersion = "algorithm_version"
    }
}

struct HoraryV2OptionalModules: Codable {
    let antiscia: [HoraryV2Antiscia]?
    let viaCombusta: [HoraryV2ViaCombusta]?
    let dodecatemoria: [HoraryV2Dodecatemoria]?
    let antisciaContacts: HoraryV2JSONValue?
    let declinationContacts: HoraryV2JSONValue?
    let declinationMoonSequence: HoraryV2JSONValue?
    let fixedStars: HoraryV2JSONValue?
    let planetaryHour: HoraryV2JSONValue?
    let nodes: HoraryV2JSONValue?
    let declinationParallels: HoraryV2JSONValue?

    enum CodingKeys: String, CodingKey {
        case antiscia
        case viaCombusta = "via_combusta"
        case dodecatemoria
        case antisciaContacts = "antiscia_contacts"
        case declinationContacts = "declination_contacts"
        case declinationMoonSequence = "declination_moon_sequence"
        case fixedStars = "fixed_stars"
        case planetaryHour = "planetary_hour"
        case nodes
        case declinationParallels = "declination_parallels"
    }
}

struct HoraryV2Antiscia: Codable {
    let bodyId: String
    let antisciaLongitudeDeg: Double?
    let contraAntisciaLongitudeDeg: Double?
    enum CodingKeys: String, CodingKey {
        case bodyId = "body_id"
        case antisciaLongitudeDeg = "antiscia_longitude_deg"
        case contraAntisciaLongitudeDeg = "contra_antiscia_longitude_deg"
    }
}

struct HoraryV2ViaCombusta: Codable {
    let bodyId: String
    let inViaCombusta: Bool
    enum CodingKeys: String, CodingKey {
        case bodyId = "body_id"
        case inViaCombusta = "in_via_combusta"
    }
}

struct HoraryV2Dodecatemoria: Codable {
    let bodyId: String
    let dodecatemoriaLongitudeDeg: Double?
    enum CodingKeys: String, CodingKey {
        case bodyId = "body_id"
        case dodecatemoriaLongitudeDeg = "dodecatemoria_longitude_deg"
    }
}

struct HoraryV2Validation: Codable {
    let warnings: [String]
    let houseFallbackApplied: Bool?
    let schemaId: String?
    let forbiddenFieldScan: String?
    let bodyCount: Int?
    let aspectCount: Int?
    let eventCount: Int?
    let lotCount: Int?

    enum CodingKeys: String, CodingKey {
        case warnings
        case houseFallbackApplied = "house_fallback_applied"
        case schemaId = "schema_id"
        case forbiddenFieldScan = "forbidden_field_scan"
        case bodyCount = "body_count"
        case aspectCount = "aspect_count"
        case eventCount = "event_count"
        case lotCount = "lot_count"
    }
}

struct HoraryV2Display: Codable {
    let languagePrimary: String?
    enum CodingKeys: String, CodingKey {
        case languagePrimary = "language_primary"
    }
}
