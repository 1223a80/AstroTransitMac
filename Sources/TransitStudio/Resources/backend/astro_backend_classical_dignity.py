from __future__ import annotations

from typing import Any

from astro_backend_core import (
    SIGN_RULERS,
    angular_separation,
    norm360,
    planet_name,
    sign_degree,
    zodiac_sign_index,
)

EXALTATION_RULERS = {
    0: "SUN",
    1: "MOON",
    3: "JUPITER",
    5: "MERCURY",
    6: "SATURN",
    9: "MARS",
    11: "VENUS",
}

TRIPLICITY_RULERS = {
    "dorothean": {
        "fire": ("SUN", "JUPITER", "SATURN"),
        "earth": ("VENUS", "MOON", "MARS"),
        "air": ("SATURN", "MERCURY", "JUPITER"),
        "water": ("VENUS", "MARS", "MOON"),
    },
    "ptolemaic": {
        "fire": ("SUN", "JUPITER", "SATURN"),
        "earth": ("VENUS", "MOON", "MARS"),
        "air": ("SATURN", "MERCURY", "JUPITER"),
        "water": ("VENUS", "MARS", "MOON"),
    },
}

SIGN_ELEMENTS = [
    "fire",
    "earth",
    "air",
    "water",
    "fire",
    "earth",
    "air",
    "water",
    "fire",
    "earth",
    "air",
    "water",
]

EGYPTIAN_BOUNDS = {
    0: [("JUPITER", 6), ("VENUS", 14), ("MERCURY", 21), ("MARS", 26), ("SATURN", 30)],
    1: [("VENUS", 8), ("MERCURY", 14), ("JUPITER", 22), ("SATURN", 27), ("MARS", 30)],
    2: [("MERCURY", 6), ("JUPITER", 12), ("VENUS", 17), ("MARS", 24), ("SATURN", 30)],
    3: [("MARS", 7), ("VENUS", 13), ("MERCURY", 19), ("JUPITER", 26), ("SATURN", 30)],
    4: [("JUPITER", 6), ("VENUS", 11), ("SATURN", 18), ("MERCURY", 24), ("MARS", 30)],
    5: [("MERCURY", 7), ("VENUS", 13), ("JUPITER", 17), ("MARS", 21), ("SATURN", 30)],
    6: [("SATURN", 6), ("MERCURY", 14), ("JUPITER", 21), ("VENUS", 28), ("MARS", 30)],
    7: [("MARS", 7), ("VENUS", 11), ("MERCURY", 19), ("JUPITER", 24), ("SATURN", 30)],
    8: [("JUPITER", 12), ("VENUS", 17), ("MERCURY", 21), ("SATURN", 26), ("MARS", 30)],
    9: [("MERCURY", 7), ("JUPITER", 14), ("VENUS", 22), ("SATURN", 26), ("MARS", 30)],
    10: [("MERCURY", 7), ("VENUS", 13), ("JUPITER", 20), ("MARS", 25), ("SATURN", 30)],
    11: [("VENUS", 12), ("JUPITER", 16), ("MERCURY", 19), ("MARS", 28), ("SATURN", 30)],
}

PTOLEMAIC_BOUNDS = {
    0: [("JUPITER", 6), ("VENUS", 14), ("MERCURY", 21), ("MARS", 28), ("SATURN", 30)],
    1: [("VENUS", 8), ("MERCURY", 15), ("JUPITER", 22), ("SATURN", 27), ("MARS", 30)],
    2: [("MERCURY", 7), ("JUPITER", 14), ("VENUS", 21), ("MARS", 25), ("SATURN", 30)],
    3: [("MARS", 6), ("JUPITER", 13), ("MERCURY", 20), ("VENUS", 27), ("SATURN", 30)],
    4: [("JUPITER", 6), ("VENUS", 13), ("SATURN", 19), ("MERCURY", 25), ("MARS", 30)],
    5: [("MERCURY", 7), ("VENUS", 13), ("JUPITER", 18), ("SATURN", 24), ("MARS", 30)],
    6: [("SATURN", 6), ("VENUS", 11), ("JUPITER", 19), ("MERCURY", 24), ("MARS", 30)],
    7: [("MARS", 6), ("JUPITER", 14), ("VENUS", 21), ("MERCURY", 27), ("SATURN", 30)],
    8: [("JUPITER", 8), ("VENUS", 14), ("MERCURY", 19), ("SATURN", 25), ("MARS", 30)],
    9: [("VENUS", 6), ("MERCURY", 12), ("JUPITER", 19), ("MARS", 25), ("SATURN", 30)],
    10: [("SATURN", 6), ("MERCURY", 12), ("VENUS", 20), ("JUPITER", 25), ("MARS", 30)],
    11: [("VENUS", 8), ("JUPITER", 14), ("MERCURY", 20), ("MARS", 26), ("SATURN", 30)],
}

