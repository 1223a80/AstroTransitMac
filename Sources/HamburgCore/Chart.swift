import Foundation

public struct ChartLocation: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var timezone: String?
    public var backendHouseSystem: String?

    public init(
        latitude: Double,
        longitude: Double,
        timezone: String? = nil,
        backendHouseSystem: String? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
        self.backendHouseSystem = backendHouseSystem
    }

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, timezone
        case backendHouseSystem = "backend_house_system"
    }
}

public struct ChartPoint: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case planet
        case transneptunian
        case angle
        case node
        case axis
        case lot
        case custom
    }

    public enum Source: String, Codable, Sendable {
        case backend
        case nativeTNP = "native_tnp"
        case user
        case calculated
    }

    public let id: String
    public let name: String
    public let nameLocal: String?
    public let kind: Kind
    public let longitude: Double
    public let latitude: Double?
    public let speed: Double?
    public let source: Source
    public let keywords: [String]
    public let keywordsZh: [String]
    public var house: Int?

    public init(
        id: String,
        name: String? = nil,
        nameLocal: String? = nil,
        kind: Kind,
        longitude: Double,
        latitude: Double? = nil,
        speed: Double? = nil,
        source: Source = .user,
        keywords: [String] = [],
        keywordsZh: [String] = [],
        house: Int? = nil
    ) {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.id = normalizedID
        self.name = name ?? ChartPoint.defaultName(for: normalizedID)
        self.nameLocal = nameLocal
        self.kind = kind
        self.longitude = Angle.normalize(longitude)
        self.latitude = latitude
        self.speed = speed
        self.source = source
        if keywords.isEmpty, let planet = UranianPlanet(rawValue: normalizedID) {
            self.keywords = planet.keywords
            self.keywordsZh = planet.keywordsZh
        } else {
            self.keywords = keywords
            self.keywordsZh = keywordsZh
        }
        self.house = house
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind, longitude, latitude, speed, source, keywords, house
        case nameLocal = "name_local"
        case keywordsZh = "keywords_zh"
    }

    public func withHouse(_ house: Int?) -> ChartPoint {
        var copy = self
        copy.house = house
        return copy
    }

    public static func transneptunian(_ position: TransneptunianPosition) -> ChartPoint {
        ChartPoint(
            id: position.id,
            name: position.name,
            kind: .transneptunian,
            longitude: position.longitude,
            latitude: position.latitude,
            speed: position.speed,
            source: .nativeTNP,
            keywords: position.keywords,
            keywordsZh: position.keywordsZh
        )
    }

    private static func defaultName(for id: String) -> String {
        switch id {
        case "SUN": return "Sun"
        case "MOON": return "Moon"
        case "MERCURY": return "Mercury"
        case "VENUS": return "Venus"
        case "MARS": return "Mars"
        case "JUPITER": return "Jupiter"
        case "SATURN": return "Saturn"
        case "URANUS": return "Uranus"
        case "NEPTUNE": return "Neptune"
        case "PLUTO": return "Pluto"
        case "TRUE_NODE", "MEAN_NODE": return "Lunar Node"
        case "SOUTH_TRUE_NODE", "SOUTH_MEAN_NODE": return "South Node"
        case "ASC": return "Ascendant"
        case "MC": return "Midheaven"
        case "DSC": return "Descendant"
        case "IC": return "Imum Coeli"
        case "ARIES_POINT": return "Aries Point"
        case "CUPIDO": return "Cupido"
        case "HADES": return "Hades"
        case "ZEUS": return "Zeus"
        case "KRONOS": return "Kronos"
        case "APOLLON": return "Apollon"
        case "ADMETOS": return "Admetos"
        case "VULKANUS": return "Vulkanus"
        case "POSEIDON": return "Poseidon"
        default: return id
        }
    }
}

public enum HouseAssignment: String, Codable, Sendable {
    /// Witte's equal houses beginning at 0° Libra = house I.
    case hamburg
    /// Use the twelve cusps supplied by the existing Python backend.
    case backend
}

public enum HamburgHouses {
    /// Fixed Witte houses: equal 30-degree houses, 0° Libra starts house I.
    public static let hamburgCusps: [Double] = (0..<12).map {
        Angle.normalize(180 + Double($0) * 30)
    }

    public static func house(for longitude: Double, cusps: [Double]) -> Int {
        guard cusps.count == 12 else {
            return house(for: longitude, cusps: hamburgCusps)
        }
        let normalized = Angle.normalize(longitude)
        for index in 0..<12 {
            let start = Angle.normalize(cusps[index])
            let end = Angle.normalize(cusps[(index + 1) % 12])
            let span = Angle.normalize(end - start)
            let offset = Angle.normalize(normalized - start)
            if span <= 1e-9 {
                if abs(offset) <= 1e-9 { return index + 1 }
                continue
            }
            if offset < span - 1e-9 {
                return index + 1
            }
            if abs(offset) <= 1e-9 {
                return index + 1
            }
        }
        return 1
    }
}

