"""Horary V3.0.1 - Standalone Traditional Horary Astrology Engine & Worksheet Generator.

Schema ID: horary-data-packet/3.0.1
Engine Version: 3.0.1

This is an independent, self-contained Python backend for classical horary calculation.
It does not depend on existing app pipelines or legacy v2/v3 route modules.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import math
import os
import sys
from dataclasses import dataclass, field
from typing import Any, Callable
from zoneinfo import ZoneInfo

try:
    import swisseph as swe
except ImportError as exc:
    sys.stderr.write("Missing pyswisseph. Install via: pip install pyswisseph\n")
    raise SystemExit(2) from exc

# ---------------------------------------------------------------------------
# Constants & Traditional Astrological Tables
# ---------------------------------------------------------------------------

SCHEMA_VERSION = "3.0.1"
SCHEMA_ID = "horary-data-packet/3.0.1"
ENGINE_NAME = "TransitStudio.horary_v3_0_1_standalone"
ENGINE_VERSION = "3.0.1"
ALGORITHM_VERSION = "horary-v3.0.1-2026-10"

SIGNS_ZH = [
    "白羊", "金牛", "双子", "巨蟹", "狮子", "处女",
    "天秤", "天蝎", "射手", "摩羯", "水瓶", "双鱼",
]
SIGNS_EN = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
]
SIGN_ELEMENTS = [
    "fire", "earth", "air", "water", "fire", "earth",
    "air", "water", "fire", "earth", "air", "water",
]
SIGN_QUALITIES = [
    "cardinal", "fixed", "mutable", "cardinal", "fixed", "mutable",
    "cardinal", "fixed", "mutable", "cardinal", "fixed", "mutable",
]

# Domicile rulers for signs 0..11
SIGN_DOMICILE_RULERS = [
    "MARS", "VENUS", "MERCURY", "MOON", "SUN", "MERCURY",
    "VENUS", "MARS", "JUPITER", "SATURN", "SATURN", "JUPITER",
]

# Exaltation rulers and exact degrees
EXALTATION_INFO: dict[int, tuple[str, float]] = {
    0: ("SUN", 19.0),
    1: ("MOON", 3.0),
    3: ("JUPITER", 15.0),
    5: ("MERCURY", 15.0),
    6: ("SATURN", 21.0),
    9: ("MARS", 28.0),
    11: ("VENUS", 27.0),
}

# Dorothean Triplicity rulers (Day, Night, Participating)
TRIPLICITY_DOROTHEAN: dict[str, tuple[str, str, str]] = {
    "fire": ("SUN", "JUPITER", "SATURN"),
    "earth": ("VENUS", "MOON", "MARS"),
    "air": ("SATURN", "MERCURY", "JUPITER"),
    "water": ("VENUS", "MARS", "MOON"),
}

# Egyptian Bounds (Terms) - With corrected Aries boundaries (LacusCurtius Loeb/Robbins 1940)
# (ruler, exclusive upper degree in sign)
EGYPTIAN_BOUNDS: dict[int, list[tuple[str, float]]] = {
    0: [("JUPITER", 6.0), ("VENUS", 12.0), ("MERCURY", 20.0), ("MARS", 25.0), ("SATURN", 30.0)],
    1: [("VENUS", 8.0), ("MERCURY", 14.0), ("JUPITER", 22.0), ("SATURN", 27.0), ("MARS", 30.0)],
    2: [("MERCURY", 6.0), ("JUPITER", 12.0), ("VENUS", 17.0), ("MARS", 24.0), ("SATURN", 30.0)],
    3: [("MARS", 7.0), ("VENUS", 13.0), ("MERCURY", 19.0), ("JUPITER", 26.0), ("SATURN", 30.0)],
    4: [("JUPITER", 6.0), ("VENUS", 11.0), ("SATURN", 18.0), ("MERCURY", 24.0), ("MARS", 30.0)],
    5: [("MERCURY", 7.0), ("VENUS", 17.0), ("JUPITER", 21.0), ("MARS", 28.0), ("SATURN", 30.0)],
    6: [("SATURN", 6.0), ("MERCURY", 14.0), ("JUPITER", 21.0), ("VENUS", 28.0), ("MARS", 30.0)],
    7: [("MARS", 7.0), ("VENUS", 11.0), ("MERCURY", 19.0), ("JUPITER", 24.0), ("SATURN", 30.0)],
    8: [("JUPITER", 12.0), ("VENUS", 17.0), ("MERCURY", 21.0), ("SATURN", 26.0), ("MARS", 30.0)],
    9: [("MERCURY", 7.0), ("JUPITER", 14.0), ("VENUS", 22.0), ("SATURN", 26.0), ("MARS", 30.0)],
    10: [("MERCURY", 7.0), ("VENUS", 13.0), ("JUPITER", 20.0), ("MARS", 25.0), ("SATURN", 30.0)],
    11: [("VENUS", 12.0), ("JUPITER", 16.0), ("MERCURY", 19.0), ("MARS", 28.0), ("SATURN", 30.0)],
}

# Chaldaean Decans (Faces)
CHALDAEAN_DECANS: list[str] = [
    # Aries
    "MARS", "SUN", "VENUS",
    # Taurus
    "MERCURY", "MOON", "SATURN",
    # Gemini
    "JUPITER", "MARS", "SUN",
    # Cancer
    "VENUS", "MERCURY", "MOON",
    # Leo
    "SATURN", "JUPITER", "MARS",
    # Virgo
    "SUN", "VENUS", "MERCURY",
    # Libra
    "MOON", "SATURN", "JUPITER",
    # Scorpio
    "MARS", "SUN", "VENUS",
    # Sagittarius
    "MERCURY", "MOON", "SATURN",
    # Capricorn
    "JUPITER", "MARS", "SUN",
    # Aquarius
    "VENUS", "MERCURY", "MOON",
    # Pisces
    "SATURN", "JUPITER", "MARS",
]

CLASSICAL_BODIES = ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]

SWE_BODY_MAP: dict[str, int] = {
    "SUN": swe.SUN,
    "MOON": swe.MOON,
    "MERCURY": swe.MERCURY,
    "VENUS": swe.VENUS,
    "MARS": swe.MARS,
    "JUPITER": swe.JUPITER,
    "SATURN": swe.SATURN,
    "TRUE_NODE": swe.TRUE_NODE,
    "MEAN_NODE": swe.MEAN_NODE,
    "URANUS": swe.URANUS,
    "NEPTUNE": swe.NEPTUNE,
    "PLUTO": swe.PLUTO,
}

BODY_NAMES_ZH: dict[str, str] = {
    "SUN": "太阳", "MOON": "月亮", "MERCURY": "水星", "VENUS": "金星",
    "MARS": "火星", "JUPITER": "木星", "SATURN": "土星",
    "TRUE_NODE": "北交点(真)", "SOUTH_TRUE_NODE": "南交点(真)",
    "MEAN_NODE": "北交点(平)", "SOUTH_MEAN_NODE": "南交点(平)",
    "URANUS": "天王星", "NEPTUNE": "海王星", "PLUTO": "冥王星",
}

BODY_NAMES_EN: dict[str, str] = {
    "SUN": "Sun", "MOON": "Moon", "MERCURY": "Mercury", "VENUS": "Venus",
    "MARS": "Mars", "JUPITER": "Jupiter", "SATURN": "Saturn",
    "TRUE_NODE": "North Node", "SOUTH_TRUE_NODE": "South Node",
    "MEAN_NODE": "Mean Node", "SOUTH_MEAN_NODE": "Mean South Node",
    "URANUS": "Uranus", "NEPTUNE": "Neptune", "PLUTO": "Pluto",
}

PLANET_MEAN_SPEED: dict[str, float] = {
    "SUN": 0.9856,
    "MOON": 13.1764,
    "MERCURY": 1.2000,
    "VENUS": 1.2000,
    "MARS": 0.5240,
    "JUPITER": 0.0831,
    "SATURN": 0.0335,
}

PTOLEMAIC_ASPECTS: dict[str, dict[str, Any]] = {
    "conjunction": {"angle": 0.0, "name_zh": "合相", "name_en": "Conjunction"},
    "sextile": {"angle": 60.0, "name_zh": "六合", "name_en": "Sextile"},
    "square": {"angle": 90.0, "name_zh": "刑相", "name_en": "Square"},
    "trine": {"angle": 120.0, "name_zh": "拱相", "name_en": "Trine"},
    "opposition": {"angle": 180.0, "name_zh": "冲相", "name_en": "Opposition"},
}

PLANETARY_MOIETY_ORBS: dict[str, float] = {
    "SUN": 15.0 / 2.0,       # 7.5°
    "MOON": 12.0 / 2.0,      # 6.0°
    "MERCURY": 7.0 / 2.0,    # 3.5°
    "VENUS": 7.0 / 2.0,      # 3.5°
    "MARS": 8.0 / 2.0,       # 4.0°
    "JUPITER": 9.0 / 2.0,    # 4.5°
    "SATURN": 9.0 / 2.0,     # 4.5°
}

FIXED_STARS_HORARY: list[dict[str, Any]] = [
    {"id": "algol", "name_zh": "大陵五 (Algol)", "name_en": "Algol", "lon": 56.1667, "nature": "凶星 (Caput Algol, 极凶, 斩首/灾厄)"},
    {"id": "alcyone", "name_zh": "昂宿六 (Alcyone)", "name_en": "Alcyone", "lon": 60.0000, "nature": "凶 (Pleiades, 盲目/哭泣/灾祸)"},
    {"id": "aldebaran", "name_zh": "毕宿五 (Aldebaran)", "name_en": "Aldebaran", "lon": 69.7833, "nature": "大吉 (王者之星, 荣誉/勇气)"},
    {"id": "sirius", "name_zh": "天狼星 (Sirius)", "name_en": "Sirius", "lon": 104.0833, "nature": "吉星 (荣誉/富贵)"},
    {"id": "regulus", "name_zh": "轩辕十四 (Regulus)", "name_en": "Regulus", "lon": 150.0000, "nature": "大吉 (王者之星, 巨大成功/暴跌风险)"},
    {"id": "spica", "name_zh": "角宿一 (Spica)", "name_en": "Spica", "lon": 204.0000, "nature": "大吉 (第一吉星, 庇护/避凶)"},
    {"id": "arcturus", "name_zh": "大角星 (Arcturus)", "name_en": "Arcturus", "lon": 204.4000, "nature": "吉星 (财富/旅行)"},
    {"id": "antares", "name_zh": "心宿二 (Antares)", "name_en": "Antares", "lon": 249.9333, "nature": "凶星 (王者之星, 争斗/鲁莽/毁灭)"},
    {"id": "vega", "name_zh": "织女一 (Vega)", "name_en": "Vega", "lon": 285.4833, "nature": "吉星 (才艺/显达)"},
    {"id": "fomalhaut", "name_zh": "北落师门 (Fomalhaut)", "name_en": "Fomalhaut", "lon": 334.0333, "nature": "吉星 (王者之星, 崇高精神/名誉)"},
    {"id": "scheat", "name_zh": "室宿二 (Scheat)", "name_en": "Scheat", "lon": 359.5333, "nature": "大凶 (水厄/牢狱/绝望)"},
]

CHALDAEAN_WEEKDAY_RULERS = [
    "MOON",    # Monday
    "MARS",    # Tuesday
    "MERCURY", # Wednesday
    "JUPITER", # Thursday
    "VENUS",   # Friday
    "SATURN",  # Saturday
    "SUN",     # Sunday
]

CHALDAEAN_PLANETARY_HOURS_ORDER = [
    "SATURN", "JUPITER", "MARS", "SUN", "VENUS", "MERCURY", "MOON",
]

# ---------------------------------------------------------------------------
# Utility Math & Formatting Functions
# ---------------------------------------------------------------------------

def norm360(deg: float) -> float:
    return deg % 360.0

def angular_distance(lon1: float, lon2: float) -> float:
    diff = abs(norm360(lon1) - norm360(lon2))
    return 360.0 - diff if diff > 180.0 else diff

def signed_diff(target: float, source: float) -> float:
    d = (target - source) % 360.0
    return d - 360.0 if d > 180.0 else d

def split_dms(deg: float) -> tuple[int, int, float]:
    d = int(deg)
    rem = (deg - d) * 60.0
    m = int(rem)
    s = (rem - m) * 60.0
    if s >= 59.9999:
        s = 0.0
        m += 1
        if m >= 60:
            m = 0
            d += 1
    return d, m, s

def format_dms(deg_in_sign: float, sign_zh: str | None = None) -> str:
    d, m, s = split_dms(deg_in_sign)
    prefix = f"{sign_zh} " if sign_zh else ""
    return f"{prefix}{d:02d}°{m:02d}'{int(round(s)):02d}\""

def sign_info(longitude: float) -> dict[str, Any]:
    lon = norm360(longitude)
    sign_idx = int(lon // 30)
    deg_in_sign = lon % 30.0
    d, m, s = split_dms(deg_in_sign)
    return {
        "sign_index": sign_idx,
        "sign_zh": SIGNS_ZH[sign_idx],
        "sign_en": SIGNS_EN[sign_idx],
        "element": SIGN_ELEMENTS[sign_idx],
        "quality": SIGN_QUALITIES[sign_idx],
        "degree_in_sign": round(deg_in_sign, 6),
        "dms": {"degrees": d, "minutes": m, "seconds": round(s, 2)},
        "formatted_zh": f"{SIGNS_ZH[sign_idx]} {d:02d}°{m:02d}'{int(round(s)):02d}\"",
        "formatted_en": f"{d:02d}°{m:02d}'{int(round(s)):02d}\" {SIGNS_EN[sign_idx]}",
    }

def ensure_ephemeris_path(custom_path: str | None = None) -> None:
    if custom_path and os.path.isdir(custom_path):
        swe.set_ephe_path(custom_path)
        return
    current_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(current_dir, "..", "ephemeris"),
        os.path.join(current_dir, "ephemeris"),
        os.path.expanduser("~/Documents/Codex/AstroTransitMac/Sources/TransitStudio/Resources/ephemeris"),
        "/usr/local/share/swisseph",
        "/usr/share/swisseph",
    ]
    for c in candidates:
        norm = os.path.abspath(c)
        if os.path.isdir(norm):
            swe.set_ephe_path(norm)
            return

# ---------------------------------------------------------------------------
# Core Astrological Calculations
# ---------------------------------------------------------------------------

@dataclass
class HoraryChartData:
    utc_datetime: datetime.datetime
    local_datetime: datetime.datetime
    timezone_name: str
    latitude: float
    longitude: float
    altitude_m: float
    house_system: str
    jd_ut: float
    delta_t: float
    is_day: bool
    angles: dict[str, float]
    cusps: list[float]
    bodies: dict[str, dict[str, Any]]
    dignities: dict[str, dict[str, Any]]
    aspects: list[dict[str, Any]]
    receptions: list[dict[str, Any]]
    moon_story: dict[str, Any]
    lots: dict[str, Any]
    considerations: list[dict[str, Any]]
    antiscia: list[dict[str, Any]]
    fixed_stars: list[dict[str, Any]]
    planetary_day_hour: dict[str, Any]
    question_text: str = ""
    place_name: str = ""

def calc_body_coordinates(jd_ut: float, body_id: str) -> dict[str, Any]:
    swe_code = SWE_BODY_MAP[body_id]
    flags = swe.FLG_SWIEPH | swe.FLG_SPEED
    ecl_res, _ = swe.calc_ut(jd_ut, swe_code, flags)
    lon, lat, dist, lon_speed = ecl_res[0], ecl_res[1], ecl_res[2], ecl_res[3]

    # Equatorial coordinates (RA, Dec)
    eq_flags = swe.FLG_SWIEPH | swe.FLG_EQUATORIAL
    eq_res, _ = swe.calc_ut(jd_ut, swe_code, eq_flags)
    ra, dec = eq_res[0], eq_res[1]

    s_info = sign_info(lon)
    motion = "retrograde" if lon_speed < -1e-5 else ("stationary" if abs(lon_speed) <= 1e-4 else "direct")

    return {
        "body_id": body_id,
        "name_zh": BODY_NAMES_ZH.get(body_id, body_id),
        "name_en": BODY_NAMES_EN.get(body_id, body_id),
        "longitude": norm360(lon),
        "latitude": lat,
        "distance": dist,
        "speed_lon": lon_speed,
        "ra": ra,
        "declination": dec,
        "sign": s_info,
        "motion": motion,
    }

def house_for_longitude(lon: float, cusps: list[float]) -> int:
    norm_lon = norm360(lon)
    for i in range(12):
        c_curr = cusps[i]
        c_next = cusps[(i + 1) % 12]
        span = (c_next - c_curr) % 360.0
        if span == 0:
            span = 360.0
        if (norm_lon - c_curr) % 360.0 < span:
            return i + 1
    return 1

def calc_essential_dignities(body_id: str, lon: float, is_day: bool) -> dict[str, Any]:
    norm_l = norm360(lon)
    sign_idx = int(norm_l // 30)
    deg_in_sign = norm_l % 30.0

    domicile = SIGN_DOMICILE_RULERS[sign_idx]
    detriment = SIGN_DOMICILE_RULERS[(sign_idx + 6) % 12]

    exalt_info = EXALTATION_INFO.get(sign_idx)
    exaltation = exalt_info[0] if exalt_info else None
    fall_info = EXALTATION_INFO.get((sign_idx + 6) % 12)
    fall = fall_info[0] if fall_info else None

    # Triplicity
    elem = SIGN_ELEMENTS[sign_idx]
    day_t, night_t, part_t = TRIPLICITY_DOROTHEAN[elem]
    active_triplicity = day_t if is_day else night_t

    # Egyptian Bounds
    bounds_list = EGYPTIAN_BOUNDS[sign_idx]
    bound_ruler = bounds_list[-1][0]
    bound_range = (0.0, 30.0)
    prev_deg = 0.0
    for r, up in bounds_list:
        if deg_in_sign < up:
            bound_ruler = r
            bound_range = (prev_deg, up)
            break
        prev_deg = up

    # Chaldaean Decan / Face
    decan_idx = sign_idx * 3 + int(deg_in_sign // 10)
    decan_ruler = CHALDAEAN_DECANS[decan_idx % len(CHALDAEAN_DECANS)]

    # Scoring (Lilly)
    score = 0
    dignity_types: list[str] = []
    if body_id == domicile:
        score += 5
        dignity_types.append("domicile")
    if body_id == exaltation:
        score += 4
        dignity_types.append("exaltation")
    if body_id in (day_t, night_t, part_t):
        score += 3
        dignity_types.append("triplicity")
    if body_id == bound_ruler:
        score += 2
        dignity_types.append("bound")
    if body_id == decan_ruler:
        score += 1
        dignity_types.append("decan")
    if body_id == detriment:
        score -= 5
        dignity_types.append("detriment")
    if body_id == fall:
        score -= 4
        dignity_types.append("fall")

    is_peregrine = len([d for d in dignity_types if d in {"domicile", "exaltation", "triplicity", "bound", "decan"}]) == 0
    if is_peregrine:
        score -= 5

    return {
        "body_id": body_id,
        "domicile_ruler": domicile,
        "exaltation_ruler": exaltation,
        "detriment_ruler": detriment,
        "fall_ruler": fall,
        "triplicity_active": active_triplicity,
        "triplicity_rulers": {"day": day_t, "night": night_t, "participating": part_t},
        "bound_ruler": bound_ruler,
        "bound_range": bound_range,
        "decan_ruler": decan_ruler,
        "dignity_types": dignity_types,
        "score": score,
        "is_peregrine": is_peregrine,
    }

def calc_solar_condition(planet_lon: float, sun_lon: float, planet_speed: float, sun_speed: float) -> dict[str, Any]:
    dist = angular_distance(planet_lon, sun_lon)
    # Applying or separating from Sun
    # Step forward 0.01 days
    dt = 0.01
    future_p = norm360(planet_lon + planet_speed * dt)
    future_s = norm360(sun_lon + sun_speed * dt)
    future_dist = angular_distance(future_p, future_s)
    is_applying = future_dist < dist

    cazimi = dist <= (17.0 / 60.0) # 0.2833°
    combust = dist <= 8.5 and not cazimi
    under_beams = dist <= 17.0 and not (cazimi or combust)

    status_zh = "日心 (Cazimi)" if cazimi else ("燃烧 (Combust)" if combust else ("日光下 (Under Beams)" if under_beams else "均否"))
    return {
        "distance_from_sun_deg": round(dist, 4),
        "is_cazimi": cazimi,
        "is_combust": combust,
        "is_under_beams": under_beams,
        "is_applying_to_sun": is_applying,
        "status_zh": status_zh,
    }

def find_next_exact_aspect(
    body1_id: str,
    body2_id: str,
    aspect_angle: float,
    jd_start: float,
    max_days: float = 30.0,
    tolerance_seconds: float = 0.5,
) -> dict[str, Any] | None:
    code1 = SWE_BODY_MAP[body1_id]
    code2 = SWE_BODY_MAP[body2_id]
    flags = swe.FLG_SWIEPH | swe.FLG_SPEED

    # Starting sign
    pos1_0, _ = swe.calc_ut(jd_start, code1, flags)
    pos2_0, _ = swe.calc_ut(jd_start, code2, flags)
    sign1_0 = int(norm360(pos1_0[0]) // 30)
    sign2_0 = int(norm360(pos2_0[0]) // 30)

    # Function evaluating angular distance error
    def diff_at(jd: float) -> float:
        p1, _ = swe.calc_ut(jd, code1, flags)
        p2, _ = swe.calc_ut(jd, code2, flags)
        dist = angular_distance(p1[0], p2[0])
        return dist - aspect_angle

    # Scan brackets with step of 0.05 days (~1.2 hours)
    step = 0.05
    t_curr = jd_start
    t_limit = jd_start + max_days
    tol_days = tolerance_seconds / 86400.0

    val_curr = diff_at(t_curr)
    found_root: float | None = None

    while t_curr < t_limit:
        t_next = min(t_curr + step, t_limit)
        val_next = diff_at(t_next)

        # Look for sign flip or local extremum touching 0
        if val_curr * val_next <= 0:
            # Bisection
            lo, hi = t_curr, t_next
            flo, fhi = val_curr, val_next
            for _ in range(35):
                mid = (lo + hi) / 2.0
                fmid = diff_at(mid)
                if abs(fmid) < 1e-7 or (hi - lo) < tol_days:
                    found_root = mid
                    break
                if flo * fmid <= 0:
                    hi, fhi = mid, fmid
                else:
                    lo, flo = mid, fmid
            if found_root is not None:
                break
        t_curr, val_curr = t_next, val_next

    if found_root is None or found_root <= jd_start:
        return None

    # Check whether planets changed signs or stationed before exact moment
    pos1_exact, _ = swe.calc_ut(found_root, code1, flags)
    pos2_exact, _ = swe.calc_ut(found_root, code2, flags)
    sign1_exact = int(norm360(pos1_exact[0]) // 30)
    sign2_exact = int(norm360(pos2_exact[0]) // 30)

    sign_changed = (sign1_exact != sign1_0) or (sign2_exact != sign2_0)

    # Check for station/refranation (speed change sign)
    stationed = False
    if pos1_0[3] * pos1_exact[3] < 0 or pos2_0[3] * pos2_exact[3] < 0:
        stationed = True

    return {
        "jd_exact": found_root,
        "offset_days": found_root - jd_start,
        "offset_seconds": (found_root - jd_start) * 86400.0,
        "sign_changed_before_exact": sign_changed,
        "station_refranation_before_exact": stationed,
    }

def calc_aspects_and_candidates(
    bodies: dict[str, dict[str, Any]],
    jd_ut: float,
    display_orb: float = 3.0,
    future_days: float = 30.0,
) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    keys = [b for b in CLASSICAL_BODIES if b in bodies]

    for i in range(len(keys)):
        for j in range(i + 1, len(keys)):
            b1 = bodies[keys[i]]
            b2 = bodies[keys[j]]
            dist = angular_distance(b1["longitude"], b2["longitude"])

            for asp_id, asp_info in PTOLEMAIC_ASPECTS.items():
                target_ang = asp_info["angle"]
                current_orb = abs(dist - target_ang)

                # Check traditional half-orb limit as well
                max_traditional_orb = PLANETARY_MOIETY_ORBS[b1["body_id"]] + PLANETARY_MOIETY_ORBS[b2["body_id"]]

                # We calculate if within display_orb OR within traditional orb
                if current_orb <= max(display_orb, max_traditional_orb):
                    # Check applying vs separating
                    dt = 0.01
                    p1_fut = norm360(b1["longitude"] + b1["speed_lon"] * dt)
                    p2_fut = norm360(b2["longitude"] + b2["speed_lon"] * dt)
                    fut_dist = angular_distance(p1_fut, p2_fut)
                    fut_orb = abs(fut_dist - target_ang)
                    is_applying = fut_orb < current_orb

                    exact_cand = None
                    if is_applying:
                        exact_cand = find_next_exact_aspect(
                            b1["body_id"], b2["body_id"], target_ang, jd_ut, max_days=future_days
                        )

                    results.append({
                        "body1_id": b1["body_id"],
                        "body2_id": b2["body_id"],
                        "aspect_id": asp_id,
                        "aspect_zh": asp_info["name_zh"],
                        "aspect_en": asp_info["name_en"],
                        "orb_deg": round(current_orb, 4),
                        "within_display_orb": current_orb <= display_orb,
                        "is_applying": is_applying,
                        "direction_zh": "入相" if is_applying else "离相",
                        "next_exact": exact_cand,
                    })
    # Sort: applying first, then by orb
    results.sort(key=lambda r: (not r["is_applying"], r["orb_deg"]))
    return results

def calc_directed_receptions(
    dignities: dict[str, dict[str, Any]],
    aspects: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    pairs_done: set[tuple[str, str]] = set()
    rows: list[dict[str, Any]] = []

    for a in aspects:
        b1, b2 = a["body1_id"], a["body2_id"]
        pair_key = tuple(sorted((b1, b2)))
        if pair_key in pairs_done:
            continue
        pairs_done.add(pair_key)

        d1 = dignities[b1]
        d2 = dignities[b2]

        # b2 in dignities of b1:
        # Check what roles b1 plays in b2's position
        b2_in_b1: list[str] = []
        if d2["domicile_ruler"] == b1:
            b2_in_b1.append("入庙 (Domicile)")
        if d2["exaltation_ruler"] == b1:
            b2_in_b1.append("擢升 (Exaltation)")
        if b1 in (d2["triplicity_rulers"]["day"], d2["triplicity_rulers"]["night"], d2["triplicity_rulers"]["participating"]):
            b2_in_b1.append("三分性 (Triplicity)")
        if d2["bound_ruler"] == b1:
            b2_in_b1.append("界 (Bound)")
        if d2["decan_ruler"] == b1:
            b2_in_b1.append("面 (Decan)")
        if d2["detriment_ruler"] == b1:
            b2_in_b1.append("失势 (Detriment)")
        if d2["fall_ruler"] == b1:
            b2_in_b1.append("落陷 (Fall)")

        # b1 in dignities of b2:
        b1_in_b2: list[str] = []
        if d1["domicile_ruler"] == b2:
            b1_in_b2.append("入庙 (Domicile)")
        if d1["exaltation_ruler"] == b2:
            b1_in_b2.append("擢升 (Exaltation)")
        if b2 in (d1["triplicity_rulers"]["day"], d1["triplicity_rulers"]["night"], d1["triplicity_rulers"]["participating"]):
            b1_in_b2.append("三分性 (Triplicity)")
        if d1["bound_ruler"] == b2:
            b1_in_b2.append("界 (Bound)")
        if d1["decan_ruler"] == b2:
            b1_in_b2.append("面 (Decan)")
        if d1["detriment_ruler"] == b2:
            b1_in_b2.append("失势 (Detriment)")
        if d1["fall_ruler"] == b2:
            b1_in_b2.append("落陷 (Fall)")

        rows.append({
            "pair": f"{BODY_NAMES_ZH[b1]} / {BODY_NAMES_ZH[b2]}",
            "body1": b1,
            "body2": b2,
            "b2_in_b1_dignities": b2_in_b1 if b2_in_b1 else ["无显式关系"],
            "b1_in_b2_dignities": b1_in_b2 if b1_in_b2 else ["无显式关系"],
            "has_mutual_positive_reception": bool(set(b2_in_b1) - {"失势 (Detriment)", "落陷 (Fall)"} and
                                                  set(b1_in_b2) - {"失势 (Detriment)", "落陷 (Fall)"}),
        })
    return rows

def calc_moon_story(
    bodies: dict[str, dict[str, Any]],
    jd_ut: float,
) -> dict[str, Any]:
    flags = swe.FLG_SWIEPH | swe.FLG_SPEED
    moon = bodies["MOON"]
    current_sign = int(moon["longitude"] // 30)
    deg_in_sign = moon["longitude"] % 30.0
    remaining_arc = 30.0 - deg_in_sign

    # Ingress into next sign: find when Moon reaches next sign boundary
    target_boundary = (current_sign + 1) * 30.0
    # Search forward in 0.05-day steps
    t_curr = jd_ut
    t_limit = jd_ut + 3.5 # Moon stays ~2.3 days in a sign
    t_exit: float | None = None

    while t_curr < t_limit:
        t_next = t_curr + 0.04
        p_c, _ = swe.calc_ut(t_curr, swe.MOON, flags)
        p_n, _ = swe.calc_ut(t_next, swe.MOON, flags)
        s_c = int(norm360(p_c[0]) // 30)
        s_n = int(norm360(p_n[0]) // 30)
        if s_c == current_sign and s_n != current_sign:
            # Bisect for exit moment
            lo, hi = t_curr, t_next
            for _ in range(30):
                mid = (lo + hi) / 2.0
                pm, _ = swe.calc_ut(mid, swe.MOON, flags)
                if int(norm360(pm[0]) // 30) == current_sign:
                    lo = mid
                else:
                    hi = mid
            t_exit = (lo + hi) / 2.0
            break
        t_curr = t_next

    # Search for Moon's previous aspect in current sign (search backwards to sign ingress)
    # Search backward to find when Moon entered current sign
    t_prev_ingress: float | None = None
    t_back = jd_ut
    while t_back > jd_ut - 3.5:
        t_step = t_back - 0.04
        p_curr, _ = swe.calc_ut(t_back, swe.MOON, flags)
        p_prev, _ = swe.calc_ut(t_step, swe.MOON, flags)
        s_curr = int(norm360(p_curr[0]) // 30)
        s_prev = int(norm360(p_prev[0]) // 30)
        if s_curr == current_sign and s_prev != current_sign:
            lo, hi = t_step, t_back
            for _ in range(30):
                mid = (lo + hi) / 2.0
                pm, _ = swe.calc_ut(mid, swe.MOON, flags)
                if int(norm360(pm[0]) // 30) == current_sign:
                    hi = mid
                else:
                    lo = mid
            t_prev_ingress = (lo + hi) / 2.0
            break
        t_back = t_step

    # Find aspects made by Moon in this sign:
    # Upcoming aspects before t_exit:
    future_aspects_in_sign: list[dict[str, Any]] = []
    other_bodies = [b for b in CLASSICAL_BODIES if b != "MOON"]

    if t_exit is not None:
        for ob in other_bodies:
            for asp_id, asp_info in PTOLEMAIC_ASPECTS.items():
                cand = find_next_exact_aspect("MOON", ob, asp_info["angle"], jd_ut, max_days=(t_exit - jd_ut))
                if cand is not None and cand["jd_exact"] <= t_exit:
                    future_aspects_in_sign.append({
                        "target_id": ob,
                        "target_zh": BODY_NAMES_ZH[ob],
                        "aspect_id": asp_id,
                        "aspect_zh": asp_info["name_zh"],
                        "jd_exact": cand["jd_exact"],
                        "offset_seconds": cand["offset_seconds"],
                    })
    future_aspects_in_sign.sort(key=lambda x: x["jd_exact"])

    # Find previous aspect in this sign
    past_aspects_in_sign: list[dict[str, Any]] = []
    if t_prev_ingress is not None:
        span_past_days = jd_ut - t_prev_ingress
        for ob in other_bodies:
            for asp_id, asp_info in PTOLEMAIC_ASPECTS.items():
                # We can search backwards
                cand = find_next_exact_aspect("MOON", ob, asp_info["angle"], t_prev_ingress, max_days=span_past_days)
                if cand is not None and cand["jd_exact"] <= jd_ut:
                    past_aspects_in_sign.append({
                        "target_id": ob,
                        "target_zh": BODY_NAMES_ZH[ob],
                        "aspect_id": asp_id,
                        "aspect_zh": asp_info["name_zh"],
                        "jd_exact": cand["jd_exact"],
                        "offset_seconds": (cand["jd_exact"] - jd_ut) * 86400.0,
                    })
    past_aspects_in_sign.sort(key=lambda x: x["jd_exact"], reverse=True)
    last_exact_aspect = past_aspects_in_sign[0] if past_aspects_in_sign else None

    # First aspect in next sign
    first_aspect_next_sign: dict[str, Any] | None = None
    if t_exit is not None:
        next_sign_cands: list[dict[str, Any]] = []
        for ob in other_bodies:
            for asp_id, asp_info in PTOLEMAIC_ASPECTS.items():
                cand = find_next_exact_aspect("MOON", ob, asp_info["angle"], t_exit, max_days=2.5)
                if cand is not None:
                    next_sign_cands.append({
                        "target_id": ob,
                        "target_zh": BODY_NAMES_ZH[ob],
                        "aspect_id": asp_id,
                        "aspect_zh": asp_info["name_zh"],
                        "jd_exact": cand["jd_exact"],
                        "offset_seconds": (cand["jd_exact"] - jd_ut) * 86400.0,
                    })
        if next_sign_cands:
            next_sign_cands.sort(key=lambda x: x["jd_exact"])
            first_aspect_next_sign = next_sign_cands[0]

    # Void of Course determination (Lilly's definition)
    # The Moon is VOC if it forms no major applying aspect to the 7 planets before leaving its sign
    is_voc = len(future_aspects_in_sign) == 0
    voc_start_jd = last_exact_aspect["jd_exact"] if (is_voc and last_exact_aspect) else (future_aspects_in_sign[-1]["jd_exact"] if future_aspects_in_sign else jd_ut)

    # Lunar phase
    sun = bodies["SUN"]
    phase_deg = norm360(moon["longitude"] - sun["longitude"])
    is_waxing = phase_deg < 180.0
    illumination = (1.0 - math.cos(math.radians(phase_deg))) / 2.0

    return {
        "current_sign_zh": SIGNS_ZH[current_sign],
        "remaining_arc_deg": round(remaining_arc, 4),
        "jd_ingress_current": t_prev_ingress,
        "jd_exit": t_exit,
        "is_waxing": is_waxing,
        "phase_name_zh": "盈月 (Waxing)" if is_waxing else "亏月 (Waning)",
        "phase_deg": round(phase_deg, 4),
        "illumination_pct": round(illumination * 100.0, 2),
        "last_exact_aspect": last_exact_aspect,
        "future_aspects_in_sign": future_aspects_in_sign,
        "first_aspect_next_sign": first_aspect_next_sign,
        "is_void_of_course": is_voc,
        "voc_interval": {
            "start_jd": voc_start_jd if is_voc else None,
            "end_jd": t_exit if is_voc else None,
        },
    }

def calc_arabic_lots(
    angles: dict[str, float],
    bodies: dict[str, dict[str, Any]],
    is_day: bool,
    cusps: list[float],
) -> dict[str, Any]:
    asc = angles["ASC"]
    sun_lon = bodies["SUN"]["longitude"]
    moon_lon = bodies["MOON"]["longitude"]

    # Lot of Fortune
    # Day: ASC + Moon - Sun; Night: ASC + Sun - Moon
    if is_day:
        fortune_lon = norm360(asc + moon_lon - sun_lon)
        fortune_formula = "上升 + 月亮 - 太阳 (昼盘)"
        spirit_lon = norm360(asc + sun_lon - moon_lon)
        spirit_formula = "上升 + 太阳 - 月亮 (昼盘)"
    else:
        fortune_lon = norm360(asc + sun_lon - moon_lon)
        fortune_formula = "上升 + 太阳 - 月亮 (夜盘)"
        spirit_lon = norm360(asc + moon_lon - sun_lon)
        spirit_formula = "上升 + 月亮 - 太阳 (夜盘)"

    fort_sign = sign_info(fortune_lon)
    fort_house = house_for_longitude(fortune_lon, cusps)
    fort_ruler = SIGN_DOMICILE_RULERS[fort_sign["sign_index"]]

    spirit_sign = sign_info(spirit_lon)
    spirit_house = house_for_longitude(spirit_lon, cusps)
    spirit_ruler = SIGN_DOMICILE_RULERS[spirit_sign["sign_index"]]

    return {
        "fortune": {
            "longitude": fortune_lon,
            "sign": fort_sign,
            "house": fort_house,
            "domicile_ruler": fort_ruler,
            "domicile_ruler_zh": BODY_NAMES_ZH[fort_ruler],
            "formula_zh": fortune_formula,
        },
        "spirit": {
            "longitude": spirit_lon,
            "sign": spirit_sign,
            "house": spirit_house,
            "domicile_ruler": spirit_ruler,
            "domicile_ruler_zh": BODY_NAMES_ZH[spirit_ruler],
            "formula_zh": spirit_formula,
        },
    }

def calc_considerations(
    angles: dict[str, float],
    bodies: dict[str, dict[str, Any]],
    moon_story: dict[str, Any],
    cusps: list[float],
) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    asc_deg = angles["ASC"] % 30.0

    # 1. Early ASC (< 3°)
    if asc_deg < 3.0:
        items.append({
            "code": "early_asc",
            "type_zh": "上升过早 (Early ASC)",
            "detail_zh": f"上升点位于星座初度 ({asc_deg:.2f}° < 3°)，事态过早、尚未成熟或情况未明。",
            "severity": "caution",
        })

    # 2. Late ASC (> 27°)
    if asc_deg > 27.0:
        items.append({
            "code": "late_asc",
            "type_zh": "上升过迟 (Late ASC)",
            "detail_zh": f"上升点位于星座末度 ({asc_deg:.2f}° > 27°)，结局已定、事态已晚或非人力可挽回。",
            "severity": "caution",
        })

    # 3. Moon in Via Combusta (15° Libra to 15° Scorpio: 195° - 225°)
    moon_lon = bodies["MOON"]["longitude"]
    if 195.0 <= moon_lon <= 225.0:
        # Exclude Spica (24° Libra = 204°)
        if not (203.0 <= moon_lon <= 205.0):
            items.append({
                "code": "via_combusta",
                "type_zh": "月亮在燃烧之路 (Via Combusta)",
                "detail_zh": "月亮位于天秤 15° 至天蝎 15° 之间，事态反复险阻、容易遭遇变故。",
                "severity": "warning",
            })

    # 4. Moon Void of Course
    if moon_story["is_void_of_course"]:
        items.append({
            "code": "moon_voc",
            "type_zh": "月亮空亡 (Moon Void of Course)",
            "detail_zh": "月亮在出座前不再与七曜形成五大主相位，多主谋事难成、徒劳无功。",
            "severity": "warning",
        })

    # 5. Saturn in 1st House
    saturn_house = house_for_longitude(bodies["SATURN"]["longitude"], cusps)
    if saturn_house == 1:
        items.append({
            "code": "saturn_in_1st",
            "type_zh": "土星在第1宫",
            "detail_zh": "凶星土星落入第1宫，问卜者受阻受挫、自身处境困难。",
            "severity": "caution",
        })

    # 6. Saturn in 7th House
    if saturn_house == 7:
        items.append({
            "code": "saturn_in_7th",
            "type_zh": "土星在第7宫",
            "detail_zh": "土星落入第7宫，警告占星师判断容易失误或结论令问卜者不满（非第7宫本事人身事项时）。",
            "severity": "caution",
        })

    # 7. Ruler of ASC Combust
    asc_sign_idx = int(angles["ASC"] // 30)
    asc_ruler = SIGN_DOMICILE_RULERS[asc_sign_idx]
    if asc_ruler != "SUN":
        ruler_lon = bodies[asc_ruler]["longitude"]
        sun_lon = bodies["SUN"]["longitude"]
        if angular_distance(ruler_lon, sun_lon) <= 8.5:
            items.append({
                "code": "asc_ruler_combust",
                "type_zh": "命主星燃烧 (ASC Ruler Combust)",
                "detail_zh": f"上升主星 {BODY_NAMES_ZH[asc_ruler]} 被太阳燃烧 (距日 <= 8.5°)，问卜者无力作为或受制于人。",
                "severity": "warning",
            })

    return items

def calc_antiscia(
    bodies: dict[str, dict[str, Any]],
    angles: dict[str, float],
    orb_deg: float = 1.0,
) -> list[dict[str, Any]]:
    # Antiscia reflects across 0° Cancer / 0° Capricorn (axis = 90° / 270°)
    # antiscia_lon = (180.0 - lon) % 360.0
    # contra_antiscia = (360.0 - lon) % 360.0
    contacts: list[dict[str, Any]] = []
    points: dict[str, float] = {b: bodies[b]["longitude"] for b in CLASSICAL_BODIES if b in bodies}
    points["ASC"] = angles["ASC"]
    points["MC"] = angles["MC"]

    keys = list(points.keys())
    for i in range(len(keys)):
        for j in range(len(keys)):
            if i == j:
                continue
            k1, k2 = keys[i], keys[j]
            lon1, lon2 = points[k1], points[k2]
            ant1 = (180.0 - lon1) % 360.0
            contra1 = (360.0 - lon1) % 360.0

            d_ant = angular_distance(lon2, ant1)
            if d_ant <= orb_deg:
                contacts.append({
                    "point": k1,
                    "target": k2,
                    "type": "antiscia",
                    "type_zh": "映点",
                    "orb": round(d_ant, 4),
                })
            d_contra = angular_distance(lon2, contra1)
            if d_contra <= orb_deg:
                contacts.append({
                    "point": k1,
                    "target": k2,
                    "type": "contra_antiscia",
                    "type_zh": "对映点",
                    "orb": round(d_contra, 4),
                })
    return contacts

def calc_fixed_star_conjunctions(
    bodies: dict[str, dict[str, Any]],
    angles: dict[str, float],
    orb_deg: float = 1.0,
) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    points: dict[str, float] = {b: bodies[b]["longitude"] for b in CLASSICAL_BODIES if b in bodies}
    points["ASC"] = angles["ASC"]
    points["MC"] = angles["MC"]

    for star in FIXED_STARS_HORARY:
        s_lon = star["lon"]
        for p_id, p_lon in points.items():
            dist = angular_distance(s_lon, p_lon)
            if dist <= orb_deg:
                hits.append({
                    "star_id": star["id"],
                    "star_name_zh": star["name_zh"],
                    "target": p_id,
                    "target_zh": BODY_NAMES_ZH.get(p_id, p_id),
                    "orb": round(dist, 4),
                    "nature": star["nature"],
                })
    return hits

def calc_planetary_day_and_hour(
    jd_ut: float,
    local_dt: datetime.datetime,
    lat: float,
    lon: float,
) -> dict[str, Any]:
    # Weekday 0=Monday .. 6=Sunday
    weekday = local_dt.weekday()
    day_ruler = CHALDAEAN_WEEKDAY_RULERS[weekday]

    # Calculate sunrise and sunset for local date
    # geopos: (lon, lat, alt)
    geopos = (lon, lat, 0.0)
    # Search around midnight local
    # Approximate sunrise/sunset via swe.rise_trans
    rise_res, rise_tret = swe.rise_trans(jd_ut - 0.5, swe.SUN, swe.CALC_RISE, geopos, 0.0, 0.0)
    set_res, set_tret = swe.rise_trans(jd_ut - 0.5, swe.SUN, swe.CALC_SET, geopos, 0.0, 0.0)

    jd_rise = rise_tret[0] if rise_res == 0 else jd_ut - 0.25
    jd_set = set_tret[0] if set_res == 0 else jd_ut + 0.25

    # If chart is before sunrise, the day ruler belongs to previous day
    # and night hours belong to previous day's sunset -> this day's sunrise
    if jd_ut < jd_rise:
        prev_weekday = (weekday - 1) % 7
        day_ruler = CHALDAEAN_WEEKDAY_RULERS[prev_weekday]
        prev_set_res, prev_set_tret = swe.rise_trans(jd_ut - 1.0, swe.SUN, swe.CALC_SET, geopos, 0.0, 0.0)
        jd_prev_set = prev_set_tret[0] if prev_set_res == 0 else jd_rise - 0.5
        night_hour_len = (jd_rise - jd_prev_set) / 12.0
        hour_num = int((jd_ut - jd_prev_set) / night_hour_len) + 1
        # 12 day hours + hour_num
        start_idx = CHALDAEAN_PLANETARY_HOURS_ORDER.index(day_ruler)
        hour_ruler_idx = (start_idx + 12 + (hour_num - 1)) % len(CHALDAEAN_PLANETARY_HOURS_ORDER)
        hour_ruler = CHALDAEAN_PLANETARY_HOURS_ORDER[hour_ruler_idx]
        is_day_hour = False
    elif jd_ut < jd_set:
        day_hour_len = (jd_set - jd_rise) / 12.0
        hour_num = int((jd_ut - jd_rise) / day_hour_len) + 1
        start_idx = CHALDAEAN_PLANETARY_HOURS_ORDER.index(day_ruler)
        hour_ruler_idx = (start_idx + (hour_num - 1)) % len(CHALDAEAN_PLANETARY_HOURS_ORDER)
        hour_ruler = CHALDAEAN_PLANETARY_HOURS_ORDER[hour_ruler_idx]
        is_day_hour = True
    else:
        # After sunset
        next_rise_res, next_rise_tret = swe.rise_trans(jd_ut, swe.SUN, swe.CALC_RISE, geopos, 0.0, 0.0)
        jd_next_rise = next_rise_tret[0] if next_rise_res == 0 else jd_set + 0.5
        night_hour_len = (jd_next_rise - jd_set) / 12.0
        hour_num = int((jd_ut - jd_set) / night_hour_len) + 1
        start_idx = CHALDAEAN_PLANETARY_HOURS_ORDER.index(day_ruler)
        hour_ruler_idx = (start_idx + 12 + (hour_num - 1)) % len(CHALDAEAN_PLANETARY_HOURS_ORDER)
        hour_ruler = CHALDAEAN_PLANETARY_HOURS_ORDER[hour_ruler_idx]
        is_day_hour = False

    return {
        "day_ruler": day_ruler,
        "day_ruler_zh": BODY_NAMES_ZH[day_ruler],
        "hour_ruler": hour_ruler,
        "hour_ruler_zh": BODY_NAMES_ZH[hour_ruler],
        "is_day_hour": is_day_hour,
        "hour_number": hour_num,
    }

# ---------------------------------------------------------------------------
# Engine Facade & Worksheet Formatter
# ---------------------------------------------------------------------------

class HoraryV301Engine:
    def __init__(self, ephe_path: str | None = None):
        ensure_ephemeris_path(ephe_path)

    def calculate(self, request: dict[str, Any]) -> HoraryChartData:
        # 1. Parse time & location
        moment = request.get("chart", {}).get("moment", {})
        year = int(moment.get("year", 2026))
        month = int(moment.get("month", 1))
        day = int(moment.get("day", 1))
        hour = int(moment.get("hour", 12))
        minute = int(moment.get("minute", 0))
        second = int(moment.get("second", 0))
        tz_str = str(moment.get("timezone", "Asia/Shanghai"))
        try:
            tz = ZoneInfo(tz_str)
        except Exception:
            tz = datetime.timezone.utc
            tz_str = "UTC"

        local_dt = datetime.datetime(year, month, day, hour, minute, second, tzinfo=tz)
        utc_dt = local_dt.astimezone(datetime.timezone.utc)

        lat = float(request.get("chart", {}).get("latitude", request.get("latitude", 31.2304)))
        lon = float(request.get("chart", {}).get("longitude", request.get("longitude", 121.4737)))
        alt = float(request.get("chart", {}).get("altitudeM", request.get("altitude_m", 0.0)))
        hsys_req = str(request.get("chart", {}).get("houseSystem", request.get("house_system", "regiomontanus"))).lower()
        hsys_code = b"R" if "regio" in hsys_req else (b"P" if "plac" in hsys_req else b"W")

        # 2. Julian day
        dec_hour = utc_dt.hour + utc_dt.minute / 60.0 + (utc_dt.second + utc_dt.microsecond / 1e6) / 3600.0
        jd_ut = swe.julday(utc_dt.year, utc_dt.month, utc_dt.day, dec_hour, swe.GREG_CAL)
        delta_t = swe.deltat(jd_ut) * 86400.0

        # 3. Houses & Angles
        try:
            raw_cusps, ascmc = swe.houses(jd_ut, lat, lon, hsys_code)
            cusps = [norm360(c) for c in raw_cusps]
        except Exception:
            # Fallback to Whole Sign
            raw_cusps, ascmc = swe.houses(jd_ut, lat, lon, b"W")
            cusps = [norm360(c) for c in raw_cusps]

        angles = {
            "ASC": norm360(ascmc[0]),
            "MC": norm360(ascmc[1]),
            "DSC": norm360(ascmc[0] + 180.0),
            "IC": norm360(ascmc[1] + 180.0),
            "ARMC": norm360(ascmc[2]),
        }

        # 4. Planetary Coordinates
        bodies: dict[str, dict[str, Any]] = {}
        for b_id in CLASSICAL_BODIES + ["TRUE_NODE"]:
            bodies[b_id] = calc_body_coordinates(jd_ut, b_id)

        # Add South Node
        tn = bodies["TRUE_NODE"]
        s_lon = norm360(tn["longitude"] + 180.0)
        bodies["SOUTH_TRUE_NODE"] = {
            "body_id": "SOUTH_TRUE_NODE",
            "name_zh": "南交点(真)",
            "name_en": "South Node",
            "longitude": s_lon,
            "latitude": -tn["latitude"],
            "distance": tn["distance"],
            "speed_lon": tn["speed_lon"],
            "sign": sign_info(s_lon),
            "motion": tn["motion"],
        }

        # Assign houses to planets
        for b in bodies.values():
            b["house"] = house_for_longitude(b["longitude"], cusps)

        # 5. Day vs Night Sect (Sun above horizon: between ASC and DSC via MC)
        sun_lon = bodies["SUN"]["longitude"]
        asc_lon = angles["ASC"]
        dsc_lon = angles["DSC"]
        # Sun is above horizon if its arc from DSC to ASC via MC holds
        is_day = ((sun_lon - dsc_lon) % 360.0) < ((asc_lon - dsc_lon) % 360.0)

        # 6. Solar condition for planets
        for b_id, b in bodies.items():
            if b_id in CLASSICAL_BODIES and b_id != "SUN":
                b["solar_condition"] = calc_solar_condition(
                    b["longitude"], sun_lon, b["speed_lon"], bodies["SUN"]["speed_lon"]
                )

        # 7. Dignities
        dignities: dict[str, dict[str, Any]] = {}
        for b_id in CLASSICAL_BODIES:
            dignities[b_id] = calc_essential_dignities(b_id, bodies[b_id]["longitude"], is_day)

        # 8. Aspects & Candidates
        orb_cfg = float(request.get("aspectOrb", request.get("aspect_orb", 3.0)))
        future_cfg = float(request.get("eventFutureDays", request.get("future_days", 30.0)))
        aspects = calc_aspects_and_candidates(bodies, jd_ut, display_orb=orb_cfg, future_days=future_cfg)

        # 9. Receptions
        receptions = calc_directed_receptions(dignities, aspects)

        # 10. Lunar Timeline & Void of Course
        moon_story = calc_moon_story(bodies, jd_ut)

        # 11. Arabic Lots
        lots = calc_arabic_lots(angles, bodies, is_day, cusps)

        # 12. Considerations
        considerations = calc_considerations(angles, bodies, moon_story, cusps)

        # 13. Antiscia
        antiscia = calc_antiscia(bodies, angles, orb_deg=1.0)

        # 14. Fixed Stars
        fixed_stars = calc_fixed_star_conjunctions(bodies, angles, orb_deg=1.0)

        # 15. Planetary Day & Hour
        day_hour = calc_planetary_day_and_hour(jd_ut, local_dt, lat, lon)

        return HoraryChartData(
            utc_datetime=utc_dt,
            local_datetime=local_dt,
            timezone_name=tz_str,
            latitude=lat,
            longitude=lon,
            altitude_m=alt,
            house_system="regiomontanus",
            jd_ut=jd_ut,
            delta_t=delta_t,
            is_day=is_day,
            angles=angles,
            cusps=cusps,
            bodies=bodies,
            dignities=dignities,
            aspects=aspects,
            receptions=receptions,
            moon_story=moon_story,
            lots=lots,
            considerations=considerations,
            antiscia=antiscia,
            fixed_stars=fixed_stars,
            planetary_day_hour=day_hour,
            question_text=str(request.get("questionText", request.get("question_text", ""))),
            place_name=str(request.get("placeName", request.get("place_name", ""))),
        )

# ---------------------------------------------------------------------------
# Chinese Reader Markdown Worksheet Generation
# ---------------------------------------------------------------------------

def jd_to_local_str(jd: float, tz: ZoneInfo | datetime.timezone) -> str:
    # Convert Julian Day back to local string
    # Swe julday reverse: swe.revjul
    y, m, d, h_dec = swe.revjul(jd, swe.GREG_CAL)
    h = int(h_dec)
    rem_m = (h_dec - h) * 60.0
    minute = int(rem_m)
    sec = int(round((rem_m - minute) * 60.0))
    if sec >= 60:
        sec = 0
        minute += 1
    if minute >= 60:
        minute = 0
        h += 1
    dt_utc = datetime.datetime(y, m, d, h % 24, minute, sec, tzinfo=datetime.timezone.utc)
    dt_local = dt_utc.astimezone(tz)
    return dt_local.strftime("%Y-%m-%d %H:%M:%S%z")

def generate_reader_markdown(chart: HoraryChartData) -> str:
    lines: list[str] = [
        f"# Horary V{SCHEMA_VERSION} 解盘工作表",
        "",
        f"**起盘时间：** {chart.local_datetime.strftime('%Y-%m-%d %H:%M:%S%z')}" + (f" · {chart.place_name}" if chart.place_name else ""),
    ]
    if chart.question_text:
        lines.append(f"**占问问题：** {chart.question_text}")

    sect_str = "昼盘 (Day)" if chart.is_day else "夜盘 (Night)"
    lines.append(f"**基本参数：** Regiomontanus 宫制 · 回归黄道 · 埃及界 · Dorothean 三分性 · {sect_str}。")
    lines.append(f"经纬度：{chart.latitude:.5f}, {chart.longitude:.5f}；时区：{chart.timezone_name}。下文时间均为当地时间。")
    lines.append("")

    # 1. 宫位与取用
    lines.extend([
        "## 1. 宫位与取用参考",
        "",
        "| 宫位 | 宫头度数 | 宫头星座 | 宫主星 |",
        "| :--- | :--- | :--- | :--- |",
    ])
    for h in range(1, 13):
        c_lon = chart.cusps[h - 1]
        s_inf = sign_info(c_lon)
        ruler = SIGN_DOMICILE_RULERS[s_inf["sign_index"]]
        lines.append(f"| 第 {h} 宫 | {format_dms(s_inf['degree_in_sign'])} | {s_inf['sign_zh']} | {BODY_NAMES_ZH[ruler]} |")
    lines.append("")

    # 2. 七曜状态
    lines.extend([
        "## 2. 七曜状态与运动",
        "",
        "| 星体 | 黄经位置 | 宫位 | 运动状态 | 日速(度/天) | 日光状态 |",
        "| :--- | :--- | :--- | :--- | :--- | :--- |",
    ])
    for b_id in CLASSICAL_BODIES:
        b = chart.bodies[b_id]
        s_inf = b["sign"]
        motion_zh = "逆行" if b["motion"] == "retrograde" else ("停滞" if b["motion"] == "stationary" else "顺行")
        solar_str = b.get("solar_condition", {}).get("status_zh", "不适用" if b_id == "SUN" else "均否")
        lines.append(
            f"| {b['name_zh']} | {format_dms(s_inf['degree_in_sign'], s_inf['sign_zh'])} | "
            f"第 {b['house']} 宫 | {motion_zh} | {b['speed_lon']:.3f} | {solar_str} |"
        )
    lines.append("")

    # 3. 本质尊贵与得势
    lines.extend([
        "## 3. 本质尊贵与得势 (Essential Dignities)",
        "",
        "| 星体 | 自身得势/失势 | 庙主 | 擢升主 | 当令三分主 | 界主 | 面主 | 尊贵分 |",
        "| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |",
    ])
    for b_id in CLASSICAL_BODIES:
        d = chart.dignities[b_id]
        status_terms: list[str] = []
        if "domicile" in d["dignity_types"]:
            status_terms.append("入庙")
        if "exaltation" in d["dignity_types"]:
            status_terms.append("擢升")
        if "detriment" in d["dignity_types"]:
            status_terms.append("落陷(失势)")
        if "fall" in d["dignity_types"]:
            status_terms.append("下沉(落陷)")
        if d["is_peregrine"]:
            status_terms.append("游荡(无力)")
        if not status_terms:
            status_terms.append("微弱尊贵")

        status_display = "、".join(status_terms)
        exalt_str = BODY_NAMES_ZH[d["exaltation_ruler"]] if d["exaltation_ruler"] else "无"
        lines.append(
            f"| {BODY_NAMES_ZH[b_id]} | {status_display} | {BODY_NAMES_ZH[d['domicile_ruler']]} | "
            f"{exalt_str} | {BODY_NAMES_ZH[d['triplicity_active']]} | {BODY_NAMES_ZH[d['bound_ruler']]} | "
            f"{BODY_NAMES_ZH[d['decan_ruler']]} | {d['score']:+d} |"
        )
    lines.append("")

    # 4. 相位与成相候选
    lines.extend([
        "## 4. 相位与成相候选",
        "",
        "| 星对 | 相位 | 当前容许度 | 方向 | 下次精确成相 (当地时间) | 阻碍检查 (换座/逆行) |",
        "| :--- | :--- | :--- | :--- | :--- | :--- |",
    ])
    tz = chart.local_datetime.tzinfo or ZoneInfo(chart.timezone_name)
    if not chart.aspects:
        lines.append("| (无容许度内相位) | - | - | - | - | - |")
    else:
        for a in chart.aspects:
            pair_name = f"{BODY_NAMES_ZH[a['body1_id']]} / {BODY_NAMES_ZH[a['body2_id']]}"
            exact_time_str = "无或已离相"
            obstacle_str = "无"
            if a["next_exact"]:
                exact_time_str = jd_to_local_str(a["next_exact"]["jd_exact"], tz)
                obs_list: list[str] = []
                if a["next_exact"]["sign_changed_before_exact"]:
                    obs_list.append("成相前换座(阻断)")
                if a["next_exact"]["station_refranation_before_exact"]:
                    obs_list.append("成相前停滞/反悔(Refranation)")
                obstacle_str = "、".join(obs_list) if obs_list else "成相顺畅"
            lines.append(
                f"| {pair_name} | {a['aspect_zh']} | {a['orb_deg']:.2f}° | "
                f"{a['direction_zh']} | {exact_time_str} | {obstacle_str} |"
            )
    lines.append("")

    # 5. 相关星对接纳
    lines.extend([
        "## 5. 相关星对接纳关系 (Receptions)",
        "",
        "| 前者 / 后者 | 后者在前者的尊贵位置 | 前者在后者的尊贵位置 | 互溶(互惠接纳) |",
        "| :--- | :--- | :--- | :--- |",
    ])
    if not chart.receptions:
        lines.append("| (无相位星对) | - | - | - |")
    else:
        for r in chart.receptions:
            b2_in_b1 = "、".join(r["b2_in_b1_dignities"])
            b1_in_b2 = "、".join(r["b1_in_b2_dignities"])
            mutual_str = "是 (正向互溶)" if r["has_mutual_positive_reception"] else "否"
            lines.append(f"| {r['pair']} | {b2_in_b1} | {b1_in_b2} | {mutual_str} |")
    lines.append("")

    # 6. 月亮推进与空亡
    ms = chart.moon_story
    lines.extend([
        "## 6. 月亮推进与空亡 (The Moon's Storyline)",
        "",
        f"**月相：** {ms['phase_name_zh']} · 光照度 {ms['illumination_pct']}% · 距太阳 {ms['phase_deg']:.2f}°",
        "",
        "| 阶段 | 事件 | 目标星体/余度 | 精确时间 (当地时间) |",
        "| :--- | :--- | :--- | :--- |",
    ])
    if ms["last_exact_aspect"]:
        la = ms["last_exact_aspect"]
        lines.append(f"| 本座最近离相 | {la['aspect_zh']} | {la['target_zh']} | {jd_to_local_str(la['jd_exact'], tz)} |")
    else:
        lines.append("| 本座最近离相 | 无 | - | - |")

    if ms["jd_exit"]:
        lines.append(f"| 离开当前星座 | 换座 | 剩余 {ms['remaining_arc_deg']:.2f}° | {jd_to_local_str(ms['jd_exit'], tz)} |")

    if ms["first_aspect_next_sign"]:
        fa = ms["first_aspect_next_sign"]
        lines.append(f"| 换座后第一相位 | {fa['aspect_zh']} | {fa['target_zh']} | {jd_to_local_str(fa['jd_exact'], tz)} |")

    lines.append("")
    voc_status = "是 (Void of Course)" if ms["is_void_of_course"] else "否 (推进顺畅)"
    lines.append(f"**当前月亮是否空亡：** {voc_status}")
    if ms["is_void_of_course"] and ms["voc_interval"]["start_jd"] and ms["voc_interval"]["end_jd"]:
        t_s = jd_to_local_str(ms["voc_interval"]["start_jd"], tz)
        t_e = jd_to_local_str(ms["voc_interval"]["end_jd"], tz)
        lines.append(f"空亡有效区间：{t_s} 至 {t_e}。")
    lines.append("")

    # 7. 审盘注意事项
    lines.extend([
        "## 7. 审盘注意事项与考虑因素 (Considerations)",
        "",
    ])
    if not chart.considerations:
        lines.append("未检出严苛的阻碍或失效提示，全盘基础状态清明。")
    else:
        for c in chart.considerations:
            lines.append(f"- **{c['type_zh']}**：{c['detail_zh']}")
    lines.append("")

    # 8. 辅助点与恒星
    fort = chart.lots["fortune"]
    spirit = chart.lots["spirit"]
    dh = chart.planetary_day_hour
    lines.extend([
        "## 8. 辅助点、恒星与日时主星",
        "",
        f"- **福点 (Pars Fortunae)**：{fort['sign']['formatted_zh']} (第 {fort['house']} 宫)，定位星 {fort['domicile_ruler_zh']}；公式：`{fort['formula_zh']}`",
        f"- **精神点 (Pars Spiritus)**：{spirit['sign']['formatted_zh']} (第 {spirit['house']} 宫)，定位星 {spirit['domicile_ruler_zh']}；公式：`{spirit['formula_zh']}`",
        f"- **行星日/时主星**：日主 **{dh['day_ruler_zh']}**，时主 **{dh['hour_ruler_zh']}** (第 {dh['hour_number']} 刻，{'昼时' if dh['is_day_hour'] else '夜时'})",
    ])
    if chart.fixed_stars:
        lines.append("- **重要恒星合相 (1°容许度内)**：")
        for fs in chart.fixed_stars:
            lines.append(f"  - {fs['target_zh']} 合 {fs['star_name_zh']} (容许度 {fs['orb']:.2f}°)：{fs['nature']}")
    if chart.antiscia:
        lines.append("- **映点与对映点**：")
        for ant in chart.antiscia[:6]: # limit top 6
            lines.append(f"  - {BODY_NAMES_ZH.get(ant['point'], ant['point'])} 与 {BODY_NAMES_ZH.get(ant['target'], ant['target'])} 呈{ant['type_zh']} (容许度 {ant['orb']:.2f}°)")

    lines.extend([
        "",
        "---",
        f"*数据包版本：{SCHEMA_ID} · 引擎：{ENGINE_NAME} {ENGINE_VERSION}*",
    ])
    return "\n".join(lines)

# ---------------------------------------------------------------------------
# Packet Serialization & Pipeline Wrapper
# ---------------------------------------------------------------------------

def calculate_horary_v3_0_1(request: dict[str, Any]) -> dict[str, Any]:
    engine = HoraryV301Engine(request.get("ephemerisPath", request.get("ephemeris_path")))
    chart = engine.calculate(request)
    reader_md = generate_reader_markdown(chart)

    # Clean JSON payload
    packet = {
        "schema": {
            "name": "horary-data-packet",
            "version": SCHEMA_VERSION,
            "schema_id": SCHEMA_ID,
        },
        "provenance": {
            "engine_name": ENGINE_NAME,
            "engine_version": ENGINE_VERSION,
            "algorithm_version": ALGORITHM_VERSION,
            "input_hash_sha256": hashlib.sha256(json.dumps(request, sort_keys=True, ensure_ascii=False).encode()).hexdigest(),
        },
        "time_and_location": {
            "utc_datetime": chart.utc_datetime.isoformat(),
            "local_datetime": chart.local_datetime.isoformat(),
            "timezone": chart.timezone_name,
            "latitude": chart.latitude,
            "longitude": chart.longitude,
            "altitude_m": chart.altitude_m,
            "jd_ut": chart.jd_ut,
            "delta_t_seconds": chart.delta_t,
            "is_day": chart.is_day,
        },
        "houses": {
            "system": chart.house_system,
            "cusps": chart.cusps,
        },
        "angles": chart.angles,
        "bodies": chart.bodies,
        "dignities": chart.dignities,
        "aspects": chart.aspects,
        "receptions": chart.receptions,
        "moon": chart.moon_story,
        "lots": chart.lots,
        "considerations": chart.considerations,
        "antiscia": chart.antiscia,
        "fixed_stars": chart.fixed_stars,
        "planetary_day_hour": chart.planetary_day_hour,
        "display": {
            "reader_markdown": reader_md,
        },
    }
    return packet

# ---------------------------------------------------------------------------
# CLI Entrypoint
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description=f"Horary V{SCHEMA_VERSION} Standalone Backend Engine")
    parser.add_argument("--sample", action="store_true", help="Run with built-in representative sample horary chart")
    parser.add_argument("--markdown", action="store_true", help="Output only the human-readable Markdown worksheet")
    args = parser.parse_args()

    if args.sample:
        req = {
            "chart": {
                "moment": {
                    "year": 2026,
                    "month": 10,
                    "day": 1,
                    "hour": 22,
                    "minute": 3,
                    "second": 10,
                    "timezone": "Asia/Shanghai",
                },
                "latitude": 36.1075,
                "longitude": 120.4688,
                "houseSystem": "regiomontanus",
            },
            "questionText": "崂山区代表时刻卜卦测试",
            "placeName": "崂山区",
            "aspectOrb": 3.0,
        }
    else:
        # Read from stdin
        if sys.stdin.isatty():
            parser.print_help()
            return
        try:
            req = json.load(sys.stdin)
        except Exception as exc:
            sys.stderr.write(f"Error reading JSON from stdin: {exc}\n")
            sys.exit(1)

    result = calculate_horary_v3_0_1(req)
    if args.markdown:
        print(result["display"]["reader_markdown"])
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