FACE_ORDER = ["MARS", "SUN", "VENUS", "MERCURY", "MOON", "SATURN", "JUPITER"]

JOY_HOUSE = {
    "SUN": 9, "MOON": 11, "MERCURY": 1, "VENUS": 5,
    "MARS": 6, "JUPITER": 11, "SATURN": 12,
}

SIGN_GENDER = ["masc", "fem", "masc", "fem", "masc", "fem", "masc", "fem", "masc", "fem", "masc", "fem"]


def house_strength(house: int) -> str:
    if house in {1, 4, 7, 10}:
        return "角宫"
    if house in {2, 5, 8, 11}:
        return "续宫"
    return "果宫"


def bounds_ruler(lon: float, bounds_system: str) -> str:
    table = PTOLEMAIC_BOUNDS if bounds_system == "ptolemaic" else EGYPTIAN_BOUNDS
    degree = sign_degree(lon)
    for ruler, upper in table[zodiac_sign_index(lon)]:
        if degree < upper or degree == upper:
            return ruler
    return table[zodiac_sign_index(lon)][-1][0]


def decan_ruler(lon: float) -> str:
    decan_index = zodiac_sign_index(lon) * 3 + int(sign_degree(lon) // 10)
    return FACE_ORDER[decan_index % len(FACE_ORDER)]


def triplicity_set(sign_idx: int, triplicity_system: str) -> tuple[str, str, str]:
    system = triplicity_system if triplicity_system in TRIPLICITY_RULERS else "dorothean"
    return TRIPLICITY_RULERS[system][SIGN_ELEMENTS[sign_idx]]


def dignity_rulers_for_lon(
    lon: float,
    is_day: bool,
    bounds_system: str,
    triplicity_system: str,
) -> dict[str, str]:
    sign_idx = zodiac_sign_index(lon)
    triplicity = triplicity_set(sign_idx, triplicity_system)
    return {
        "domicile": SIGN_RULERS[sign_idx],
        "exaltation": EXALTATION_RULERS.get(sign_idx, ""),
        "triplicity": triplicity[0] if is_day else triplicity[1],
        "bound": bounds_ruler(lon, bounds_system),
        "decan": decan_ruler(lon),
    }


def dignity_labels(
    body_id: str,
    lon: float,
    is_day: bool,
    bounds_system: str,
    triplicity_system: str,
) -> tuple[str, str, str, str, str, int, list[str], list[dict[str, Any]], str, str]:
    sign_idx = zodiac_sign_index(lon)
    rulers = dignity_rulers_for_lon(lon, is_day, bounds_system, triplicity_system)
    score = 0
    notes: list[str] = []
    breakdown: list[dict[str, Any]] = []

    domicile = "入庙" if rulers["domicile"] == body_id else ""
    if domicile:
        score += 5
        notes.append("入庙")
        breakdown.append({"label": "domicile", "score": 5, "value": "入庙"})

    detriment_label = ""
    is_detriment = SIGN_RULERS[(sign_idx + 6) % 12] == body_id
    if is_detriment:
        score -= 5
        notes.append("失势")
        detriment_label = "失势"
        breakdown.append({"label": "detriment", "score": -5, "value": "失势"})

    exaltation = "旺" if rulers["exaltation"] == body_id else ""
    if exaltation:
        score += 4
        notes.append("旺")
        breakdown.append({"label": "exaltation", "score": 4, "value": "旺"})

    fall_label = ""
    is_fall = EXALTATION_RULERS.get((sign_idx + 6) % 12) == body_id
    if is_fall:
        score -= 4
        notes.append("落陷")
        fall_label = "落陷"
        breakdown.append({"label": "fall", "score": -4, "value": "落陷"})

    triplicity = triplicity_set(sign_idx, triplicity_system)
    triplicity_label = ""
    if body_id in triplicity:
        role = ["昼主", "夜主", "参与"][triplicity.index(body_id)]
        triplicity_label = role
        delta = 3 if role != "参与" else 1
        score += delta
        notes.append(f"三分 {role}")
        breakdown.append({"label": "triplicity", "score": delta, "value": role})

    bound = planet_name(rulers["bound"])
    if rulers["bound"] == body_id:
        score += 2
        notes.append("界主")
        breakdown.append({"label": "bound", "score": 2, "value": "界主"})

    decan = planet_name(rulers["decan"])
    if rulers["decan"] == body_id:
        score += 1
        notes.append("面主")
        breakdown.append({"label": "decan", "score": 1, "value": "面主"})

    return domicile, exaltation, triplicity_label, bound, decan, score, notes, breakdown, detriment_label, fall_label


def triplicity_ruler_details(
    sign_idx: int,
    triplicity_system: str,
    all_planet_positions: dict[str, dict[str, Any]],
) -> list[dict[str, Any]]:
    element = SIGN_ELEMENTS[sign_idx]
    system = triplicity_system if triplicity_system in TRIPLICITY_RULERS else "dorothean"
    day_ruler, night_ruler, participating = TRIPLICITY_RULERS[system][element]
    roles = [
        ("day", "昼主", day_ruler),
        ("night", "夜主", night_ruler),
        ("part", "参与", participating),
    ]
    details: list[dict[str, Any]] = []
    for role_id, role_label, ruler_id in roles:
        ruler_data = all_planet_positions.get(ruler_id, {})
        ruler_house = ruler_data.get("house", 0)
        ruler_speed = ruler_data.get("speed", 0)
        ruler_notes: list[str] = []
        ruler_score = 0

        in_domicile = SIGN_RULERS[zodiac_sign_index(ruler_data.get("longitude", 0))] == ruler_id
        is_direct = ruler_speed >= 0
        is_angular = ruler_house in {1, 4, 7, 10}

        if in_domicile:
            ruler_score += 3
            ruler_notes.append("入庙")
        else:
            ruler_notes.append("未入庙")
        if is_direct:
            ruler_score += 2
            ruler_notes.append("顺行")
        else:
            ruler_notes.append("逆行")
        if is_angular:
            ruler_score += 2
            ruler_notes.append("角宫")
        elif ruler_house in {2, 5, 8, 11}:
            ruler_score += 1
            ruler_notes.append("续宫")
        else:
            ruler_notes.append("果宫")

        status = "强" if ruler_score >= 6 else "中" if ruler_score >= 4 else "弱"
        details.append({
            "role": role_id,
            "label": role_label,
            "ruler": planet_name(ruler_id),
            "ruler_id": ruler_id,
            "score": ruler_score,
            "status": status,
            "notes": ruler_notes,
        })
    return details


def solar_phase(body_id: str, lon: float, sun_lon: float, cazimi_orb: float = 17.0 / 60.0, combust_orb: float = 8.5, under_beams_orb: float = 15.0) -> tuple[str, int, list[str], dict[str, Any]]:
    if body_id == "SUN":
        return "-", 0, [], {
            "label": "solar_phase", "score": 0, "value": "-",
            "solar_condition": "-", "sun_distance_deg": 0,
            "threshold_profile": {"cazimi_arcmin": round(cazimi_orb * 60, 1), "combust_deg": combust_orb, "under_beams_deg": under_beams_orb},
        }

    separation = angular_separation(lon, sun_lon)
    threshold_profile = {"cazimi_arcmin": round(cazimi_orb * 60, 1), "combust_deg": combust_orb, "under_beams_deg": under_beams_orb}

    if separation <= cazimi_orb:
        return "日心合", 5, ["日心合"], {
            "label": "solar_phase", "score": 5, "value": "日心合",
            "solar_condition": "cazimi", "sun_distance_deg": round(separation, 4),
            "threshold_profile": threshold_profile,
        }
    if separation <= combust_orb:
        return "燃烧", -5, ["燃烧"], {
            "label": "solar_phase", "score": -5, "value": "燃烧",
            "solar_condition": "combust", "sun_distance_deg": round(separation, 4),
            "threshold_profile": threshold_profile,
        }
    if separation <= under_beams_orb:
        return "日光下", -3, ["日光下"], {
            "label": "solar_phase", "score": -3, "value": "日光下",
            "solar_condition": "under_beams", "sun_distance_deg": round(separation, 4),
            "threshold_profile": threshold_profile,
        }
    return "可见", 0, [], {
        "label": "solar_phase", "score": 0, "value": "可见",
        "solar_condition": "visible", "sun_distance_deg": round(separation, 4),
        "threshold_profile": threshold_profile,
    }


def motion_label(body_id: str, speed: float) -> tuple[str, int, list[str], dict[str, Any]]:
    if body_id in {"SUN", "MOON"}:
        return "顺行", 0, [], {"label": "motion", "score": 0, "value": "顺行"}
    if abs(speed) < 0.05:
        return "停滞", -2, ["停滞"], {"label": "motion", "score": -2, "value": "停滞"}
    if speed < 0:
        return "逆行", -3, ["逆行"], {"label": "motion", "score": -3, "value": "逆行"}
    return "顺行", 0, [], {"label": "motion", "score": 0, "value": "顺行"}


def sect_status(body_id: str, is_day: bool, lon: float, sun_lon: float, house: int = 0) -> tuple[str, int, list[str], dict[str, Any]]:
    if body_id == "MERCURY":
        oriental = norm360(sun_lon - lon) < 180.0
        status = "随昼" if oriental else "随夜"
        in_sect = (is_day and oriental) or ((not is_day) and not oriental)
        mercury_condition = "oriental" if oriental else "occidental"
        return status, 2 if in_sect else -1, [status], {
            "label": "sect", "score": 2 if in_sect else -1, "value": status,
            "mercury_condition": mercury_condition,
            "chart_sect": "day" if is_day else "night",
            "planet_sect": "day" if in_sect else "night",
            "sect_agreement": in_sect,
        }
    if is_day:
        in_sect = body_id in {"SUN", "JUPITER", "SATURN"}
        status = "合昼派" if in_sect else "违昼派"
    else:
        in_sect = body_id in {"MOON", "VENUS", "MARS"}
        status = "合夜派" if in_sect else "违夜派"

    score = 2 if in_sect else -1
    return status, score, [status], {
        "label": "sect", "score": score, "value": status,
        "chart_sect": "day" if is_day else "night",
        "planet_sect": "day" if in_sect else "night",
        "sect_agreement": in_sect,
    }


def hayz_status(body_id: str, is_day: bool, lon: float, house: int, sun_lon: float) -> tuple[str, int, list[str], dict[str, Any]]:
    sign_idx = zodiac_sign_index(lon)
    gender = SIGN_GENDER[sign_idx]
    above_horizon = house >= 7

    if body_id == "SUN":
        if not is_day:
            return "", 0, [], {"label": "hayz", "score": 0, "value": "", "trace": {"sign_gender": gender, "above_horizon": above_horizon, "sect_agreement": True, "chart_sect": "day" if is_day else "night", "is_day_chart": is_day, "note": "Sun is only hayz in a day chart"}}
        hayz = above_horizon and gender == "masc"
        if hayz:
            return "Hayz", 3, ["Hayz"], {"label": "hayz", "score": 3, "value": "Hayz", "trace": {"sign_gender": gender, "above_horizon": above_horizon, "sect_agreement": True, "is_hayz": True}}
        return "", 0, [], {"label": "hayz", "score": 0, "value": "", "trace": {"sign_gender": gender, "above_horizon": above_horizon, "sect_agreement": True, "is_hayz": False, "note": "Sun not hayz: above_horizon and masculine sign both required"}}

    sect, _, _, _ = sect_status(body_id, is_day, lon, sun_lon)
    in_sect = sect.startswith("合")

    hayz = False
    if is_day and above_horizon and in_sect and gender == "masc":
        hayz = True
    elif is_day and not above_horizon and not in_sect and gender == "fem":
        hayz = True
    elif not is_day and not above_horizon and in_sect and gender == "fem":
        hayz = True
    elif not is_day and above_horizon and not in_sect and gender == "masc":
        hayz = True

    trace = {"sign_gender": gender, "above_horizon": above_horizon, "sect_agreement": in_sect, "is_hayz": hayz}

    if hayz:
        return "Hayz", 3, ["Hayz"], {"label": "hayz", "score": 3, "value": "Hayz", "trace": trace}
    return "", 0, [], {"label": "hayz", "score": 0, "value": "", "trace": trace}


def joy_status(body_id: str, house: int) -> tuple[str, int, list[str], dict[str, Any]]:
    expected = JOY_HOUSE.get(body_id, 0)
    if expected > 0 and house == expected:
        return "喜乐", 1, ["喜乐"], {"label": "joy", "score": 1, "value": "喜乐"}
    return "", 0, [], {"label": "joy", "score": 0, "value": ""}


def calc_dodekatemorion(lon: float) -> tuple[float, int, str]:
    sign_start = (int(lon // 30)) * 30.0
    degree_in_sign = lon % 30.0
    dodek_lon = norm360(sign_start + degree_in_sign * 12)
    dodek_sign_idx = zodiac_sign_index(dodek_lon)
    return round(dodek_lon, 4), dodek_sign_idx, planet_name(SIGN_RULERS[dodek_sign_idx])
