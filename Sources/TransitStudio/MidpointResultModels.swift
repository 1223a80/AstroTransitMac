import Foundation

/// Metadata for one standalone 360-degree midpoint calculation.
struct MidpointMeta: Codable {
    let schemaVersion: Int
    let method: String
    let modulus: Int
    let activationOrb: Double
    let includeOppositeAxis: Bool
    let activationSources: [String]?
    let birthUTC: String
    let referenceUTC: String?
    let ephemeris: String
    let effectivePointSet: ModernPointSet

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case method
        case modulus
        case activationOrb = "activation_orb"
        case includeOppositeAxis = "include_opposite_axis"
        case activationSources = "activation_sources"
        case birthUTC = "birth_utc"
        case referenceUTC = "reference_utc"
        case ephemeris
        case effectivePointSet = "effective_point_set"
    }
}

/// One canonical A/B midpoint axis. Direct and opposite longitudes remain two
/// branches of the same stable axis ID.
struct MidpointAxis: Codable, Identifiable, Hashable {
    let id: String
    let pointAID: String
    let pointAName: String
    let pointBID: String
    let pointBName: String
    let midpointLongitude: Double
    let oppositeLongitude: Double
    let midpointText: String
    let oppositeText: String
    let trace: MidpointAxisTrace

    enum CodingKeys: String, CodingKey {
        case id
        case pointAID = "point_a_id"
        case pointAName = "point_a_name"
        case pointBID = "point_b_id"
        case pointBName = "point_b_name"
        case midpointLongitude = "midpoint_longitude"
        case oppositeLongitude = "opposite_longitude"
        case midpointText = "midpoint_text"
        case oppositeText = "opposite_text"
        case trace
    }
}

struct MidpointAxisTrace: Codable, Hashable {
    let inputLongitudes: [Double]

    enum CodingKeys: String, CodingKey {
        case inputLongitudes = "input_longitudes"
    }
}

/// A focus/source point activating one branch of a midpoint axis.
struct MidpointHit: Codable, Identifiable, Hashable {
    let id: String
    let focusPointID: String?
    let focusPointName: String?
    let sourcePointID: String
    let sourcePointName: String
    let axisID: String
    let axisBranch: String
    let hitLongitude: Double
    let axisLongitude: Double
    let separation: Double
    let orb: Double
    let sourceType: String
    let referenceUTC: String?

    enum CodingKeys: String, CodingKey {
        case id
        case focusPointID = "focus_point_id"
        case focusPointName = "focus_point_name"
        case sourcePointID = "source_point_id"
        case sourcePointName = "source_point_name"
        case axisID = "axis_id"
        case axisBranch = "axis_branch"
        case hitLongitude = "hit_longitude"
        case axisLongitude = "axis_longitude"
        case separation
        case orb
        case sourceType = "source_type"
        case referenceUTC = "reference_utc"
    }
}

struct MidpointTree: Codable, Identifiable {
    let focusPointID: String
    let focusPointName: String
    let hits: [MidpointHit]

    var id: String { focusPointID }

    enum CodingKeys: String, CodingKey {
        case focusPointID = "focus_point_id"
        case focusPointName = "focus_point_name"
        case hits
    }
}

struct MidpointResult: Codable {
    let meta: MidpointMeta
    let axes: [MidpointAxis]
    let trees: [MidpointTree]
    let snapshotActivations: [MidpointHit]
    let warnings: [String]
    let sectionErrors: [String: String]?

    enum CodingKeys: String, CodingKey {
        case meta
        case axes
        case trees
        case snapshotActivations = "snapshot_activations"
        case warnings
        case sectionErrors = "section_errors"
    }
}
