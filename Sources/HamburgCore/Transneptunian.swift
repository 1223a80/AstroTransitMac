import Foundation

/// The eight hypothetical Trans-Neptunian planets of the Hamburg School.
public enum UranianPlanet: String, CaseIterable, Codable, Sendable {
    case cupido = "CUPIDO"
    case hades = "HADES"
    case zeus = "ZEUS"
    case kronos = "KRONOS"
    case apollon = "APOLLON"
    case admetos = "ADMETOS"
    case vulkanus = "VULKANUS"
    case poseidon = "POSEIDON"

    public var displayName: String {
        switch self {
        case .cupido: return "Cupido"
        case .hades: return "Hades"
        case .zeus: return "Zeus"
        case .kronos: return "Kronos"
        case .apollon: return "Apollon"
        case .admetos: return "Admetos"
        case .vulkanus: return "Vulkanus"
        case .poseidon: return "Poseidon"
        }
    }

    /// Two-letter abbreviation used in Uranian shorthand.
    public var abbreviation: String {
        switch self {
        case .cupido: return "Cu"
        case .hades: return "Ha"
        case .zeus: return "Ze"
        case .kronos: return "Kr"
        case .apollon: return "Ap"
        case .admetos: return "Ad"
        case .vulkanus: return "Vu"
        case .poseidon: return "Po"
        }
    }

    /// Short traditional keyword set, not a full delineation.
    public var keywords: [String] {
        switch self {
        case .cupido: return ["union", "family", "art", "community"]
        case .hades: return ["past", "depth", "decay", "hidden"]
        case .zeus: return ["creative fire", "technology", "leadership"]
        case .kronos: return ["authority", "mastery", "state"]
        case .apollon: return ["expansion", "commerce", "science"]
        case .admetos: return ["concentration", "block", "raw material"]
        case .vulkanus: return ["power", "force", "intensity"]
        case .poseidon: return ["spirit", "mind", "ideology"]
        }
    }

    public var keywordsZh: [String] {
        switch self {
        case .cupido: return ["结合", "家庭", "艺术", "社群"]
        case .hades: return ["过去", "深层", "衰变", "隐藏"]
        case .zeus: return ["创造之火", "技术", "领导"]
        case .kronos: return ["权威", "精通", "国家"]
        case .apollon: return ["扩张", "商业", "科学"]
        case .admetos: return ["集中", "阻塞", "原料"]
        case .vulkanus: return ["力量", "强制", "强度"]
        case .poseidon: return ["精神", "心智", "意识形态"]
        }
    }

    public var elements: TNPOrbitalElements {
        switch self {
        case .cupido:
            return .init(meanAnomalyDeg: 163.7409, semiMajorAxisAU: 40.99837,
                         eccentricity: 0.00460, perihelionDeg: 171.4333,
                         nodeDeg: 129.8325, inclinationDeg: 1.0833)
        case .hades:
            return .init(meanAnomalyDeg: 27.6496, semiMajorAxisAU: 50.66744,
                         eccentricity: 0.00245, perihelionDeg: 148.1796,
                         nodeDeg: 161.3339, inclinationDeg: 1.0500)
        case .zeus:
            return .init(meanAnomalyDeg: 165.1232, semiMajorAxisAU: 59.21436,
                         eccentricity: 0.00120, perihelionDeg: 299.0440,
                         nodeDeg: 0, inclinationDeg: 0)
        case .kronos:
            return .init(meanAnomalyDeg: 169.0193, semiMajorAxisAU: 64.81960,
                         eccentricity: 0.00305, perihelionDeg: 208.8801,
                         nodeDeg: 0, inclinationDeg: 0)
        case .apollon:
            return .init(meanAnomalyDeg: 138.0533, semiMajorAxisAU: 70.29949,
                         eccentricity: 0, perihelionDeg: 0,
                         nodeDeg: 0, inclinationDeg: 0)
        case .admetos:
            return .init(meanAnomalyDeg: 351.3350, semiMajorAxisAU: 73.62765,
                         eccentricity: 0, perihelionDeg: 0,
                         nodeDeg: 0, inclinationDeg: 0)
        case .vulkanus:
            return .init(meanAnomalyDeg: 55.8983, semiMajorAxisAU: 77.25568,
                         eccentricity: 0, perihelionDeg: 0,
                         nodeDeg: 0, inclinationDeg: 0)
        case .poseidon:
            return .init(meanAnomalyDeg: 165.5163, semiMajorAxisAU: 83.66907,
                         eccentricity: 0, perihelionDeg: 0,
                         nodeDeg: 0, inclinationDeg: 0)
        }
    }

