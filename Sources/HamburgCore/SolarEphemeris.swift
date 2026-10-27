import Foundation

/// Geocentric solar reference used to convert heliocentric TNP positions
/// into geocentric ones, and to derive true-solar-arc directions.
public struct SolarReference: Codable, Hashable, Sendable {
    public let longitude: Double
    public let latitude: Double
    public let distanceAU: Double

    public init(longitude: Double, latitude: Double = 0, distanceAU: Double = 1) {
        self.longitude = Angle.normalize(longitude)
        self.latitude = latitude
        self.distanceAU = distanceAU
    }

    enum CodingKeys: String, CodingKey {
        case longitude, latitude
        case distanceAU = "distance_au"
    }
}

/// Compact solar ephemeris based on Meeus, *Astronomical Algorithms*.
///
/// Accuracy is about 0.01 degrees for the longitude and a few 1e-5 AU for
/// the radius over 1800-2200. That is far below the precision of the
/// hypothetical TNP orbits and of astrological dial work. When the CLI has
/// the Python backend's Sun longitude, that authoritative value is used
/// instead of this fallback.
public enum SolarEphemeris {
    public static func apparentLongitude(julianDay: Double) -> Double {
        let t = (julianDay - Precession.j2000) / 36_525.0
        let meanLongitude = normalize(280.46646 + 36_000.76983 * t + 0.0003032 * t * t)
        let meanAnomaly = normalize(357.52911 + 35_999.05029 * t - 0.0001537 * t * t)
        let m = meanAnomaly * Double.pi / 180
        let equationOfCenter =
            (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(m)
            + (0.019993 - 0.000101 * t) * sin(2 * m)
            + 0.000289 * sin(3 * m)
        let trueLongitude = meanLongitude + equationOfCenter
        let node = (125.04 - 1_934.136 * t) * Double.pi / 180
        return normalize(trueLongitude - 0.00569 - 0.00478 * sin(node))
    }

    public static func distanceAU(julianDay: Double) -> Double {
        let t = (julianDay - Precession.j2000) / 36_525.0
        let meanAnomaly = normalize(357.52911 + 35_999.05029 * t - 0.0001537 * t * t)
        let m = meanAnomaly * Double.pi / 180
        let equationOfCenter =
            (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(m)
            + (0.019993 - 0.000101 * t) * sin(2 * m)
            + 0.000289 * sin(3 * m)
        let trueAnomaly = (meanAnomaly + equationOfCenter) * Double.pi / 180
        let eccentricity = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t
        let numerator = 1.000001018 * (1 - eccentricity * eccentricity)
        return numerator / (1 + eccentricity * cos(trueAnomaly))
    }

    public static func reference(julianDay: Double) -> SolarReference {
        SolarReference(
            longitude: apparentLongitude(julianDay: julianDay),
            latitude: 0,
            distanceAU: distanceAU(julianDay: julianDay)
        )
    }

    private static func normalize(_ value: Double) -> Double {
        Angle.normalize(value)
    }
}
