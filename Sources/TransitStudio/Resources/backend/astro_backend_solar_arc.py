from __future__ import annotations

from datetime import timedelta, timezone
from typing import Any

from astro_backend_core import (
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


ANGLE_NAMES = {
    "ASC": "ASC",
    "MC": "MC",
    "DSC": "DSC",
    "IC": "IC",
    "VERTEX": "Vertex",
    "ANTIVERTEX": "Antivertex",
    "EQUATORIAL_ASCENDANT": "East Point (Equatorial Ascendant)",
}


def true_solar_arc_value(natal_sun_longitude: float, progressed_sun_longitude: float) -> float:
    """Return the direct true-solar-arc value used by static and timing modes."""
    return norm360(progressed_sun_longitude - natal_sun_longitude)


def _resolve_solar_arc_specs(
    point_set: dict[str, Any],
    warnings: list[str],
) -> list[Any]:
    # The Sun is the Solar Arc anchor even when the caller intentionally does
    # not request it as an output point.
    body_ids = list(point_set["resolved_body_ids"])
    if "SUN" not in body_ids:
        body_ids.insert(0, "SUN")
    return resolve_bodies(
        [body_id for body_id in body_ids if not body_id.startswith("AST:")],
        list(point_set["custom_asteroids"]),
        warnings,
    )


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


def calculate_solar_arc(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    from astro_backend_patterns import find_patterns

    birth = request["birth"]
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    house_system = request.get("house_system") or birth.get("houseSystem", "whole_sign")
    sidereal = set_zodiac_mode(zodiac, warnings)
    node_mode = request.get("node_mode", "true_node")
    aspect_specs = request.get("aspects", [])
    # Arc key: true_sun (default) | naibod_mean | custom_key
    arc_method = str(request.get("solar_arc_method") or request.get("arc_method") or "true_sun")
    if arc_method not in {"true_sun", "naibod_mean", "custom_key"}:
        warnings.append(f"Unknown solar_arc_method={arc_method}; using true_sun")
        arc_method = "true_sun"
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

    specs = _resolve_solar_arc_specs(point_set, warnings)
    natal_positions = calculate_positions(birth_jd, specs, warnings, sidereal=sidereal)
    prog_positions = calculate_positions(prog_jd, specs, warnings, sidereal=sidereal)

    natal_by_id = {row["body_id"]: row for row in natal_positions}
    prog_by_id = {row["body_id"]: row for row in prog_positions}

    # Solar arc key (never mix keys silently in one result)
    natal_sun_lon = natal_by_id.get("SUN", {}).get("longitude", 0.0)
    prog_sun_lon = prog_by_id.get("SUN", {}).get("longitude", 0.0)
    if arc_method == "true_sun":
        arc = true_solar_arc_value(natal_sun_lon, prog_sun_lon)
    elif arc_method == "naibod_mean":
        arc = 0.98564733 * age_years
    else:
        custom_rate = float(request.get("solar_arc_rate_deg_per_year") or 1.0)
        arc = custom_rate * age_years
    # Solar arc growth rate (deg/year) — not natal planetary speed.
    solar_arc_rate_deg_per_year = arc / age_years if age_years > 1e-9 else 0.0

    # Build natal chart
    natal_cusps, natal_angles, house_label = build_houses(
        birth_jd, latitude, longitude, house_system, sidereal, warnings,
    )
    natal_positioned_all = [
        {**row, "house": house_for_longitude(row["longitude"], natal_cusps)}
        for row in natal_positions
    ]
    natal_positioned = [
        row for row in natal_positioned_all if row["body_id"] in selected_body_ids
    ]

    # Directed house cusps (same arc on all cusps) — explicit algorithm.
    sa_cusps = [norm360(c + arc) for c in natal_cusps]
    sa_house_rows = house_rows(sa_cusps)

    # Solar arc positions = natal lon + arc
    sa_positioned_all: list[dict[str, Any]] = []
    for row in natal_positioned_all:
        sa_lon = norm360(row["longitude"] + arc)
        sign, degree_text = "", ""
        try:
            from astro_backend_core import format_longitude
            sign, degree_text = format_longitude(sa_lon)
        except Exception:
            pass
        sa_in_natal_house = house_for_longitude(sa_lon, natal_cusps)
        sa_in_directed_house = house_for_longitude(sa_lon, sa_cusps)
        sa_positioned_all.append({
            "body_id": row["body_id"],
            "name": row["name"],
            "longitude": sa_lon,
            "latitude": row.get("latitude", 0.0),
            # Do not present natal speed as SA motion.
            "speed": None,
            "natal_speed_metadata": row.get("speed", 0.0),
            "solar_arc_rate_deg_per_year": round(solar_arc_rate_deg_per_year, 6),
            "sign": sign,
            "degree_text": degree_text,
            "natal_house_original": row.get("house"),
            "sa_point_in_natal_house": sa_in_natal_house,
            "sa_point_in_directed_house_system": sa_in_directed_house,
            "house": sa_in_natal_house,  # default most useful: SA point in natal house
            "house_note": "default house = sa_point_in_natal_house; directed cusps also provided",
        })
    sa_positioned = [
        row for row in sa_positioned_all if row["body_id"] in selected_body_ids
    ]

    # Solar arc angles
    sa_asc = norm360(natal_angles["ASC"] + arc)
    sa_mc = norm360(natal_angles["MC"] + arc)
    sa_dsc = norm360(sa_asc + 180.0)
    sa_ic = norm360(sa_mc + 180.0)

    sa_angles = {"ASC": sa_asc, "MC": sa_mc, "DSC": sa_dsc, "IC": sa_ic}
    for angle_id in point_set["angle_ids"]:
        if angle_id in sa_angles:
            continue
        natal_value = natal_angles.get(angle_id)
        if natal_value is not None:
            sa_angles[angle_id] = norm360(natal_value + arc)
    sa_angle_rows, available_angle_ids = _angle_rows(
        sa_angles, point_set["angle_ids"], sa_cusps, warnings,
    )

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
    except Exception as exc:
        warnings.append(f"Solar Arc 内部相位计算失败：{exc}")
        section_errors["solar_arc_internal"] = str(exc)
        aspects_internal = []
    house_map = {row["body_id"]: row.get("house", 1) for row in sa_positioned}
    # SA-internal patterns are natal patterns rotated by one arc — not new time structures.
    # Default: do not emit them as current-time signals. Optional: natal_pattern_rotated.
    patterns: list[dict[str, Any]] = []
    patterns_mode = str(request.get("sa_internal_patterns") or "off")
    # Legacy: patterns_enabled=true maps to natal_pattern_rotated (not "new structure").
    if request.get("patterns_enabled", False) and patterns_mode == "off":
        patterns_mode = "natal_pattern_rotated"
    if patterns_mode == "natal_pattern_rotated":
        try:
            raw = find_patterns(body_lons, aspects_internal, house_map, warnings=warnings)
            for p in raw or []:
                item = dict(p) if isinstance(p, dict) else {"pattern": p}
                item["kind"] = "natal_pattern_rotated"
                item["note"] = "SA points share one arc; internal figures equal natal figures rotated"
                patterns.append(item)
        except Exception as exc:
            warnings.append(f"Solar Arc 图形识别失败：{exc}")
            section_errors["patterns"] = str(exc)
    elif patterns_mode not in {"off", "natal_pattern_rotated"}:
        warnings.append(f"Unknown sa_internal_patterns={patterns_mode}; using off")

    # Mixed SA→natal activation clusters: group aspects that share an SA body hitting a tight natal structure.
    activation_clusters: list[dict[str, Any]] = []
    by_sa: dict[str, list[dict[str, Any]]] = {}
    for asp in sa_to_natal:
        key = str(asp.get("transit_body_id") or asp.get("body_a_id") or asp.get("left_body_id") or "")
        if key:
            by_sa.setdefault(key, []).append(asp)
    for sa_body, group in by_sa.items():
        if len(group) >= 2:
            activation_clusters.append({
                "sa_body_id": sa_body,
                "hit_count": len(group),
                "targets": [
                    asp.get("target_body_id") or asp.get("body_b_id") or asp.get("right_body_id")
                    for asp in group
                ],
                "note": "Single SA point activating multiple natal points; treat as one cluster when natal structure is tight",
            })

    point_set = finalize_point_set(
        point_set,
        [row["body_id"] for row in natal_positions + prog_positions],
        available_angle_ids=available_angle_ids,
        warnings=warnings,
    )

    return {
        "meta": {
            "method": arc_method,
            "method_version": "solar_arc_v2",
            "arc_method": arc_method,
            "natal_utc": birth_utc_str,
            "progressed_utc": progressed_dt.isoformat() if hasattr(progressed_dt, 'isoformat') else str(progressed_dt),
            "ephemeris": ", ".join(sorted(all_ephemerides)) if all_ephemerides else "unknown",
            "house_system_requested": house_system,
            "house_system_effective": house_label,
            "zodiac": zodiac,
            "effective_point_set": point_set,
            "solar_arc_rate_deg_per_year": round(solar_arc_rate_deg_per_year, 6),
            "angles_use_uniform_solar_arc": True,
            "cusps_use_uniform_solar_arc": True,
        },
        "natal_planets": natal_positioned,
        "solar_arc_planets": sa_positioned,
        "solar_arc_angles": sa_angle_rows,
        "solar_arc_houses": sa_house_rows,
        "solar_arc_to_natal_aspects": sa_to_natal,
        "activation_clusters": activation_clusters,
        "arc_value": round(arc, 6),
        "patterns": patterns,
        "patterns_mode": patterns_mode,
        "aspects_internal_sa": aspects_internal,
        "aspects_internal_note": "SA-internal aspects equal natal aspects (relative geometry preserved); not new timed structures",
        "warnings": warnings,
        "section_errors": section_errors if section_errors else None,
        "calculation_assumptions": [
            f"Arc method={arc_method}; keys never mixed in one result.",
            "Default house field = SA point in natal Placidus/requested house system.",
            "SA angles and cusps use the same uniform solar arc.",
            "Natal planetary speed is metadata only; SA motion is the solar arc rate.",
            "SA-internal patterns default off; optional natal_pattern_rotated labeling.",
        ],
    }
