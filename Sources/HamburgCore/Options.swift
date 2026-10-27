import Foundation

public enum OrbUnit: String, Codable, Sendable {
    /// The orb is expressed in degrees of the 360-degree zodiac.
    case zodiac
    /// The orb is expressed in degrees on the selected dial.
    case dial
}

public enum SolarArcMethod: String, Codable, Sendable {
    case trueSun = "true_sun"
    case naibod
    case custom
}

public struct HamburgOptions: Codable, Hashable, Sendable {
    /// Dial circumference. Hamburg practice is centered on 90 degrees, but
    /// 360, 180, 45, 22.5, 11.25 and 5.625 are also meaningful.
    public var dialModulus: Double
    public var midpointOrb: Double
    public var pictureOrb: Double
    public var orbUnit: OrbUnit
    public var focusPointIDs: [String]
    public var maxPictures: Int
    public var maxHitsPerTree: Int
    public var maxAntisciaContacts: Int
    public var antisciaEnabled: Bool
    public var solarArcEnabled: Bool
    public var solarArcMethod: SolarArcMethod
    /// Required when `solarArcMethod == .custom`; degrees per tropical year.
    public var solarArcRate: Double?
    public var solarArcOrb: Double
    public var maxSolarArcHits: Int
    public var includeConverseSolarArc: Bool
    public var includeDirectedMidpoints: Bool
    /// Additional dials shown for every position. The report always contains
    /// the configured dial as well.
    public var displayDials: [Double]
    public var applyTNPlightTime: Bool

    public init(
        dialModulus: Double = 90,
        midpointOrb: Double = 1.0,
        pictureOrb: Double = 1.0,
        orbUnit: OrbUnit = .zodiac,
        focusPointIDs: [String] = ["SUN", "MOON", "ASC", "MC", "ARIES_POINT"],
        maxPictures: Int = 300,
        maxHitsPerTree: Int = 100,
        maxAntisciaContacts: Int = 200,
        antisciaEnabled: Bool = true,
        solarArcEnabled: Bool = true,
        solarArcMethod: SolarArcMethod = .trueSun,
        solarArcRate: Double? = nil,
        solarArcOrb: Double = 1.0,
        maxSolarArcHits: Int = 200,
        includeConverseSolarArc: Bool = false,
        includeDirectedMidpoints: Bool = false,
        displayDials: [Double] = [360, 90, 45, 22.5],
        applyTNPlightTime: Bool = true
    ) {
        self.dialModulus = dialModulus
        self.midpointOrb = midpointOrb
        self.pictureOrb = pictureOrb
        self.orbUnit = orbUnit
        self.focusPointIDs = focusPointIDs
        self.maxPictures = maxPictures
        self.maxHitsPerTree = maxHitsPerTree
        self.maxAntisciaContacts = maxAntisciaContacts
        self.antisciaEnabled = antisciaEnabled
        self.solarArcEnabled = solarArcEnabled
        self.solarArcMethod = solarArcMethod
        self.solarArcRate = solarArcRate
        self.solarArcOrb = solarArcOrb
        self.maxSolarArcHits = maxSolarArcHits
        self.includeConverseSolarArc = includeConverseSolarArc
        self.includeDirectedMidpoints = includeDirectedMidpoints
        self.displayDials = displayDials
        self.applyTNPlightTime = applyTNPlightTime
    }

    enum CodingKeys: String, CodingKey {
        case dialModulus = "dial_modulus"
        case midpointOrb = "midpoint_orb"
        case pictureOrb = "picture_orb"
        case orbUnit = "orb_unit"
        case focusPointIDs = "focus_point_ids"
        case maxPictures = "max_pictures"
        case maxHitsPerTree = "max_hits_per_tree"
        case maxAntisciaContacts = "max_antiscia_contacts"
        case antisciaEnabled = "antiscia_enabled"
        case solarArcEnabled = "solar_arc_enabled"
        case solarArcMethod = "solar_arc_method"
        case solarArcRate = "solar_arc_rate"
        case solarArcOrb = "solar_arc_orb"
        case maxSolarArcHits = "max_solar_arc_hits"
        case includeConverseSolarArc = "include_converse_solar_arc"
        case includeDirectedMidpoints = "include_directed_midpoints"
        case displayDials = "display_dials"
        case applyTNPlightTime = "apply_tnp_light_time"
    }

