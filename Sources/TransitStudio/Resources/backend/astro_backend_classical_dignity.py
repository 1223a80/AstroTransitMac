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
        "fire": ("SUN", "JUPITER", ""),
        "earth": ("VENUS", "MOON", ""),
        "air": ("SATURN", "MERCURY", ""),
        "water": ("MARS", "MARS", ""),
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

# Egyptian terms (Ptolemy, Tetrabiblos I.20, Egyptian table). Each tuple is (ruler, exclusive_upper_degree).
# Degree D in sign is in the first bound with D < upper (last bound absorbs D==30).
EGYPTIAN_BOUNDS = {
    0: [("JUPITER", 6), ("VENUS", 12), ("MERCURY", 20), ("MARS", 25), ("SATURN", 30)],
    1: [("VENUS", 8), ("MERCURY", 14), ("JUPITER", 22), ("SATURN", 27), ("MARS", 30)],
    2: [("MERCURY", 6), ("JUPITER", 12), ("VENUS", 17), ("MARS", 24), ("SATURN", 30)],
    3: [("MARS", 7), ("VENUS", 13), ("MERCURY", 19), ("JUPITER", 26), ("SATURN", 30)],
    4: [("JUPITER", 6), ("VENUS", 11), ("SATURN", 18), ("MERCURY", 24), ("MARS", 30)],
    # Virgo: Mer 0–7, Ven 7–17, Jup 17–21, Mar 21–28, Sat 28–30 (was wrongly Ven13/Jup17/Mar21/Sat30)
    5: [("MERCURY", 7), ("VENUS", 17), ("JUPITER", 21), ("MARS", 28), ("SATURN", 30)],
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
    "SUN": 9, "MOON": 3, "MERCURY": 1, "VENUS": 5,
    "MARS": 6, "JUPITER": 11, "SATURN": 12,
}

SIGN_GENDER = ["masc", "fem", "masc", "fem", "masc", "fem", "masc", "fem", "masc", "fem", "masc", "fem"]


def house_strength(house: int) -> str:
    if house in {1, 4, 7, 10}:
        return "角宫"
    if house in {2, 5, 8, 11}:
        return "续宫"
    return "果宫"


# Traditional place quality (good/bad) is independent of angularity class.
GOOD_PLACES = {1, 4, 5, 7, 9, 10, 11}
DIFFICULT_PLACES = {6, 8, 12}
TRADITIONAL_PLACE_NAMES = {
    1: "Hour-marker / Ascendant",
    2: "Gate of Hades",
    3: "Goddess",
    4: "Subterraneous / IC",
    5: "Good Fortune",
    6: "Bad Fortune",
    7: "Setting",
    8: "Idle",
    9: "God",
    10: "Midheaven",
    11: "Good Spirit",
    12: "Bad Spirit",
}


def place_quality_fields(house: int) -> dict[str, Any]:
    """Angularity class vs place quality vs ASC aspect (whole-sign beholding)."""
    if house in {1, 4, 7, 10}:
        angularity = "angular"
    elif house in {2, 5, 8, 11}:
        angularity = "succeedent"
    else:
        angularity = "cadent"
    # Whole-sign aspects to ASC: houses that aspect 1 by major aspect.
    # 1 conj, 3 sextile, 4 square, 5 trine, 7 opp, 9 trine, 10 square, 11 sextile.
    beholds = house in {1, 3, 4, 5, 7, 9, 10, 11}
    if house in GOOD_PLACES:
        quality = "good"
    elif house in DIFFICULT_PLACES:
        quality = "difficult"
    else:
        quality = "neutral"
    return {
        "angularity_class": angularity,
        "place_quality": quality,
        "beholds_ascendant": beholds,
        "aversion_to_ascendant": not beholds,
        "traditional_place_name": TRADITIONAL_PLACE_NAMES.get(house, ""),
        "house_strength_label": house_strength(house),
    }


def bounds_ruler(lon: float, bounds_system: str) -> str:
    """Return bound lord for longitude. Upper degree is exclusive except the final 30° bound."""
    table = PTOLEMAIC_BOUNDS if bounds_system == "ptolemaic" else EGYPTIAN_BOUNDS
    degree = sign_degree(lon)
    bounds = table[zodiac_sign_index(lon)]
    for ruler, upper in bounds:
        # Exclusive upper edge so e.g. Virgo 17°00' belongs to Jupiter, not Venus.
        if degree < upper:
            return ruler
    return bounds[-1][0]


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
    """Rulers of the *position* (not whether the subject planet owns them)."""
    sign_idx = zodiac_sign_index(lon)
    triplicity = triplicity_set(sign_idx, triplicity_system)
    return {
        "domicile": SIGN_RULERS[sign_idx],
        "exaltation": EXALTATION_RULERS.get(sign_idx, ""),
        "triplicity": triplicity[0] if is_day else triplicity[1],
        "bound": bounds_ruler(lon, bounds_system),
        "decan": decan_ruler(lon),
    }


