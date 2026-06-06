"""Shadbala (six-fold strength) calculation for Jyotish.

Formulas sourced from Maitreya ShadBala.cpp by Martin Pettau.
"""

from __future__ import annotations

import math
from datetime import datetime
from typing import Any

from astro_backend_core import norm360, swe, zodiac_sign_index
from astro_backend_jyotish_data import (
    UCCHA_DEGREES, NEECHA_DEGREES, NAISARGIKA_FRIENDSHIP,
    GRAHA_DRISHTI, VEDIC_PLANET_IDS,
    is_planet_friend, is_planet_enemy,
)


def _angular_distance(a: float, b: float) -> float:
    """Shortest angular distance between two longitudes."""
    diff = abs(a - b) % 360.0
    return min(diff, 360.0 - diff)


def calc_uchcha_bala(planet_id: str, longitude: float) -> float:
    """Uchcha Bala (exaltation strength): 0-60 virupas.
    From Maitreya: a = red_deg(exaltation_point - planet_longitude - 180)
    if a > 180: a = 360 - a
    bala = a / 3
    Max 60 virupas when planet is at exact exaltation degree.
    """
    if planet_id not in UCCHA_DEGREES:
        return 0.0
    exalt = UCCHA_DEGREES[planet_id]
    a = norm360(exalt - longitude - 180.0)
    if a > 180.0:
        a = 360.0 - a
    return a / 3.0


def calc_dig_bala(planet_id: str, longitude: float, asc_longitude: float) -> float:
    """Dig Bala (directional strength): 0-60 virupas.
    Each planet is strongest in a specific house direction:
    - Sun/Mars: 10th house (MC, south)
    - Jupiter/Mercury: 1st house (ASC, east)
    - Moon/Venus: 4th house (IC, north)
    - Saturn: 7th house (DSC, west)

    Uses the planet's Whole Sign house position relative to ASC.
    From Maitreya ShadBala.cpp: distance from planet house to weakest house.
    """
    asc_rasi = zodiac_sign_index(asc_longitude)
    planet_rasi = zodiac_sign_index(longitude)

    # Planet's Whole Sign house (0-based: 0=1st house)
    planet_house = (planet_rasi - asc_rasi) % 12

    # The "weakest house" index (0-based where 0=1st house)
    weakest_house = {
        "SUN": 3, "MARS": 3,       # Weakest in 4th house (IC)
        "JUPITER": 6, "MERCURY": 6, # Weakest in 7th house (DSC)
        "MOON": 9, "VENUS": 9,      # Weakest in 10th house (MC)
        "SATURN": 0,                # Weakest in 1st house (ASC)
    }

    if planet_id not in weakest_house:
        return 0.0

    wh = weakest_house[planet_id]
    # Distance from planet house to weakest house
    dist = (planet_house - wh) % 12
    if dist > 6:
        dist = 12 - dist
    return dist * 10.0  # 0-60 virupas


def calc_paksha_bala(sun_lon: float, moon_lon: float) -> tuple[float, dict[str, float]]:
    """Paksha Bala (phase strength): based on Moon's phase from Sun.
    Full moon (180°) gives max benefit to benefic planets.
    New moon (0°) gives max strength to malefic planets.
    Returns dict with bala for each planet.
    """
    dist = _angular_distance(sun_lon, moon_lon)
    paksha_value = dist / 3.0  # 0-60

    # Benefics get paksha_value, malefics get 60-paksha_value
    # Moon and Mercury vary based on their own benefic/malefic nature
    balas = {
        "SUN": 60.0 - paksha_value,
        "MOON": paksha_value,
        "MARS": 60.0 - paksha_value,
        "MERCURY": paksha_value,
        "JUPITER": paksha_value,
        "VENUS": paksha_value,
        "SATURN": 60.0 - paksha_value,
    }
    return paksha_value, balas


def calc_nathonatha_bala(jd_ut: float, latitude: float, longitude: float) -> dict[str, float]:
    """Nathonatha Bala (diurnal/nocturnal strength).
    Based on whether the birth was in day or night and distance from noon.
    """
    # Calculate local mean time from JD
    # LMT = JD + longitude/360 adjustment
    from astro_backend_ephemeris import call_houses_ex

    sidereal = 0  # tropical for houses
    try:
        cusps, ascmc = call_houses_ex(jd_ut, latitude, longitude, "P", False)
    except Exception:
        return {p: 30.0 for p in VEDIC_PLANET_IDS[:7]}

    # Approximate: distance from noon in hours
    jd_at_noon = math.floor(jd_ut) + 0.5
    hours_from_noon = (jd_ut - jd_at_noon) * 24.0
    if hours_from_noon < 0:
        hours_from_noon += 24.0
    if hours_from_noon > 12:
        hours_from_noon = 24.0 - hours_from_noon

    natabala = hours_from_noon * 5.0  # 0-60 virupas

    return {
        "SUN": 60.0 - natabala,
        "MOON": natabala,
        "MARS": natabala,
        "MERCURY": 60.0,
        "JUPITER": 60.0 - natabala,
        "VENUS": 60.0 - natabala,
        "SATURN": natabala,
    }