    /// Decode an options patch: every key is optional and falls back to the
    /// documented default. This keeps CLI requests small and forward
    /// compatible.
    public init(from decoder: Decoder) throws {
        let defaults = HamburgOptions()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dialModulus = try container.decodeIfPresent(Double.self, forKey: .dialModulus)
            ?? defaults.dialModulus
        self.midpointOrb = try container.decodeIfPresent(Double.self, forKey: .midpointOrb)
            ?? defaults.midpointOrb
        self.pictureOrb = try container.decodeIfPresent(Double.self, forKey: .pictureOrb)
            ?? defaults.pictureOrb
        self.orbUnit = try container.decodeIfPresent(OrbUnit.self, forKey: .orbUnit)
            ?? defaults.orbUnit
        self.focusPointIDs = try container.decodeIfPresent([String].self, forKey: .focusPointIDs)
            ?? defaults.focusPointIDs
        self.maxPictures = try container.decodeIfPresent(Int.self, forKey: .maxPictures)
            ?? defaults.maxPictures
        self.maxHitsPerTree = try container.decodeIfPresent(Int.self, forKey: .maxHitsPerTree)
            ?? defaults.maxHitsPerTree
        self.maxAntisciaContacts = try container.decodeIfPresent(Int.self, forKey: .maxAntisciaContacts)
            ?? defaults.maxAntisciaContacts
        self.antisciaEnabled = try container.decodeIfPresent(Bool.self, forKey: .antisciaEnabled)
            ?? defaults.antisciaEnabled
        self.solarArcEnabled = try container.decodeIfPresent(Bool.self, forKey: .solarArcEnabled)
            ?? defaults.solarArcEnabled
        self.solarArcMethod = try container.decodeIfPresent(SolarArcMethod.self, forKey: .solarArcMethod)
            ?? defaults.solarArcMethod
        self.solarArcRate = try container.decodeIfPresent(Double.self, forKey: .solarArcRate)
        self.solarArcOrb = try container.decodeIfPresent(Double.self, forKey: .solarArcOrb)
            ?? defaults.solarArcOrb
        self.maxSolarArcHits = try container.decodeIfPresent(Int.self, forKey: .maxSolarArcHits)
            ?? defaults.maxSolarArcHits
        self.includeConverseSolarArc = try container.decodeIfPresent(Bool.self, forKey: .includeConverseSolarArc)
            ?? defaults.includeConverseSolarArc
        self.includeDirectedMidpoints = try container.decodeIfPresent(Bool.self, forKey: .includeDirectedMidpoints)
            ?? defaults.includeDirectedMidpoints
        self.displayDials = try container.decodeIfPresent([Double].self, forKey: .displayDials)
            ?? defaults.displayDials
        self.applyTNPlightTime = try container.decodeIfPresent(Bool.self, forKey: .applyTNPlightTime)
            ?? defaults.applyTNPlightTime
    }

    public var dialOrbForMidpoints: Double {
        orbUnit == .zodiac ? Angle.zodiacOrbToDial(midpointOrb, modulus: dialModulus) : midpointOrb
    }

    public var dialOrbForPictures: Double {
        orbUnit == .zodiac ? Angle.zodiacOrbToDial(pictureOrb, modulus: dialModulus) : pictureOrb
    }

    public var dialOrbForSolarArc: Double {
        orbUnit == .zodiac ? Angle.zodiacOrbToDial(solarArcOrb, modulus: dialModulus) : solarArcOrb
    }