    /// Keplerian period in tropical years.
    public var periodYears: Double {
        pow(elements.semiMajorAxisAU, 1.5)
    }
}

/// James Neely's revised 1980 elements, in the J1900 ecliptic frame.
///
/// The literal table is the one documented by Swiss Ephemeris as
/// "Neely 1980, Matrix Magazine VII, Table I". The values are facts; this
/// implementation is independent and does not copy Swiss Ephemeris code.
public struct TNPOrbitalElements: Hashable, Sendable {
    public let epochJulianDay: Double
    public let meanAnomalyDeg: Double
    public let semiMajorAxisAU: Double
    public let eccentricity: Double
    public let perihelionDeg: Double
    public let nodeDeg: Double
    public let inclinationDeg: Double

    public init(
        epochJulianDay: Double = Precession.j1900,
        meanAnomalyDeg: Double,
        semiMajorAxisAU: Double,
        eccentricity: Double,
        perihelionDeg: Double,
        nodeDeg: Double,
        inclinationDeg: Double
    ) {
        self.epochJulianDay = epochJulianDay
        self.meanAnomalyDeg = meanAnomalyDeg
        self.semiMajorAxisAU = semiMajorAxisAU
        self.eccentricity = eccentricity
        self.perihelionDeg = perihelionDeg
        self.nodeDeg = nodeDeg
        self.inclinationDeg = inclinationDeg
    }
}

public struct TransneptunianPosition: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let abbreviation: String
    public let heliocentricLongitude: Double
    public let heliocentricLatitude: Double
    public let heliocentricDistanceAU: Double
    public let longitude: Double
    public let latitude: Double
    public let distanceAU: Double
    public let speed: Double?
    public let keywords: [String]
    public let keywordsZh: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, abbreviation, longitude, latitude, speed, keywords
        case heliocentricLongitude = "heliocentric_longitude"
        case heliocentricLatitude = "heliocentric_latitude"
        case heliocentricDistanceAU = "heliocentric_distance_au"
        case distanceAU = "distance_au"
        case keywordsZh = "keywords_zh"
    }
}

/// Native Keplerian ephemeris for the eight Hamburg School points.
public enum TransneptunianEphemeris {
    /// Light travels one AU in this many days.
    private static let lightTimeDaysPerAU = 499.004784 / 86_400.0
    private static let gaussianDailyMotion = 0.9856076686

    public static func heliocentricPosition(
        planet: UranianPlanet,
        julianDay: Double
    ) -> Vector3 {
        guard julianDay.isFinite else { return .zero }
        let elements = planet.elements
        let dailyMotion = gaussianDailyMotion / pow(elements.semiMajorAxisAU, 1.5)
        let meanAnomaly = Angle.normalize(
            elements.meanAnomalyDeg + dailyMotion * (julianDay - elements.epochJulianDay)
        ) * Double.pi / 180
        let eccentricAnomaly = solveKepler(meanAnomaly: meanAnomaly, eccentricity: elements.eccentricity)

        let xOrbital = elements.semiMajorAxisAU * (cos(eccentricAnomaly) - elements.eccentricity)
        let yOrbital = elements.semiMajorAxisAU
            * (1 - elements.eccentricity * elements.eccentricity).squareRoot()
            * sin(eccentricAnomaly)

        let perihelion = elements.perihelionDeg * Double.pi / 180
        let node = elements.nodeDeg * Double.pi / 180
        let inclination = elements.inclinationDeg * Double.pi / 180
        let cosPeri = cos(perihelion), sinPeri = sin(perihelion)
        let cosNode = cos(node), sinNode = sin(node)
        let cosInclination = cos(inclination), sinInclination = sin(inclination)

        let x = (cosPeri * cosNode - sinPeri * cosInclination * sinNode) * xOrbital
            + (-sinPeri * cosNode - cosPeri * cosInclination * sinNode) * yOrbital
        let y = (cosPeri * sinNode + sinPeri * cosInclination * cosNode) * xOrbital
            + (-sinPeri * sinNode + cosPeri * cosInclination * cosNode) * yOrbital
        let z = (sinPeri * sinInclination) * xOrbital
            + (cosPeri * sinInclination) * yOrbital

        let distance = (x * x + y * y + z * z).squareRoot()
        guard distance > 0 else { return .zero }
        let longitude = Angle.normalize(atan2(y, x) * 180 / .pi)
        let latitude = asin(max(-1, min(1, z / distance))) * 180 / .pi
        let (precessedLongitude, precessedLatitude) = Precession.precessEcliptic(
            longitude: longitude,
            latitude: latitude,
            from: elements.epochJulianDay,
            to: julianDay
        )
        return sphericalVector(
            longitude: precessedLongitude,
            latitude: precessedLatitude,
            distance: distance
        )
    }

