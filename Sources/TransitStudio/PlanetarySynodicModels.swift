import Foundation

struct PlanetaryPair: Codable, Hashable {
    let bodyA: String
    let bodyB: String

    enum CodingKeys: String, CodingKey {
        case bodyA = "body_a"
        case bodyB = "body_b"
    }
}

struct PlanetarySynodicRequest: Codable {
    let mode: String
    let start: ChartMoment
    let end: ChartMoment
    let displayTimezone: String
    let pair: PlanetaryPair
    let phases: [AspectRequest]
    let birth: RelocationBirth?
    let targetPointSet: ModernPointSet?
    let contactAspects: [AspectRequest]?
    let zodiac: String
    let ephemerisPath: String?
    let noAsteroids: Bool
    let requireEphemeris: String

    init(
        mode: String = "planetary_synodic",
        start: ChartMoment,
        end: ChartMoment,
        displayTimezone: String,
        pair: PlanetaryPair,
        phases: [AspectRequest],
        birth: RelocationBirth? = nil,
        targetPointSet: ModernPointSet? = nil,
        contactAspects: [AspectRequest]? = nil,
        zodiac: String = "tropical",
        ephemerisPath: String? = nil,
        noAsteroids: Bool = false,
        requireEphemeris: String = "warn"
    ) {
        self.mode = mode
        self.start = start
        self.end = end
        self.displayTimezone = displayTimezone
        self.pair = pair
        self.phases = phases
        self.birth = birth
        self.targetPointSet = targetPointSet
        self.contactAspects = contactAspects
        self.zodiac = zodiac
        self.ephemerisPath = ephemerisPath
        self.noAsteroids = noAsteroids
        self.requireEphemeris = requireEphemeris
    }

    enum CodingKeys: String, CodingKey {
        case mode, start, end, pair, phases, birth, zodiac
        case displayTimezone = "display_timezone"
        case targetPointSet = "target_point_set"
        case contactAspects = "contact_aspects"
        case ephemerisPath = "ephemeris_path"
        case noAsteroids = "no_asteroids"
        case requireEphemeris = "require_ephemeris"
    }
}

struct SynodicPhaseEvent: Codable, Identifiable {
    let id: String
    let groupID: String?
    let eventType: String?
    let phaseID: String?
    let phaseName: String?
    let phaseAngle: Double?
    let bodyAID: String?
    let bodyBID: String?
    let exactUTC: String
    let exactLocal: String?
    let longitudeA: Double?
    let longitudeB: Double?
    let separationDeg: Double?
    let relativeSpeed: Double?
    let motionA: String?
    let motionB: String?
    let relativeMotion: String?
    let exactOrb: Double?
    let passIndexInWindow: Int?
    let passCountInWindow: Int?
    let methodKey: String?
    let natalContacts: [CycleContact]?

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case eventType = "event_type"
        case phaseID = "phase_id"
        case phaseName = "phase_name"
        case phaseAngle = "phase_angle"
        case bodyAID = "body_a_id"
        case bodyBID = "body_b_id"
        case exactUTC = "exact_utc"
        case exactLocal = "exact_local"
        case longitudeA = "longitude_a"
        case longitudeB = "longitude_b"
        case separationDeg = "separation_deg"
        case relativeSpeed = "relative_speed"
        case motionA = "motion_a"
        case motionB = "motion_b"
        case relativeMotion = "relative_motion"
        case exactOrb = "exact_orb"
        case passIndexInWindow = "pass_index_in_window"
        case passCountInWindow = "pass_count_in_window"
        case methodKey = "method_key"
        case natalContacts = "natal_contacts"
    }
}

struct SynodicCycleRow: Codable, Identifiable {
    let id: String
    let startUTC: String?
    let endUTC: String?
    let startLocal: String?
    let endLocal: String?
    let bodyAID: String?
    let bodyBID: String?
    let durationDays: Double?
    let methodKey: String?

    enum CodingKeys: String, CodingKey {
        case id
        case startUTC = "start_utc"
        case endUTC = "end_utc"
        case startLocal = "start_local"
        case endLocal = "end_local"
        case bodyAID = "body_a_id"
        case bodyBID = "body_b_id"
        case durationDays = "duration_days"
        case methodKey = "method_key"
    }
}

struct PlanetarySynodicMeta: Codable {
    let mode: String?
    let method: String
    let schemaVersion: Int?
    let startUTC: String?
    let endUTC: String?
    let displayTimezone: String?
    let pair: PlanetaryPair?
    let eventCount: Int?
    let cycleCount: Int?
    let zodiac: String?
    let ephemeris: String?

    enum CodingKeys: String, CodingKey {
        case mode, method, pair, zodiac, ephemeris
        case schemaVersion = "schema_version"
        case startUTC = "start_utc"
        case endUTC = "end_utc"
        case displayTimezone = "display_timezone"
        case eventCount = "event_count"
        case cycleCount = "cycle_count"
    }
}

struct PlanetarySynodicResult: Codable {
    let meta: PlanetarySynodicMeta
    let requestedConfig: [String: NestedJSON]?
    let effectiveConfig: [String: NestedJSON]?
    let events: [SynodicPhaseEvent]
    let cycles: [SynodicCycleRow]
    let warnings: [String]
    let sectionErrors: [String: String]?
    let calculationAssumptions: [String]?

    enum CodingKeys: String, CodingKey {
        case meta, events, cycles, warnings
        case requestedConfig = "requested_config"
        case effectiveConfig = "effective_config"
        case sectionErrors = "section_errors"
        case calculationAssumptions = "calculation_assumptions"
    }
}
