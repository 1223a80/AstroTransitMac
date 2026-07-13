import Foundation

enum AstroConstants {
    static let allModes: [String] = ["transit", "classical", "horary", "scan", "rectify",
                                     "synastry", "composite", "davison", "progression", "solar_arc",
                                     "harmonic", "vedic", "modern_return", "modern_timing"]

    static let allHouseSystems: [String] = [
        "whole_sign", "placidus", "porphyry", "regiomontanus", "alcabitius", "equal",
    ]

    static let allZodiacs: [String] = ["tropical", "sidereal_lahiri", "sidereal_raman",
                                       "sidereal_krishnamurti", "sidereal_yukteshwar",
                                       "sidereal_citra", "sidereal_revati",
                                       "sidereal_pushya_paksha", "sidereal_suryasiddhanta"]

    // Vedic astrology options (for .vedic practice mode)
    static let allAyanamshas: [String: String] = [
        "lahiri": "Lahiri",
        "raman": "Raman",
        "krishnamurti": "Krishnamurti",
        "yukteshwar": "Yukteshwar",
        "suryasiddhanta": "Surya Siddhanta",
        "pushya_paksha": "True Pushya",
        "revati": "True Revati",
        "citra": "True Citra",
        "fagan_bradley": "Fagan-Bradley",
        "ss_revati": "SS Revati",
        "ss_citra": "SS Citra",
    ]

    static let defaultAyanamsha: String = "lahiri"

    // 9 Grahas used in Jyotish — RAHU = North Node, KETU = South Node
    static let vedicBodyIDs: [String] = [
        "SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN",
        "RAHU", "KETU",
    ]

    static let vargaIDs: [String] = [
        "D1", "D2", "D3", "D4", "D6", "D7", "D8", "D9", "D10",
        "D12", "D16", "D20", "D24", "D27", "D30", "D40", "D45", "D60",
    ]

    static let allBoundsSystems: [String] = ["egyptian", "ptolemaic"]

    static let allTriplicitySystems: [String] = ["dorothean", "ptolemaic"]

    static let allScanKinds: [String] = ["aspect", "ingress", "station"]

    static let allMoonFilters: [String] = ["exclude", "include", "only"]

    static let allBodyIDs: [String] = [
        "SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN",
        "URANUS", "NEPTUNE", "PLUTO",
        "CHIRON", "PHOLUS", "CERES", "PALLAS", "JUNO", "VESTA",
        "MEAN_NODE", "TRUE_NODE", "SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE",
        "MEAN_LILITH", "OSCU_LILITH",
        "RAHU", "KETU",
    ]

    static let classicalBodyIDs: [String] = [
        "SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN",
    ]

    static let asteroidBodyIDs: Set<String> = [
        "CHIRON", "PHOLUS", "CERES", "PALLAS", "JUNO", "VESTA",
    ]

    static let modernModes: [String] = ["synastry", "composite", "davison", "progression", "solar_arc"]

    static let allNodeModes: [String] = ["true_node", "mean_node"]

    static let allPatternIDs: [String] = [
        "t_square", "grand_trine", "grand_cross", "kite", "yod", "mystic_rectangle", "stellium",
    ]

    static let allChartShapeIDs: [String] = [
        "bucket", "bowl", "seesaw", "splash", "splay", "locomotive", "bundle", "fan", "cradle",
    ]

    static let allAspectIDs: [String] = [
        "conjunction", "opposition", "trine", "square", "sextile",
        "semisquare", "sesquisquare", "semisextile", "quincunx",
        "quintile", "biquintile",
    ]
}
