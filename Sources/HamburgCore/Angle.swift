import Foundation

/// Angle helpers shared by the whole Hamburg engine.
///
/// All longitudes are stored in the tropical ecliptic frame, in degrees,
/// normalized to `[0, 360)`. Nothing in this file depends on an ephemeris.
public enum Angle {
    /// Normalize an arbitrary finite value into `[0, 360)`.
    public static func normalize(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        let remainder = value.truncatingRemainder(dividingBy: 360)
        if remainder < 0 { return remainder + 360 }
        if remainder == 0 { return 0 }
        return remainder == 360 ? 0 : remainder
    }

    /// Signed shortest separation `from -> to` in `(-180, 180]`.
    public static func signedSeparation(_ from: Double, _ to: Double) -> Double {
        let raw = normalize(to - from)
        return raw > 180 ? raw - 360 : raw
    }

    /// Unsigned shortest separation in `[0, 180]`.
    public static func separation(_ first: Double, _ second: Double) -> Double {
        abs(signedSeparation(first, second))
    }

    /// Circular midpoint of two longitudes.
    ///
    /// The 180-degree tie-break is deterministic and matches the existing
    /// Python backend: `midpoint(0, 180) == 90`, `midpoint(180, 0) == 270`.
    /// Canonical pair ordering in the engine removes the ambiguity in reports.
    public static func midpoint(_ first: Double, _ second: Double) -> Double {
        let delta = signedSeparation(first, second)
        if abs(abs(delta) - 180) < 1e-9 {
            return normalize(first + 90)
        }
        return normalize(first + delta / 2)
    }

    /// Fold a longitude onto a dial of the given circumference.
    public static func fold(_ longitude: Double, modulus: Double) -> Double {
        guard modulus.isFinite, modulus > 0 else { return normalize(longitude) }
        let remainder = normalize(longitude).truncatingRemainder(dividingBy: modulus)
        return remainder < 0 ? remainder + modulus : remainder
    }

    /// Circular distance between two longitudes on a dial of `modulus` degrees.
    public static func dialDistance(_ first: Double, _ second: Double, modulus: Double) -> Double {
        guard modulus.isFinite, modulus > 0 else {
            return separation(first, second)
        }
        let a = fold(first, modulus: modulus)
        let b = fold(second, modulus: modulus)
        let raw = abs(a - b)
        return min(raw, modulus - raw)
    }

    /// Convert an orb expressed on the 360-degree zodiac to the given dial.
    public static func zodiacOrbToDial(_ orb: Double, modulus: Double) -> Double {
        guard modulus.isFinite, modulus > 0 else { return orb }
        return orb * modulus / 360
    }

    /// Convert an orb expressed on the given dial to 360-degree zodiac degrees.
    public static func dialOrbToZodiac(_ orb: Double, modulus: Double) -> Double {
        guard modulus.isFinite, modulus > 0 else { return orb }
        return orb * 360 / modulus
    }
}

/// A tropical zodiac sign.
public enum ZodiacSign: Int, CaseIterable, Codable, Sendable {
    case aries, taurus, gemini, cancer, leo, virgo
    case libra, scorpio, sagittarius, capricorn, aquarius, pisces

    public var name: String {
        switch self {
        case .aries: return "Aries"
        case .taurus: return "Taurus"
        case .gemini: return "Gemini"
        case .cancer: return "Cancer"
        case .leo: return "Leo"
        case .virgo: return "Virgo"
        case .libra: return "Libra"
        case .scorpio: return "Scorpio"
        case .sagittarius: return "Sagittarius"
        case .capricorn: return "Capricorn"
        case .aquarius: return "Aquarius"
        case .pisces: return "Pisces"
        }
    }

    public var nameZh: String {
        switch self {
        case .aries: return "白羊"
        case .taurus: return "金牛"
        case .gemini: return "双子"
        case .cancer: return "巨蟹"
        case .leo: return "狮子"
        case .virgo: return "处女"
        case .libra: return "天秤"
        case .scorpio: return "天蝎"
        case .sagittarius: return "射手"
        case .capricorn: return "摩羯"
        case .aquarius: return "水瓶"
        case .pisces: return "双鱼"
        }
    }

    public var glyph: String {
        switch self {
        case .aries: return "♈"
        case .taurus: return "♉"
        case .gemini: return "♊"
        case .cancer: return "♋"
        case .leo: return "♌"
        case .virgo: return "♍"
        case .libra: return "♎"
        case .scorpio: return "♏"
        case .sagittarius: return "♐"
        case .capricorn: return "♑"
        case .aquarius: return "♒"
        case .pisces: return "♓"
        }
    }

    public static func containing(_ longitude: Double) -> ZodiacSign {
        let index = Int(Angle.normalize(longitude) / 30) % 12
        return ZodiacSign(rawValue: index) ?? .aries
    }
}

/// Sign, degree-within-sign, and a compact printable representation.
public struct ZodiacPosition: Hashable, Sendable {
    public let longitude: Double
    public let sign: ZodiacSign
    public let degrees: Int
    public let minutes: Int
    public let seconds: Int

    public init(longitude: Double) {
        let normalized = Angle.normalize(longitude)
        self.longitude = normalized
        // Round once in whole-arcseconds so 29°59'59.6" carries into the
        // next sign instead of printing as 00°00'00" of the old sign.
        let totalArcseconds = Int((normalized * 3_600).rounded()) % 1_296_000
        let signIndex = totalArcseconds / 108_000
        self.sign = ZodiacSign(rawValue: signIndex) ?? .aries
        let withinSign = totalArcseconds % 108_000
        self.degrees = withinSign / 3_600
        self.minutes = (withinSign % 3_600) / 60
        self.seconds = withinSign % 60
    }

    /// Example: `12°34'56" Aries`.
    public var text: String {
        String(format: "%02d°%02d'%02d\" %@", degrees, minutes, seconds, sign.name)
    }

    /// Example: `白羊 12°34′56″`.
    public var textZh: String {
        String(format: "%@ %02d°%02d′%02d″", sign.nameZh, degrees, minutes, seconds)
    }

    /// Decimal degrees within the sign, useful for display tables.
    public var degreesInSign: Double {
        Double(degrees) + Double(minutes) / 60 + Double(seconds) / 3600
    }
}