def calc_naisargika_bala() -> dict[str, float]:
    """Naisargika Bala (natural strength): fixed values.
    From Maitreya: Order from weakest to strongest:
    Sun(0, 60), Moon(1, 51.4), Venus(4, 25.7), Jupiter(2, 42.9),
    Mercury(5, 17.1), Mars(3, 34.3), Saturn(6, 8.6)
    """
    # Base values: 7 planets ordered by natural strength
    # The strongest gets 60 rupas, scaled proportionally
    base = [60.0, 51.43, 42.86, 34.29, 25.71, 17.14, 8.57]
    return {
        "SUN": base[0],
        "MOON": base[1],
        "MERCURY": base[4],
        "VENUS": base[3],
        "MARS": base[2],
        "JUPITER": base[5],
        "SATURN": base[6],
    }


def calc_shadbala(
    planet_positions: dict[str, dict[str, Any]],
    jd_ut: float,
    latitude: float,
    longitude: float,
    asc_longitude: float | None = None,
) -> dict[str, dict[str, Any]]:
    """Calculate Shadbala (six-fold strength) for all 7 visible planets.

    Returns dict with each planet's 6 balas + total + percentage.

    This implementation is still incomplete because full Sthana/Kala/Drik
    subcomponents are not yet modeled. The numeric totals are exposed for
    inspection, but minimum-requirement pass/fail judgments are suppressed.
    """
    result: dict[str, dict[str, Any]] = {}

    sun_lon = planet_positions.get("SUN", {}).get("longitude", 0.0)
    moon_lon = planet_positions.get("MOON", {}).get("longitude", 0.0)

    # Use provided asc_longitude, default to 0° Aries if not available
    _asc_lon = asc_longitude if asc_longitude is not None else 0.0
    uchcha = {}
    for pid in ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"]:
        if pid in planet_positions:
            uchcha[pid] = calc_uchcha_bala(pid, planet_positions[pid]["longitude"])

    # Dig Bala
    dig = {}
    for pid in ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"]:
        if pid in planet_positions:
            dig[pid] = calc_dig_bala(pid, planet_positions[pid]["longitude"], _asc_lon)

    # Paksha Bala
    _, paksha_result = calc_paksha_bala(sun_lon, moon_lon)

    # Nathonatha Bala
    nathonatha = calc_nathonatha_bala(jd_ut, latitude, longitude)

    # Naisargika Bala
    naisargika = calc_naisargika_bala()

    # Required Shadbala (minimum needed for full strength)
    required = {"SUN": 390, "MOON": 360, "MARS": 300, "MERCURY": 420,
                "JUPITER": 390, "VENUS": 330, "SATURN": 300}

    # Combine all
    for pid in ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"]:
        if pid not in planet_positions:
            continue
        sb = uchcha.get(pid, 0.0)  # Sthana Bala = Uchcha (simplified)
        db = dig.get(pid, 0.0)      # Dig Bala
        paksha_val = paksha_result.get(pid, 30.0)
        nth_val = nathonatha.get(pid, 30.0)
        # Simplified Kala Bala = Nathonatha + Paksha + Tribhaga
        kb = nth_val + paksha_val + 15.0 if pid in ["JUPITER"] else nth_val + paksha_val
        nb = naisargika.get(pid, 30.0)
        # Cheshta Bala simplified: ~30 rupas for slow/retrograde
        speed = planet_positions[pid].get("speed", 0.0)
        cb = 45.0 if speed < 0 else 30.0 if abs(speed) < 0.3 else 15.0

        total = sb + db + kb + cb + nb
        req = required.get(pid, 300)
        pct = min(100.0, total / req * 100.0)

        rupas = total / 60.0
        required_rupas = req / 60.0
        result[pid] = {
            "sthāna_bala": round(sb, 1),
            "dig_bala": round(db, 1),
            "kāla_bala": round(kb, 1),
            "ceṣṭa_bala": round(cb, 1),
            "naiṣargika_bala": round(nb, 1),
            "dṛg_bala": 0.0,  # Not implemented in simplified version
            "shadbala_total": round(total, 1),
            "shadbala_rupas": round(rupas, 2),
            "required": req,
            "required_rupas": round(required_rupas, 2),
            "meets_required": None,
            "percent": round(pct, 1),
            "is_complete": False,
            "status": "incomplete",
            "note": "Full Sthana/Dig/Kala/Cheshta/Naisargika/Drik implementation pending; no meets_required judgment is allowed.",
            "display_summary": None,
        }

    return result
