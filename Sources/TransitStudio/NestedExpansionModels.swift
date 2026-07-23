import Foundation

// MARK: - NestedJSON re-decode helper

extension NestedJSON {
    /// Re-encode NestedJSON then decode as a typed Codable model.
    func decodeAs<T: Decodable>(_ type: T.Type) -> T? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - B14 Zodiacal Releasing

struct ZRPeriodRow: Codable, Identifiable, Hashable {
    var level: String?
    var sign: String?
    var signIndex: Int?
    var ruler: String?
    var years: Double?
    var startLocal: String?
    var endLocal: String?
    var isActive: Bool?

    var id: String { "\(level ?? "")-\(sign ?? "")-\(startLocal ?? "")-\(endLocal ?? "")" }

    enum CodingKeys: String, CodingKey {
        case level, sign, ruler, years
        case signIndex = "sign_index"
        case startLocal = "start_local"
        case endLocal = "end_local"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = try c.decodeIfPresent(String.self, forKey: .level)
        sign = try c.decodeIfPresent(String.self, forKey: .sign)
        signIndex = try c.decodeIfPresent(Int.self, forKey: .signIndex)
        ruler = try c.decodeIfPresent(String.self, forKey: .ruler)
        startLocal = try c.decodeIfPresent(String.self, forKey: .startLocal)
        endLocal = try c.decodeIfPresent(String.self, forKey: .endLocal)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive)
        if let d = try? c.decodeIfPresent(Double.self, forKey: .years) {
            years = d
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .years) {
            years = Double(i)
        } else {
            years = nil
        }
    }
}

struct ZRLotBlock: Codable, Hashable {
    var currentActiveLevel: String?
    var currentLevelRuler: String?
    var currentLevelSign: String?
    var lotLongitude: Double?
    var lotId: String?
    var loosingOfBond: Bool?
    var loosingOfBondDetail: String?
    var loosingOfBondLevel: String?
    var l1Periods: [ZRPeriodRow]?
    var l2Periods: [ZRPeriodRow]?
    var l3Periods: [ZRPeriodRow]?
    var l4Periods: [ZRPeriodRow]?

    enum CodingKeys: String, CodingKey {
        case currentActiveLevel = "current_active_level"
        case currentLevelRuler = "current_level_ruler"
        case currentLevelSign = "current_level_sign"
        case lotLongitude = "lot_longitude"
        case lotId = "lot_id"
        case loosingOfBond = "loosing_of_bond"
        case loosingOfBondDetail = "loosing_of_bond_detail"
        case loosingOfBondLevel = "loosing_of_bond_level"
        case l1Periods = "l1_periods"
        case l2Periods = "l2_periods"
        case l3Periods = "l3_periods"
        case l4Periods = "l4_periods"
    }
}

struct ZodiacalReleasingPayload: Codable, Hashable {
    var fortune: ZRLotBlock?
    var spirit: ZRLotBlock?
    var maxLevel: Int?
    var fortuneLongitude: Double?
    var spiritLongitude: Double?

    enum CodingKeys: String, CodingKey {
        case fortune, spirit
        case maxLevel = "max_level"
        case fortuneLongitude = "fortune_longitude"
        case spiritLongitude = "spirit_longitude"
    }
}

extension TimeLordsExtendedResult {
    var zrPayload: ZodiacalReleasingPayload? {
        zodiacalReleasing?.decodeAs(ZodiacalReleasingPayload.self)
    }
}

// MARK: - B16 PD algorithm_description

struct PDAlgorithmDescription: Codable, Hashable {
    var name: String?
    var key: String?
    var knownLimits: [String]?
    var externalCrosscheckStatus: String?
    var externalCrosscheckNote: String?

    enum CodingKeys: String, CodingKey {
        case name, key
        case knownLimits = "known_limits"
        case externalCrosscheckStatus = "external_crosscheck_status"
        case externalCrosscheckNote = "external_crosscheck_note"
    }
}

extension PrimaryDirectionsAuditResult {
    var algorithmDescriptionPayload: PDAlgorithmDescription? {
        algorithmDescription?.decodeAs(PDAlgorithmDescription.self)
    }
}

// MARK: - B17 circumambulation packet

struct BoundBoundaryRow: Codable, Identifiable, Hashable {
    var sign: String?
    var startDegree: Double?
    var endDegree: Double?
    var ruler: String?
    var rulerId: String?
    var arcValue: Double?
    var ageAtBoundary: Double?
    var estimatedDate: String?
    var isCurrent: Bool?

    var id: String {
        "\(sign ?? "")-\(startDegree.map { String($0) } ?? "")-\(ruler ?? "")-\(estimatedDate ?? "")"
    }

    enum CodingKeys: String, CodingKey {
        case sign, ruler
        case startDegree = "start_degree"
        case endDegree = "end_degree"
        case rulerId = "ruler_id"
        case arcValue = "arc_value"
        case ageAtBoundary = "age_at_boundary"
        case estimatedDate = "estimated_date"
        case isCurrent = "is_current"
    }
}

struct CircumambulationPacket: Codable, Hashable {
    var currentRuler: String?
    var currentRulerId: String?
    var currentBoundInfo: String?
    var boundSign: String?
    var boundStartDegree: Double?
    var boundEndDegree: Double?
    var boundStartDate: String?
    var boundEndDate: String?
    var currentDirectedPosition: Double?
    var startLon: Double?
    var system: String?
    var naibodRate: Double?
    var boundaries: [BoundBoundaryRow]?

    enum CodingKeys: String, CodingKey {
        case system, boundaries
        case currentRuler = "current_ruler"
        case currentRulerId = "current_ruler_id"
        case currentBoundInfo = "current_bound_info"
        case boundSign = "bound_sign"
        case boundStartDegree = "bound_start_degree"
        case boundEndDegree = "bound_end_degree"
        case boundStartDate = "bound_start_date"
        case boundEndDate = "bound_end_date"
        case currentDirectedPosition = "current_directed_position"
        case startLon = "start_lon"
        case naibodRate = "naibod_rate"
    }
}

extension DistributionPacketRow {
    var circumambulationPacket: CircumambulationPacket? {
        packet?.decodeAs(CircumambulationPacket.self)
    }
}

// MARK: - B18 prenatal packet

struct PrenatalSyzygySummary: Codable, Hashable {
    var syzygyType: String?
    var exactUtc: String?
    var exactJd: Double?
    var longitude: Double?
    var sign: String?
    var degree: Double?
    var syzygyDegreeUsed: String?
    var ruler: String?
    var methodVariant: String?

    enum CodingKeys: String, CodingKey {
        case longitude, sign, degree, ruler
        case syzygyType = "syzygy_type"
        case exactUtc = "exact_utc"
        case exactJd = "exact_jd"
        case syzygyDegreeUsed = "syzygy_degree_used"
        case methodVariant = "method_variant"
    }
}

struct PrenatalPacketSummary: Codable, Hashable {
    var prenatalSyzygy: PrenatalSyzygySummary?

    enum CodingKeys: String, CodingKey {
        case prenatalSyzygy = "prenatal_syzygy"
    }
}

extension PrenatalParansResult {
    var prenatalPacketSummary: PrenatalPacketSummary? {
        prenatalPacket?.decodeAs(PrenatalPacketSummary.self)
    }
}
