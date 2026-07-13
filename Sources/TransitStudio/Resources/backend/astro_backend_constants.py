from __future__ import annotations

from typing import ClassVar

ALL_MODES: list[str] = ["transit", "classical", "horary", "scan", "rectify",
                        "synastry", "composite", "davison", "progression", "solar_arc", "harmonic",
                        "vedic", "modern_return", "modern_timing", "midpoint"]

ALL_NODE_MODES: list[str] = ["true_node", "mean_node"]

ALL_PATTERN_IDS: list[str] = [
    "t_square", "grand_trine", "grand_cross", "kite", "yod", "mystic_rectangle", "stellium",
]

ALL_CHART_SHAPE_IDS: list[str] = [
    "bucket", "bowl", "seesaw", "splash", "splay", "locomotive", "bundle", "fan", "cradle",
]

ALL_HOUSE_SYSTEMS: list[str] = [
    "whole_sign", "placidus", "porphyry", "regiomontanus", "alcabitius", "equal",
]

ALL_ZODIACS: list[str] = ["tropical", "sidereal_lahiri", "sidereal_raman", "sidereal_krishnamurti",
                        "sidereal_yukteshwar", "sidereal_citra", "sidereal_revati",
                        "sidereal_pushya_paksha", "sidereal_suryasiddhanta"]

ALL_BOUNDS_SYSTEMS: list[str] = ["egyptian", "ptolemaic"]

ALL_TRIPLICITY_SYSTEMS: list[str] = ["dorothean", "ptolemaic"]

ALL_SCAN_KINDS: list[str] = ["aspect", "ingress", "station"]

ALL_MOON_FILTERS: list[str] = ["exclude", "include", "only"]

ALL_BODY_IDS: list[str] = [
    "SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN",
    "URANUS", "NEPTUNE", "PLUTO",
    "CHIRON", "PHOLUS", "CERES", "PALLAS", "JUNO", "VESTA",
    "MEAN_NODE", "TRUE_NODE", "SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE",
    "MEAN_LILITH", "OSCU_LILITH",
    "RAHU", "KETU",
]

CLASSICAL_BODY_IDS: list[str] = [
    "SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN",
]

ASTEROID_BODY_IDS: set[str] = {
    "CHIRON", "PHOLUS", "CERES", "PALLAS", "JUNO", "VESTA",
}

VEDIC_BODY_IDS: list[str] = [
    "SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN",
    "RAHU", "KETU",
]

ALL_VARGAS: list[str] = [
    "D1", "D2", "D3", "D4", "D6", "D7", "D8", "D9", "D10",
    "D12", "D16", "D20", "D24", "D27", "D30", "D40", "D45", "D60",
]

ALL_ASPECT_IDS: list[str] = [
    "conjunction", "opposition", "trine", "square", "sextile",
    "semisquare", "sesquisquare", "semisextile", "quincunx",
    "quintile", "biquintile",
]

# Human-readable labels for display in UI and exports
LABELS: ClassVar[dict[str, dict[str, str]]] = {
    "body_id": {
        "SUN": "太阳", "MOON": "月亮", "MERCURY": "水星", "VENUS": "金星",
        "MARS": "火星", "JUPITER": "木星", "SATURN": "土星",
        "URANUS": "天王星", "NEPTUNE": "海王星", "PLUTO": "冥王星",
        "CHIRON": "凯龙星", "PHOLUS": "Pholus", "CERES": "谷神星",
        "PALLAS": "智神星", "JUNO": "婚神星", "VESTA": "灶神星",
        "MEAN_NODE": "北交点", "TRUE_NODE": "北交点（真）",
        "SOUTH_MEAN_NODE": "南交点", "SOUTH_TRUE_NODE": "南交点（真）",
        "MEAN_LILITH": "黑月（均）", "OSCU_LILITH": "黑月（瞬）",
        "RAHU": "罗睺", "KETU": "计都",
    },
    "aspect_id": {
        "conjunction": "合相", "opposition": "冲相", "trine": "拱相",
        "square": "刑相", "sextile": "六合",         "semisquare": "半刑",
        "sesquisquare": "补八分", "semisextile": "半六合", "quincunx": "补十二分",
        "quintile": "五分相", "biquintile": "倍五分相",
    },
}
