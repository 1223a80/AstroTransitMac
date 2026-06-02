from __future__ import annotations

from datetime import timedelta, timezone
from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    angular_separation,
    format_local,
    moment_to_jd,
    moment_to_local_datetime,
    norm360,
    set_zodiac_mode,
)
from astro_backend_ephemeris import (
    build_houses,
    calculate_positions,
    house_for_longitude,
    house_rows,
    point_row,
    resolve_bodies,
)
from astro_backend_scan import find_aspects


PROGRESSION_BODY_IDS = [
    "SUN", "MOON", "MERCURY", "VENUS", "MARS",
    "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
]

LUNATION_PHASES = [
    (0, "新月"),
    (45, "蛾眉月"),
    (90, "上弦月"),
    (135, "盈凸月"),
    (180, "满月"),
    (225, "亏凸月"),
    (270, "下弦月"),
    (315, "残月"),
]


def _calc_progressed_dt(birth_utc: Any, reference_utc: Any) -> tuple[Any, float]:
    """Compute progressed datetime and age in years."""
    delta = reference_utc - birth_utc
    age_years = delta.total_seconds() / (365.2422 * 86400.0)
    offset_days = age_years
    progressed_dt = birth_utc + timedelta(days=offset_days)
    return progressed_dt, age_years


def _resolve_prog_bodies(node_mode: str, warnings: list[str]) -> list[Any]:
    body_ids = list(PROGRESSION_BODY_IDS)
    if node_mode == "true_node":
        body_ids += ["TRUE_NODE", "SOUTH_TRUE_NODE"]
    elif node_mode == "mean_node":
        body_ids += ["MEAN_NODE", "SOUTH_MEAN_NODE"]
    return resolve_bodies(body_ids, [], warnings)


def _calc_lunation(prog_sun_lon: float, prog_moon_lon: float) -> dict[str, Any]:
    sep = angular_separation(prog_sun_lon, prog_moon_lon)
    best_angle = 0
    best_name = "新月"
    best_dist = 999.0
    for angle, name in LUNATION_PHASES:
        dist = abs(sep - angle)
        if dist < best_dist:
            best_dist = dist
            best_angle = angle
            best_name = name
    return {
        "sun_moon_separation": round(sep, 6),
        "phase_angle": float(best_angle),
        "phase_name": best_name,
    }


def calculate_progressions(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    sidereal = set_zodiac_mode(request.get("zodiac", "tropical"))
    house_system = request.get("house_system", "whole_sign")
    node_mode = request.get("node_mode", "true_node")
    aspect_specs = request.get("aspects", [])

    birth = request["birth"]
    birth_dt = moment_to_local_datetime(birth["moment"])
    reference = request["reference"]
    reference_dt = moment_to_local_datetime(reference)

    birth_jd, birth_utc_str = moment_to_jd(birth["moment"])
    _, reference_utc_str = moment_to_jd(reference)
    latitude = float(birth["latitude"])
    longitude = float(birth["longitude"])

    import datetime as dt_mod
    try:
        birth_utc_dt = dt_mod.datetime.fromisoformat(birth_utc_str.replace("Z", "+00:00"))
        ref_utc_dt = dt_mod.datetime.fromisoformat(reference_utc_str.replace("Z", "+00:00"))
    except Exception:
        birth_utc_dt = birth_dt.astimezone(timezone.utc)
        ref_utc_dt = reference_dt.astimezone(timezone.utc)

    progressed_dt, age_years = _calc_progressed_dt(birth_utc_dt, ref_utc_dt)

    from astro_backend_core import jd_from_datetime
    prog_jd = jd_from_datetime(progressed_dt)

    section_errors: dict[str, str] = {}
    specs = _resolve_prog_bodies(node_mode, warnings)

    natal_positions = calculate_positions(birth_jd, specs, warnings, sidereal=sidereal)
    prog_positions = calculate_positions(prog_jd, specs, warnings, sidereal=sidereal)

    natal_cusps, natal_angles, _ = build_houses(
        birth_jd, latitude, longitude, house_system, sidereal, warnings,
    )
    prog_cusps, prog_angles, _ = build_houses(
        prog_jd, latitude, longitude, house_system, sidereal, warnings,
    )

    natal_positioned = [
        {**row, "house": house_for_longitude(row["longitude"], natal_cusps)}
        for row in natal_positions
    ]
    prog_positioned = [
        {**row, "house": house_for_longitude(row["longitude"], prog_cusps)}
        for row in prog_positions
    ]

    natal_angle_rows = [
        point_row("ASC", "ASC", natal_angles["ASC"], natal_cusps),
        point_row("MC", "MC", natal_angles["MC"], natal_cusps),
        point_row("DSC", "DSC", natal_angles["DSC"], natal_cusps),
        point_row("IC", "IC", natal_angles["IC"], natal_cusps),
    ]
    prog_angle_rows = [
        point_row("ASC", "ASC", prog_angles["ASC"], prog_cusps),
        point_row("MC", "MC", prog_angles["MC"], prog_cusps),
        point_row("DSC", "DSC", prog_angles["DSC"], prog_cusps),
        point_row("IC", "IC", prog_angles["IC"], prog_cusps),
    ]

    natal_house_rows = house_rows(natal_cusps)
    prog_house_rows = house_rows(prog_cusps)

    all_ephemerides = {row.get("_ephemeris", "Swiss Ephemeris") for row in natal_positions + prog_positions}

    prog_to_natal: list[dict[str, Any]] = []
    try:
        prog_to_natal = find_aspects(prog_positioned, natal_positioned, aspect_specs)
    except Exception as exc:
        warnings.append(f"Progressed→Natal 相位计算失败：{exc}")
        section_errors["progressed_to_natal"] = str(exc)

    prog_to_prog: list[dict[str, Any]] = []
    try:
        prog_to_prog = find_aspects(prog_positioned, prog_positioned, aspect_specs)
    except Exception as exc:
        warnings.append(f"Progressed→Progressed 相位计算失败：{exc}")
        section_errors["progressed_to_progressed"] = str(exc)

    # Lunation
    progressed_lunation: dict[str, Any] = {}
    try:
        prog_sun = next((r for r in prog_positioned if r["body_id"] == "SUN"), None)
        prog_moon = next((r for r in prog_positioned if r["body_id"] == "MOON"), None)
        if prog_sun and prog_moon:
            progressed_lunation = _calc_lunation(prog_sun["longitude"], prog_moon["longitude"])
    except Exception as exc:
        warnings.append(f"Progressed lunation 计算失败：{exc}")
        section_errors["progressed_lunation"] = str(exc)

    if not birth.get("hour", False) and not birth["moment"].get("minute", False):
        warnings.append("出生时间不详，progressed angles/houses 可能不准确。")

    return {
        "meta": {
            "method": "secondary_progression_day_for_year",
            "natal_utc": birth_utc_str,
            "progressed_utc": progressed_dt.isoformat() if hasattr(progressed_dt, 'isoformat') else str(progressed_dt),
            "ephemeris": ", ".join(sorted(all_ephemerides)) if all_ephemerides else "unknown",
        },
        "natal_planets": natal_positioned,
        "progressed_planets": prog_positioned,
        "natal_angles": natal_angle_rows,
        "progressed_angles": prog_angle_rows,
        "natal_houses": natal_house_rows,
        "progressed_houses": prog_house_rows,
        "progressed_to_natal_aspects": prog_to_natal,
        "progressed_to_progressed_aspects": prog_to_prog,
        "progressed_lunation": progressed_lunation if progressed_lunation else None,
        "warnings": warnings,
        "section_errors": section_errors if section_errors else None,
    }
