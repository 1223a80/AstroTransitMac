from __future__ import annotations

from datetime import timedelta, timezone
from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
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


DAVISON_BODY_IDS = [
    "SUN", "MOON", "MERCURY", "VENUS", "MARS",
    "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
]


def _julian_day_to_datetime(jd: float) -> Any:
    from astro_backend_core import swe
    year, month, day, hour_f = swe.revjul(jd)
    hour = int(hour_f)
    minute = int((hour_f - hour) * 60)
    return year, month, day, hour, minute


def calculate_davison(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    from astro_backend_patterns import find_patterns

    sidereal = set_zodiac_mode(request.get("zodiac", "tropical"))
    house_system = request.get("house_system", "whole_sign")
    node_mode = request.get("node_mode", "true_node")
    aspect_specs = request.get("aspects", [])

    person_a = request["person_a"]
    person_b = request["person_b"]
    a_dt = moment_to_local_datetime(person_a["moment"])
    b_dt = moment_to_local_datetime(person_b["moment"])

    a_lat = float(person_a["latitude"])
    a_lon = float(person_a["longitude"])
    b_lat = float(person_b["latitude"])
    b_lon = float(person_b["longitude"])

    mid_dt = a_dt + (b_dt - a_dt) / 2
    mid_lat = (a_lat + b_lat) / 2.0
    mid_lon = (a_lon + b_lon) / 2.0

    mid_utc = mid_dt.astimezone(timezone.utc)
    try:
        from astro_backend_core import jd_from_datetime
        mid_jd = jd_from_datetime(mid_dt)
    except Exception:
        mid_jd = 0.0

    body_ids = list(DAVISON_BODY_IDS)
    if node_mode == "true_node":
        body_ids += ["TRUE_NODE", "SOUTH_TRUE_NODE"]
    elif node_mode == "mean_node":
        body_ids += ["MEAN_NODE", "SOUTH_MEAN_NODE"]

    specs = resolve_bodies(body_ids, [], warnings)
    positions = calculate_positions(mid_jd, specs, warnings, sidereal=sidereal)
    cusps, angle_values, _ = build_houses(
        mid_jd, mid_lat, mid_lon, house_system, sidereal, warnings,
    )

    positioned = [
        {**row, "house": house_for_longitude(row["longitude"], cusps)}
        for row in positions
    ]
    angles = [
        point_row("ASC", "ASC", angle_values["ASC"], cusps),
        point_row("MC", "MC", angle_values["MC"], cusps),
        point_row("DSC", "DSC", angle_values["DSC"], cusps),
        point_row("IC", "IC", angle_values["IC"], cusps),
    ]
    house_rows_list = house_rows(cusps)

    all_ephemerides = {row.get("_ephemeris", "Swiss Ephemeris") for row in positions}

    section_errors: dict[str, str] = {}
    aspects: list[dict[str, Any]] = []
    try:
        aspects = find_aspects(positioned, positioned, aspect_specs, skip_self_aspects=True)
    except Exception as exc:
        warnings.append(f"Davison 相位计算失败：{exc}")
        section_errors["aspects"] = str(exc)

    body_lons = {row["body_id"]: row["longitude"] for row in positioned}
    house_map = {row["body_id"]: row.get("house", 1) for row in positioned}
    patterns: list[dict[str, Any]] = []
    try:
        patterns = find_patterns(body_lons, aspects, house_map)
    except Exception as exc:
        warnings.append(f"Davison 图形识别失败：{exc}")
        section_errors["patterns"] = str(exc)

    return {
        "meta": {
            "method": "davison_midtime_midspace",
            "person_a_utc": a_dt.astimezone(timezone.utc).isoformat() if a_dt.tzinfo else "",
            "person_b_utc": b_dt.astimezone(timezone.utc).isoformat() if b_dt.tzinfo else "",
            "ephemeris": ", ".join(sorted(all_ephemerides)) if all_ephemerides else "unknown",
        },
        "angles": angles,
        "houses": house_rows_list,
        "planets": positioned,
        "aspects": aspects,
        "patterns": patterns,
        "warnings": warnings,
        "section_errors": section_errors if section_errors else None,
    }