def dignity_ownership(body_id: str, rulers: dict[str, str], triplicity: tuple[str, str, str]) -> dict[str, Any]:
    """Separate position rulers from subject ownership of those dignities."""
    trip_ids = [r for r in triplicity if r]
    return {
        "domicile_ruler": rulers.get("domicile") or "",
        "exaltation_ruler": rulers.get("exaltation") or "",
        "triplicity_rulers": list(trip_ids),
        "bound_ruler": rulers.get("bound") or "",
        "decan_ruler": rulers.get("decan") or "",
        "subject_owns_domicile": rulers.get("domicile") == body_id,
        "subject_owns_exaltation": bool(rulers.get("exaltation")) and rulers.get("exaltation") == body_id,
        "subject_owns_triplicity": body_id in trip_ids,
        "subject_owns_bound": rulers.get("bound") == body_id,
        "subject_owns_decan": rulers.get("decan") == body_id,
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
        breakdown.append({"label": "domicile", "score": 5, "value": "入庙", "owned": True})

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
        breakdown.append({"label": "exaltation", "score": 4, "value": "旺", "owned": True})

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
        breakdown.append({"label": "triplicity", "score": delta, "value": role, "owned": True})

    # Always report the position's bound/decan ruler names; score only if subject owns them.
    bound = planet_name(rulers["bound"])
    if rulers["bound"] == body_id:
        score += 2
        notes.append("界主")
        breakdown.append({"label": "bound", "score": 2, "value": "界主", "owned": True, "bound_ruler": rulers["bound"]})
    else:
        breakdown.append({
            "label": "bound_ruler",
            "score": 0,
            "value": bound,
            "owned": False,
            "bound_ruler": rulers["bound"],
        })

    decan = planet_name(rulers["decan"])
    if rulers["decan"] == body_id:
        score += 1
        notes.append("面主")
        breakdown.append({"label": "decan", "score": 1, "value": "面主", "owned": True, "decan_ruler": rulers["decan"]})
    else:
        breakdown.append({
            "label": "decan_ruler",
            "score": 0,
            "value": decan,
            "owned": False,
            "decan_ruler": rulers["decan"],
        })

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
        if not ruler_id:
            continue
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

    def _phase_payload(label: str, score: int, condition: str) -> dict[str, Any]:
        return {
            "label": "solar_phase",
            "score": score,
            "value": label,
            "solar_condition": condition,
            "solar_elongation_condition": condition,
            "combust": condition == "combust",
            "under_beams": condition in {"under_beams", "combust", "cazimi"},
            "cazimi": condition == "cazimi",
            "heliacally_visible": False if condition in {"combust", "under_beams", "cazimi"} else None,
            "visibility_method": "solar_elongation_thresholds_only",
            "sun_distance_deg": round(separation, 4),
            "threshold_profile": threshold_profile,
            "note": "solar elongation condition only; not naked-eye heliacal visibility",
        }

    if separation <= cazimi_orb:
        return "日心合", 5, ["日心合"], _phase_payload("日心合", 5, "cazimi")
    if separation <= combust_orb:
        return "燃烧", -5, ["燃烧"], _phase_payload("燃烧", -5, "combust")
    if separation <= under_beams_orb:
        return "日光下", -3, ["日光下"], _phase_payload("日光下", -3, "under_beams")
    # Free of solar elongation hazards — not the same as heliacal naked-eye visibility.
    return "脱离日光", 0, [], {
        "label": "solar_phase", "score": 0, "value": "脱离日光",
        "solar_condition": "free_of_beams",
        "solar_elongation_condition": "free_of_beams",
        "combust": False,
        "under_beams": False,
        "cazimi": False,
        "heliacally_visible": None,
        "visibility_method": "solar_elongation_thresholds_only",
        "sun_distance_deg": round(separation, 4),
        "threshold_profile": threshold_profile,
        "note": "solar elongation condition only; heliacal visibility requires the visibility module",
    }


def motion_label(body_id: str, speed: float) -> tuple[str, int, list[str], dict[str, Any]]:
    if body_id in {"SUN", "MOON"}:
        return "顺行", 0, [], {"label": "motion", "score": 0, "value": "顺行"}
    mean_speed = {
        "MERCURY": 1.383,
        "VENUS": 1.2,
        "MARS": 0.524,
        "JUPITER": 0.083,
        "SATURN": 0.033,
    }.get(body_id, 1.0)
    station_threshold = max(mean_speed * 0.03, 0.001)
    if abs(speed) < station_threshold:
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
