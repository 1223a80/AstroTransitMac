from __future__ import annotations

import math
from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    CLASSICAL_BODY_IDS,
    SIGNS,
    completed_age,
    declination_from_lon,
    format_longitude,
    jd_from_datetime,
    norm360,
    obliquity,
    planet_name,
    right_ascension_from_lon,
    sign_degree,
    zodiac_sign_index,
)
from astro_backend_ephemeris import build_houses, body_longitude_at, calculate_positions

ASPECT_ANGLES = {
    "conjunction": 0.0,
    "sextile": 60.0,
    "square": 90.0,
    "trine": 120.0,
    "opposition": 180.0,
}

ASPECT_NAMES = {
    "conjunction": "合相",
    "sextile": "六合",
    "square": "刑相",
    "trine": "拱相",
    "opposition": "冲相",
}

NAIBOD_RATE = 0.9856


def right_ascension(lon: float, obliq: float) -> float:
    return right_ascension_from_lon(lon, obliq)


def declination(lon: float, obliq: float) -> float:
    return declination_from_lon(lon, obliq)


def meridian_distance(ra: float, mc_ra: float) -> float:
    return norm360(ra - mc_ra)


def ascensional_difference(lon: float, obliq: float, latitude: float) -> float:
    dec = declination(lon, obliq)
    dec_rad = math.radians(dec)
    lat_rad = math.radians(latitude)
    try:
        ad = math.degrees(math.asin(math.tan(dec_rad) * math.tan(lat_rad)))
    except (ValueError, ZeroDivisionError):
        ad = 0.0
    return ad


def semi_arc(lon: float, obliq: float, latitude: float, is_diurnal: bool) -> float:
    ad = ascensional_difference(lon, obliq, latitude)
    if is_diurnal:
        return 180.0 - ad
    return 180.0 + ad


def latitude_adjusted_arc_position(lon: float, obliq: float, latitude: float, is_diurnal: bool) -> float:
    ra = right_ascension(lon, obliq)
    return ra + (semi_arc(lon, obliq, latitude, is_diurnal) - 180.0)


def platiclon_to_arc(promissor_lon: float, significator_lon: float, obliq: float, latitude: float, is_diurnal: bool) -> float:
    ra_prom = latitude_adjusted_arc_position(promissor_lon, obliq, latitude, is_diurnal)
    ra_sig = latitude_adjusted_arc_position(significator_lon, obliq, latitude, is_diurnal)
    arc = norm360(ra_sig - ra_prom)
    if arc > 180:
        arc = arc - 360
    return arc


def _make_direction(
    prom_id: str,
    sig_id: str,
    prom_lon: float,
    sig_lon: float,
    asp_type: str,
    asp_name: str,
    obliq: float,
    latitude: float,
    is_diurnal: bool,
    birth_dt: datetime,
    max_age: int,
) -> dict[str, Any] | None:
    if asp_type == "conjunction":
        target_lon = sig_lon
    else:
        target_lon = norm360(sig_lon + ASPECT_ANGLES.get(asp_type, 0.0))

    arc = platiclon_to_arc(prom_lon, target_lon, obliq, latitude, is_diurnal)
    age_at = arc / NAIBOD_RATE
    direction_type = "direct" if arc >= 0 else "converse"
    abs_age = abs(age_at)

    if abs_age > max_age:
        return None

    event_dt_after_birth = birth_dt + timedelta(days=abs_age * 365.2425)
    symbolic_date = birth_dt + timedelta(days=age_at * 365.2425)
    return {
        "id": f"pd-{prom_id}-{sig_id}-{asp_type}",
        "promissor": planet_name(prom_id),
        "promissor_id": prom_id,
        "significator": sig_id if sig_id in fixed_point_names else planet_name(sig_id),
        "significator_id": sig_id,
        "aspect_type": asp_type,
        "aspect_name": asp_name,
        "natal_promissor_lon": round(prom_lon, 4),
        "natal_significator_lon": round(sig_lon, 4),
        "direction_type": direction_type,
        "arc_signed": round(arc, 4),
        "arc_abs": round(abs_age * NAIBOD_RATE, 4),
        "age_from_abs_arc": round(abs_age, 2),
        "event_date_after_birth": event_dt_after_birth.strftime("%Y-%m-%d"),
        "symbolic_date_from_signed_arc": symbolic_date.strftime("%Y-%m-%d") if arc < 0 else None,
    }


