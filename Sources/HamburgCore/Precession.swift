import Foundation

public struct Vector3: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vector3(x: 0, y: 0, z: 0)

    public var length: Double {
        (x * x + y * y + z * z).squareRoot()
    }

    public var longitude: Double {
        Angle.normalize(atan2(y, x) * 180 / .pi)
    }

    public var latitude: Double {
        guard length > 0 else { return 0 }
        return asin(max(-1, min(1, z / length))) * 180 / .pi
    }

    public static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    public static func * (lhs: Double, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs * rhs.x, y: lhs * rhs.y, z: lhs * rhs.z)
    }
}

/// Row-major 3x3 matrix used for equatorial precession.
public struct Matrix3: Sendable {
    public let rows: [[Double]]

    public init(_ rows: [[Double]]) {
        precondition(rows.count == 3 && rows.allSatisfy { $0.count == 3 })
        self.rows = rows
    }

    public func apply(_ vector: Vector3) -> Vector3 {
        Vector3(
            x: rows[0][0] * vector.x + rows[0][1] * vector.y + rows[0][2] * vector.z,
            y: rows[1][0] * vector.x + rows[1][1] * vector.y + rows[1][2] * vector.z,
            z: rows[2][0] * vector.x + rows[2][1] * vector.y + rows[2][2] * vector.z
        )
    }

    public var transposed: Matrix3 {
        Matrix3([
            [rows[0][0], rows[1][0], rows[2][0]],
            [rows[0][1], rows[1][1], rows[2][1]],
            [rows[0][2], rows[1][2], rows[2][2]],
        ])
    }
}

/// Ecliptic frame rotation and IAU 1976 precession.
///
/// The TNP orbital elements are referred to the ecliptic and equinox of
/// J1900. Positions are rotated to the ecliptic and equinox of date before
/// the geocentric step. This matches the frame convention used by Swiss
/// Ephemeris for the same Neely elements.
public enum Precession {
    public static let j2000 = 2_451_545.0
    public static let j1900 = 2_415_020.0

    /// Mean obliquity of the ecliptic in degrees (Meeus, eq. 22.2).
    public static func meanObliquity(julianDay: Double) -> Double {
        let t = (julianDay - j2000) / 36_525.0
        let seconds = 21.448
            - 46.8150 * t
            - 0.00059 * t * t
            + 0.001813 * t * t * t
        return 23.0 + 26.0 / 60.0 + seconds / 3_600.0
    }

    /// Equatorial rotation from J2000 to `julianDay` (IAU 1976).
    public static func matrix(julianDay: Double) -> Matrix3 {
        let t = (julianDay - j2000) / 36_525.0
        let arcsecondsToRadians = Double.pi / (180.0 * 3_600.0)
        let zeta = (2_306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t) * arcsecondsToRadians
        let z = (2_306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t) * arcsecondsToRadians
        let theta = (2_004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t) * arcsecondsToRadians

        let cz = cos(z), sz = sin(z)
        let ct = cos(theta), st = sin(theta)
        let czeta = cos(zeta), szeta = sin(zeta)

        return Matrix3([
            [
                cz * ct * czeta - sz * szeta,
                -cz * ct * szeta - sz * czeta,
                -cz * st,
            ],
            [
                sz * ct * czeta + cz * szeta,
                -sz * ct * szeta + cz * czeta,
                -sz * st,
            ],
            [
                st * czeta,
                -st * szeta,
                ct,
            ],
        ])
    }

    public static func eclipticToEquatorial(
        longitude: Double,
        latitude: Double,
        obliquity: Double
    ) -> Vector3 {
        let l = longitude * Double.pi / 180
        let b = latitude * Double.pi / 180
        let e = obliquity * Double.pi / 180
        let x = cos(b) * cos(l)
        let y = cos(b) * sin(l)
        let z = sin(b)
        return Vector3(
            x: x,
            y: y * cos(e) - z * sin(e),
            z: y * sin(e) + z * cos(e)
        )
    }

    public static func equatorialToEcliptic(_ vector: Vector3, obliquity: Double) -> (longitude: Double, latitude: Double) {
        let e = obliquity * Double.pi / 180
        let x = vector.x
        let y = vector.y * cos(e) + vector.z * sin(e)
        let z = -vector.y * sin(e) + vector.z * cos(e)
        let r = (x * x + y * y + z * z).squareRoot()
        let longitude = Angle.normalize(atan2(y, x) * 180 / .pi)
        let latitude = r > 0 ? asin(max(-1, min(1, z / r))) * 180 / .pi : 0
        return (longitude, latitude)
    }

    /// Precess an ecliptic position from one equinox to another.
    public static func precessEcliptic(
        longitude: Double,
        latitude: Double,
        from sourceJD: Double,
        to targetJD: Double
    ) -> (longitude: Double, latitude: Double) {
        let sourceObliquity = meanObliquity(julianDay: sourceJD)
        let targetObliquity = meanObliquity(julianDay: targetJD)
        let sourceVector = eclipticToEquatorial(
            longitude: longitude,
            latitude: latitude,
            obliquity: sourceObliquity
        )
        // matrix(source) maps J2000 -> source, so its transpose maps source -> J2000.
        let j2000Vector = matrix(julianDay: sourceJD).transposed.apply(sourceVector)
        let targetVector = matrix(julianDay: targetJD).apply(j2000Vector)
        return equatorialToEcliptic(targetVector, obliquity: targetObliquity)
    }
}
