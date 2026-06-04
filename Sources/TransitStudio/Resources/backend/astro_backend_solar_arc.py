from __future__ import annotations

from datetime import timedelta, timezone
from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    angular_separation,
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


SOLAR_ARC_BODY_IDS = [
    "SUN", "MOON", "MERCURY", "VENUS", "MARS",
    "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
]


def calculate_solar_arc(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    from astro_backend_patterns import find_patterns

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

    # Progressed date to get progressed Sun
    import datetime as dt_mod
    try:
        birth_utc_dt = dt_mod.datetime.fromisoformat(birth_utc_str.replace("Z", "+00:00"))
        ref_utc_dt = dt_mod.datetime.fromisoformat(reference_utc_str.replace("Z", "+00:00"))
    except Exception:
        birth_utc_dt = birth_dt.astimezone(timezone.utc)
        ref_utc_dt = reference_dt.astimezone(timezone.utc)

    age_years = (ref_utc_dt - birth_utc_dt).total_seconds() / (365.2422 * 86400.0)
    progressed_dt = birth_utc_dt + timedelta(days=age_years)

    from astro_backend_core import jd_from_datetime
    prog_jd = jd_from_datetime(progressed_dt)

    body_ids = list(SOLAR_ARC_BODY_IDS)
    if node_mode == "true_node":
        body_ids += ["TRUE_NODE", "SOUTH_TRUE_NODE"]
    elif node_mode == "mean_node":
        body_ids += ["MEAN_NODE", "SOUTH_MEAN_NODE"]

    specs = resolve_bodies(body_ids, [], warnings)
    natal_positions = calculate_positions(birth_jd, specs, warnings, sidereal=sidereal)
    prog_positions = calculate_positions(prog_jd, specs, warnings, sidereal=sidereal)

    natal_by_id = {row["body_id"]: row for row in natal_positions}
    prog_by_id = {row["body_id"]: row for row in prog_positions}

    # Solar arc = progressed_sun - natal_sun
    natal_sun_lon = natal_by_id.get("SUN", {}).get("longitude", 0.0)
    prog_sun_lon = prog_by_id.get("SUN", {}).get("longitude", 0.0)
    arc = norm360(prog_sun_lon - natal_sun_lon)

    # Build natal chart
    natal_cusps, natal_angles, _ = build_houses(
        birth_jd, latitude, longitude, house_system, sidereal, warnings,
    )
    natal_positioned = [
        {**row, "house": house_for_longitude(row["longitude"], natal_cusps)}
        for row in natal_positions
    ]

    # Solar arc positions = natal lon + arc
    sa_positioned: list[dict[str, Any]] = []
    for row in natal_positions:
        sa_lon = norm360(row["longitude"] + arc)
        sign, degree_text = "", ""
        try:
            from astro_backend_core import format_longitude
            sign, degree_text = format_longitude(sa_lon)
        except Exception:
            pass
        h = house_for_longitude(sa_lon, natal_cusps)
        sa_positioned.append({
            "body_id": row["body_id"],
            "name": row["name"],
            "longitude": sa_lon,
            "latitude": row.get("latitude", 0.0),
            "speed": row.get("speed", 0.0),
            "sign": sign,
            "degree_text": degree_text,
            "house": h,
        })

    # Solar arc angles
    sa_asc = norm360(natal_angles["ASC"] + arc)
    sa_mc = norm360(natal_angles["MC"] + arc)
    sa_dsc = norm360(sa_asc + 180.0)
    sa_ic = norm360(sa_mc + 180.0)

    sa_angles = {"ASC": sa_asc, "MC": sa_mc, "DSC": sa_dsc, "IC": sa_ic}
    sa_angle_rows = [
        point_row("ASC", "ASC", sa_asc, natal_cusps),
        point_row("MC", "MC", sa_mc, natal_cusps),
        point_row("DSC", "DSC", sa_dsc, natal_cusps),
        point_row("IC", "IC", sa_ic, natal_cusps),
    ]

    # Solar arc houses: natal cusps + arc
    sa_cusps = [norm360(c + arc) for c in natal_cusps]
    sa_house_rows = house_rows(sa_cusps)

    all_ephemerides = {row.get("_ephemeris", "Swiss Ephemeris") for row in natal_positions + prog_positions}

    section_errors: dict[str, str] = {}
    sa_to_natal: list[dict[str, Any]] = []
    try:
        sa_to_natal = find_aspects(sa_positioned, natal_positioned, aspect_specs)
    except Exception as exc:
        warnings.append(f"Solar Arc→Natal 相位计算失败：{exc}")
        section_errors["solar_arc_to_natal"] = str(exc)

    body_lons = {row["body_id"]: row["longitude"] for row in sa_positioned}
    aspects_internal: list[dict[str, Any]] = []
    try:
        aspects_internal = find_aspects(sa_positioned, sa_positioned, aspect_specs, skip_self_aspects=True)
    except Exception:
        aspects_internal = []
    house_map = {row["body_id"]: row.get("house", 1) for row in sa_positioned}
    patterns: list[dict[str, Any]] = []
    patterns_enabled = request.get("patterns_enabled", False)
    if patterns_enabled:
        try:
            patterns = find_patterns(body_lons, aspects_internal, house_map)
        except Exception as exc:
            warnings.append(f"Solar Arc 图形识别失败：{exc}")
            section_errors["patterns"] = str(exc)

    return {
        "meta": {
            "method": "true_solar_arc",
            "natal_utc": birth_utc_str,
            "progressed_utc": progressed_dt.isoformat() if hasattr(progressed_dt, 'isoformat') else str(progressed_dt),
            "ephemeris": ", ".join(sorted(all_ephemerides)) if all_ephemerides else "unknown",
        },
        "natal_planets": [row for row in natal_positioned if row["body_id"] in SOLAR_ARC_BODY_IDS],
        "solar_arc_planets": [row for row in sa_positioned if row["body_id"] in SOLAR_ARC_BODY_IDS],
        "solar_arc_angles": sa_angle_rows,
        "solar_arc_houses": sa_house_rows,
        "solar_arc_to_natal_aspects": sa_to_natal,
        "arc_value": round(arc, 6),
        "patterns": patterns,
        "warnings": warnings,
        "section_errors": section_errors if section_errors else None,
    }