    /// Normalize values that could break the geometry, recording a warning
    /// instead of silently producing nonsense.
    public func normalized() -> (options: HamburgOptions, warnings: [String]) {
        var copy = self
        var warnings: [String] = []
        if !copy.dialModulus.isFinite || copy.dialModulus < 1 || copy.dialModulus > 360 {
            warnings.append("dial_modulus must be in [1, 360]; using 90.")
            copy.dialModulus = 90
        } else {
            let harmonicCount = 360.0 / copy.dialModulus
            if abs(harmonicCount - harmonicCount.rounded()) > 1e-9 {
                warnings.append("dial_modulus should divide 360 evenly; using 90.")
                copy.dialModulus = 90
            }
        }
        if !copy.midpointOrb.isFinite || copy.midpointOrb < 0 {
            warnings.append("midpoint_orb must be finite and non-negative; using 1.0.")
            copy.midpointOrb = 1.0
        }
        if !copy.pictureOrb.isFinite || copy.pictureOrb < 0 {
            warnings.append("picture_orb must be finite and non-negative; using 1.0.")
            copy.pictureOrb = 1.0
        }
        if !copy.solarArcOrb.isFinite || copy.solarArcOrb < 0 {
            warnings.append("solar_arc_orb must be finite and non-negative; using 1.0.")
            copy.solarArcOrb = 1.0
        }
        copy.maxPictures = max(1, min(copy.maxPictures, 5_000))
        copy.maxHitsPerTree = max(1, min(copy.maxHitsPerTree, 2_000))
        copy.maxAntisciaContacts = max(1, min(copy.maxAntisciaContacts, 2_000))
        copy.maxSolarArcHits = max(1, min(copy.maxSolarArcHits, 2_000))
        copy.focusPointIDs = copy.focusPointIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
        if copy.focusPointIDs.isEmpty {
            copy.focusPointIDs = ["SUN", "MOON", "ASC", "MC", "ARIES_POINT"]
        }
        if let rate = copy.solarArcRate, !rate.isFinite {
            warnings.append("solar_arc_rate must be finite; ignoring it.")
            copy.solarArcRate = nil
        }
        if copy.solarArcMethod == .custom, copy.solarArcRate == nil {
            warnings.append("solar_arc_method=custom requires solar_arc_rate; using Naibod.")
            copy.solarArcMethod = .naibod
        }
        var dials: [Double] = []
        for dial in copy.displayDials where dial.isFinite && dial >= 1 && dial <= 360 {
            if !dials.contains(where: { abs($0 - dial) < 1e-9 }) { dials.append(dial) }
        }
        if !dials.contains(where: { abs($0 - copy.dialModulus) < 1e-9 }) {
            dials.insert(copy.dialModulus, at: 0)
        }
        copy.displayDials = dials
        return (copy, warnings)
    }
}

/// Nearest point on a dial lattice and its relationship to the canonical
/// midpoint axis. This is the single primitive behind midpoint trees,
/// planetary pictures, solar-arc contacts and antiscia contacts.
public struct DialProximity: Hashable, Sendable {
    public let distance: Double
    public let nearestLongitude: Double
    public let harmonic: Int
    public let branch: String
    public let harmonicCount: Int
}

public enum DialMath {
    public static func proximity(
        longitude: Double,
        axis: Double,
        modulus: Double
    ) -> DialProximity {
        let safeModulus = max(1e-9, modulus)
        let rawK = (longitude - axis) / safeModulus
        let k = rawK.rounded()
        let nearest = Angle.normalize(axis + k * safeModulus)
        let distance = abs(Angle.signedSeparation(nearest, longitude))
        let count = max(1, Int((360.0 / safeModulus).rounded()))
        var harmonic = Int(k.truncatingRemainder(dividingBy: Double(count)))
        if harmonic < 0 { harmonic += count }
        let branch = Int(k.truncatingRemainder(dividingBy: 2)) == 0 ? "direct" : "opposite"
        return DialProximity(
            distance: distance,
            nearestLongitude: nearest,
            harmonic: harmonic,
            branch: branch,
            harmonicCount: count
        )
    }

    /// Convert a dial distance to the equivalent 360-degree orb used in
    /// reports. This is a harmonic-scaled orb, not the raw ecliptic
    /// separation to the direct midpoint.
    public static func zodiacOrb(fromDialDistance distance: Double, modulus: Double) -> Double {
        distance * 360.0 / max(1e-9, modulus)
    }
}
