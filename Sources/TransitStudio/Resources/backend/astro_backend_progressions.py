from __future__ import annotations

from datetime import timedelta, timezone
from typing import Any

from astro_backend_core import (
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
from astro_backend_modern_points import finalize_point_set, resolve_point_set


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

ANGLE_NAMES = {
    "ASC": "ASC",
    "MC": "MC",
    "DSC": "DSC",
    "IC": "IC",
    "VERTEX": "Vertex",
    "ANTIVERTEX": "Antivertex",
    "EQUATORIAL_ASCENDANT": "East Point (Equatorial Ascendant)",
}


def _calc_progressed_dt(birth_utc: Any, reference_utc: Any) -> tuple[Any, float]:
    """Compute progressed datetime and age in years."""
    delta = reference_utc - birth_utc
    age_years = delta.total_seconds() / (365.2422 * 86400.0)
    offset_days = age_years
    progressed_dt = birth_utc + timedelta(days=offset_days)
    return progressed_dt, age_years


def _resolve_prog_bodies(point_set: dict[str, Any], warnings: list[str]) -> list[Any]:
    body_ids = [
        body_id
        for body_id in point_set["resolved_body_ids"]
        if not body_id.startswith("AST:")
    ]
    return resolve_bodies(body_ids, list(point_set["custom_asteroids"]), warnings)


def _angle_rows(
    angle_values: dict[str, float],
    angle_ids: list[str],
    cusps: list[float],
    warnings: list[str],
) -> tuple[list[dict[str, Any]], list[str]]:
    rows: list[dict[str, Any]] = []
    available: list[str] = []
    for angle_id in angle_ids:
        value = angle_values.get(angle_id)
        if value is None:
            message = f"轴点 {angle_id} 不可用，已从 effective_point_set 移除。"
            if message not in warnings:
                warnings.append(message)
            continue
        rows.append(point_row(angle_id, ANGLE_NAMES.get(angle_id, angle_id), value, cusps))
        available.append(angle_id)
    return rows, available


def _calc_lunation(prog_sun_lon: float, prog_moon_lon: float) -> dict[str, Any]:
    sep = angular_separation(prog_sun_lon, prog_moon_lon)
    directed_phase = norm360(prog_moon_lon - prog_sun_lon)
    best_angle = 0
    best_name = "新月"
    best_dist = 999.0
    for angle, name in LUNATION_PHASES:
        dist = abs((directed_phase - angle + 180.0) % 360.0 - 180.0)
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
    birth = request["birth"]
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    house_system = request.get("house_system") or birth.get("houseSystem", "whole_sign")
    sidereal = set_zodiac_mode(zodiac, warnings)
    node_mode = request.get("node_mode", "true_node")
    aspect_specs = request.get("aspects", [])
    point_set = resolve_point_set(
        request.get("point_set") if "point_set" in request else None,
        node_mode=node_mode,
    )
    selected_body_ids = set(point_set["resolved_body_ids"])

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
    specs = _resolve_prog_bodies(point_set, warnings)

    natal_positions = calculate_positions(birth_jd, specs, warnings, sidereal=sidereal)
    prog_positions = calculate_positions(prog_jd, specs, warnings, sidereal=sidereal)

    natal_cusps, natal_angles, _ = build_houses(
        birth_jd, latitude, longitude, house_system, sidereal, warnings,
    )
    prog_cusps, prog_angles, _ = build_houses(
        prog_jd, latitude, longitude, house_system, sidereal, warnings,
    )

    natal_positioned_all = [
        {**row, "house": house_for_longitude(row["longitude"], natal_cusps)}
        for row in natal_positions
    ]
    prog_positioned_all = [
        {**row, "house": house_for_longitude(row["longitude"], prog_cusps)}
        for row in prog_positions
    ]
    natal_positioned = [
        row for row in natal_positioned_all if row["body_id"] in selected_body_ids
    ]
    prog_positioned = [
        row for row in prog_positioned_all if row["body_id"] in selected_body_ids
    ]

    natal_angle_rows, natal_available_angles = _angle_rows(
        natal_angles, point_set["angle_ids"], natal_cusps, warnings,
    )
    prog_angle_rows, prog_available_angles = _angle_rows(
        prog_angles, point_set["angle_ids"], prog_cusps, warnings,
    )
    available_angle_ids = [
        angle_id
        for angle_id in point_set["angle_ids"]
        if angle_id in natal_available_angles and angle_id in prog_available_angles
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
        prog_to_prog = find_aspects(prog_positioned, prog_positioned, aspect_specs, skip_self_aspects=True)
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

    point_set = finalize_point_set(
        point_set,
        [row["body_id"] for row in natal_positions + prog_positions],
        available_angle_ids=available_angle_ids,
        warnings=warnings,
    )

    birth_moment = birth.get("moment", {})
    if "hour" not in birth_moment or "minute" not in birth_moment:
        warnings.append("出生时间不详，progressed angles/houses 可能不准确。")

    return {
        "meta": {
            "method": "secondary_progression_day_for_year",
            "natal_utc": birth_utc_str,
            "progressed_utc": progressed_dt.isoformat() if hasattr(progressed_dt, 'isoformat') else str(progressed_dt),
            "ephemeris": ", ".join(sorted(all_ephemerides)) if all_ephemerides else "unknown",
            "effective_point_set": point_set,
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