fixed_point_names = {"ASC", "MC", "DSC", "IC"}


def calculate_primary_directions(
    birth_jd: float,
    birth_dt: datetime,
    latitude: float,
    longitude: float,
    house_system: str,
    sidereal: bool,
    warnings: list[str],
    max_age: int = 90,
    reference_dt: datetime | None = None,
    window_years: float = 3.0,
) -> list[dict[str, Any]]:
    obliq = obliquity(birth_jd)
    cusps, angles, _ = build_houses(birth_jd, latitude, longitude, house_system, sidereal, warnings)

    specs = [BODY_REGISTRY[bid] for bid in CLASSICAL_BODY_IDS]
    positions = calculate_positions(birth_jd, specs, warnings, sidereal=sidereal)
    pos_by_id = {row["body_id"]: row for row in positions}

    mc_lon = angles.get("MC", 0.0)
    asc_lon = angles.get("ASC", 0.0)
    sun_lon = pos_by_id["SUN"]["longitude"]
    sun_house = 1
    for i, cusp in enumerate(cusps[:-1]):
        next_cusp = cusps[i + 1] if i + 1 < len(cusps) else cusps[0] + 360
        if cusp <= sun_lon < next_cusp or (next_cusp < cusp and (sun_lon >= cusp or sun_lon < next_cusp)):
            sun_house = i + 1
            break
    is_diurnal = sun_house >= 7

    directions: list[dict[str, Any]] = []

    fixed_points = {
        "ASC": asc_lon,
        "MC": mc_lon,
        "DSC": norm360(asc_lon + 180),
        "IC": norm360(mc_lon + 180),
    }

    planet_ids = list(pos_by_id.keys())

    for prom_id in planet_ids:
        prom_lon = pos_by_id[prom_id]["longitude"]
        for sig_name, sig_lon in fixed_points.items():
            d = _make_direction(prom_id, sig_name, prom_lon, sig_lon, "conjunction", "合相", obliq, latitude, is_diurnal, birth_dt, max_age)
            if d:
                directions.append(d)

    for sig_name, sig_lon in fixed_points.items():
        for prom_id in planet_ids:
            prom_lon = pos_by_id[prom_id]["longitude"]
            d = _make_direction(sig_name, prom_id, sig_lon, prom_lon, "conjunction", "合相", obliq, latitude, is_diurnal, birth_dt, max_age)
            if d:
                directions.append(d)

    for prom_id in planet_ids:
        prom_lon = pos_by_id[prom_id]["longitude"]
        for sig_id in planet_ids:
            if prom_id == sig_id:
                continue
            sig_lon = pos_by_id[sig_id]["longitude"]
            for asp_name, asp_angle in ASPECT_ANGLES.items():
                if asp_name == "conjunction":
                    continue
                d = _make_direction(prom_id, sig_id, prom_lon, sig_lon, asp_name, ASPECT_NAMES[asp_name], obliq, latitude, is_diurnal, birth_dt, max_age)
                if d:
                    directions.append(d)

    seen: set[str] = set()
    unique: list[dict[str, Any]] = []
    for d in directions:
        key = d["id"]
        if key not in seen:
            seen.add(key)
            unique.append(d)

    unique.sort(key=lambda d: d["age_from_abs_arc"])

    # Apply reference-age window filter (default ±3 years)
    if reference_dt is not None:
        ref_age = completed_age(birth_dt, reference_dt)
        unique = [
            d for d in unique
            if ref_age - window_years <= d["age_from_abs_arc"] <= ref_age + window_years
        ]

    return unique