public struct HamburgChart: Sendable {
    public let julianDayUT: Double
    public let moment: Moment?
    public let location: ChartLocation?
    public let points: [ChartPoint]
    public let houseAssignment: HouseAssignment
    public let cusps: [Double]
    public let backendCusps: [Double]
    public let warnings: [String]

    public init(
        julianDayUT: Double,
        moment: Moment? = nil,
        location: ChartLocation? = nil,
        points: [ChartPoint],
        backendCusps: [Double] = [],
        houseAssignment: HouseAssignment = .hamburg,
        includeAriesPoint: Bool = true,
        warnings: [String] = []
    ) {
        var mutableWarnings = warnings
        var unique: [String: ChartPoint] = [:]
        var ordered: [ChartPoint] = []
        for point in points {
            if unique[point.id] != nil {
                mutableWarnings.append("Duplicate point id \(point.id) ignored.")
                continue
            }
            unique[point.id] = point
            ordered.append(point)
        }
        if includeAriesPoint && unique["ARIES_POINT"] == nil {
            let aries = ChartPoint(
                id: "ARIES_POINT",
                name: "Aries Point",
                kind: .axis,
                longitude: 0,
                source: .calculated
            )
            unique["ARIES_POINT"] = aries
            ordered.append(aries)
        }

        var effectiveAssignment = houseAssignment
        var effectiveCusps: [Double]
        if houseAssignment == .backend, backendCusps.count == 12 {
            effectiveCusps = backendCusps.map(Angle.normalize)
        } else {
            if houseAssignment == .backend {
                mutableWarnings.append("Backend house cusps missing or incomplete; using Hamburg houses.")
            }
            effectiveAssignment = .hamburg
            effectiveCusps = HamburgHouses.hamburgCusps
        }

        let withHouses = ordered.map {
            $0.withHouse(HamburgHouses.house(for: $0.longitude, cusps: effectiveCusps))
        }
        self.julianDayUT = julianDayUT
        self.moment = moment
        self.location = location
        self.points = withHouses.sorted(by: HamburgChart.canonicalOrder)
        self.houseAssignment = effectiveAssignment
        self.cusps = effectiveCusps
        self.backendCusps = backendCusps
        self.warnings = mutableWarnings
    }

    public var pointsByID: [String: ChartPoint] {
        Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0) })
    }

    public var ariesPoint: ChartPoint? {
        pointsByID["ARIES_POINT"]
    }

    public var sun: ChartPoint? {
        pointsByID["SUN"]
    }

    /// Add all eight native TNPs to a chart built from backend positions.
    public static func addingTransneptunians(
        to points: [ChartPoint],
        julianDayUT: Double,
        moment: Moment? = nil,
        location: ChartLocation? = nil,
        backendCusps: [Double] = [],
        houseAssignment: HouseAssignment = .hamburg,
        includeAriesPoint: Bool = true,
        warnings: [String] = [],
        solar: SolarReference? = nil,
        applyLightTime: Bool = true
    ) -> HamburgChart {
        let existingIDs = Set(points.map(\.id))
        let tnps = TransneptunianEphemeris.geocentricPositions(
            julianDay: julianDayUT,
            solar: solar,
            applyLightTime: applyLightTime
        )
        let tnpPoints = tnps
            .filter { !existingIDs.contains($0.id) }
            .map(ChartPoint.transneptunian)
        return HamburgChart(
            julianDayUT: julianDayUT,
            moment: moment,
            location: location,
            points: points + tnpPoints,
            backendCusps: backendCusps,
            houseAssignment: houseAssignment,
            includeAriesPoint: includeAriesPoint,
            warnings: warnings
        )
    }

    private static let rank: [String: Int] = {
        let standard = [
            "SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN",
            "URANUS", "NEPTUNE", "PLUTO",
        ]
        var result: [String: Int] = [:]
        for (index, id) in standard.enumerated() { result[id] = index }
        result["TRUE_NODE"] = 20
        result["MEAN_NODE"] = 21
        result["SOUTH_TRUE_NODE"] = 22
        result["SOUTH_MEAN_NODE"] = 23
        for (index, planet) in UranianPlanet.allCases.enumerated() {
            result[planet.rawValue] = 40 + index
        }
        result["ASC"] = 60
        result["MC"] = 61
        result["DSC"] = 62
        result["IC"] = 63
        result["ARIES_POINT"] = 80
        return result
    }()

    public static func canonicalOrder(_ lhs: ChartPoint, _ rhs: ChartPoint) -> Bool {
        let left = rank[lhs.id] ?? 1_000
        let right = rank[rhs.id] ?? 1_000
        if left != right { return left < right }
        return lhs.id < rhs.id
    }
}
