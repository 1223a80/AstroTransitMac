import Foundation

enum AstroConstants {
    static let allModes: [String] = ["transit", "classical", "horary", "scan", "rectify",
                                     "synastry", "composite", "davison", "progression", "solar_arc", "harmonic"]

    static let allHouseSystems: [String] = [
        "whole_sign", "placidus", "porphyry", "regiomontanus", "alcabitius", "equal",
    ]

    static let allZodiacs: [String] = ["tropical", "sidereal_lahiri"]

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