    public static func geocentricPosition(
        planet: UranianPlanet,
        julianDay: Double,
        solar: SolarReference? = nil,
        applyLightTime: Bool = true
    ) -> TransneptunianPosition {
        let solar = solar ?? SolarEphemeris.reference(julianDay: julianDay)
        let current = geocentricVector(
            planet: planet,
            julianDay: julianDay,
            solar: solar,
            applyLightTime: applyLightTime
        )
        let before = geocentricVector(
            planet: planet,
            julianDay: julianDay - 0.5,
            solar: solar,
            applyLightTime: applyLightTime
        ).geocentric.longitude
        let after = geocentricVector(
            planet: planet,
            julianDay: julianDay + 0.5,
            solar: solar,
            applyLightTime: applyLightTime
        ).geocentric.longitude

        return TransneptunianPosition(
            id: planet.rawValue,
            name: planet.displayName,
            abbreviation: planet.abbreviation,
            heliocentricLongitude: current.heliocentric.longitude,
            heliocentricLatitude: current.heliocentric.latitude,
            heliocentricDistanceAU: current.heliocentric.length,
            longitude: current.geocentric.longitude,
            latitude: current.geocentric.latitude,
            distanceAU: current.geocentric.length,
            speed: Angle.signedSeparation(before, after),
            keywords: planet.keywords,
            keywordsZh: planet.keywordsZh
        )
    }

    public static func geocentricPositions(
        julianDay: Double,
        solar: SolarReference? = nil,
        applyLightTime: Bool = true
    ) -> [TransneptunianPosition] {
        UranianPlanet.allCases.map {
            geocentricPosition(
                planet: $0,
                julianDay: julianDay,
                solar: solar,
                applyLightTime: applyLightTime
            )
        }
    }

    private static func geocentricVector(
        planet: UranianPlanet,
        julianDay: Double,
        solar: SolarReference,
        applyLightTime: Bool
    ) -> (heliocentric: Vector3, geocentric: Vector3) {
        guard julianDay.isFinite else { return (.zero, .zero) }
        let solarDistance = solar.distanceAU.isFinite && solar.distanceAU > 0
            ? solar.distanceAU
            : SolarEphemeris.distanceAU(julianDay: julianDay)
        let sunVector = sphericalVector(
            longitude: solar.longitude,
            latitude: solar.latitude,
            distance: solarDistance
        )
        var heliocentric = heliocentricPosition(planet: planet, julianDay: julianDay)
        if applyLightTime {
            var geocentricDistance = (heliocentric + sunVector).length
            for _ in 0..<2 {
                let lightTime = geocentricDistance * lightTimeDaysPerAU
                heliocentric = heliocentricPosition(planet: planet, julianDay: julianDay - lightTime)
                geocentricDistance = (heliocentric + sunVector).length
            }
        }
        return (heliocentric, heliocentric + sunVector)
    }

    private static func solveKepler(meanAnomaly: Double, eccentricity: Double) -> Double {
        var eccentricAnomaly = meanAnomaly
        for _ in 0..<30 {
            let delta = (eccentricAnomaly - eccentricity * sin(eccentricAnomaly) - meanAnomaly)
                / (1 - eccentricity * cos(eccentricAnomaly))
            eccentricAnomaly -= delta
            if abs(delta) < 1e-14 { break }
        }
        return eccentricAnomaly
    }

    private static func sphericalVector(
        longitude: Double,
        latitude: Double,
        distance: Double
    ) -> Vector3 {
        let l = longitude * Double.pi / 180
        let b = latitude * Double.pi / 180
        return Vector3(
            x: distance * cos(b) * cos(l),
            y: distance * cos(b) * sin(l),
            z: distance * sin(b)
        )
    }
}
