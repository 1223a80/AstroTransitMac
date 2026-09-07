from __future__ import annotations

from typing import Any

from astro_backend_core import (
    circular_midpoint,
    format_longitude,
    geographic_longitude_midpoint,
    moment_to_jd,
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
from astro_backend_modern_points import resolve_point_set
from astro_backend_scan import find_aspects


COMPOSITE_BODY_IDS = [
    "SUN", "MOON", "MERCURY", "VENUS", "MARS",
    "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
]


def _positions_for(jd: float, specs: list[Any], sidereal: bool, warnings: list[str]) -> dict[str, dict[str, Any]]:
    rows = calculate_positions(jd, specs, warnings, sidereal=sidereal)
    return {row["body_id"]: row for row in rows}


def _requested_angle_values(
    angle_ids: list[str],
    left_angles: dict[str, float],
    right_angles: dict[str, float],
) -> dict[str, float]:
    """Midpoint only the requested axes that both source charts provide."""
    values: dict[str, float] = {}
    for angle_id in angle_ids:
        left_value = left_angles.get(angle_id)
        right_value = right_angles.get(angle_id)
        if left_value is None or right_value is None:
            continue
        values[angle_id] = circular_midpoint(left_value, right_value)
    return values


def _angle_rows(
    angle_ids: list[str],
    angle_values: dict[str, float],
    cusps: list[float],
) -> list[dict[str, Any]]:
    return [
        point_row(angle_id, angle_id, angle_values[angle_id], cusps)
        for angle_id in angle_ids
        if angle_id in angle_values
    ]


def calculate_composite(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    from astro_backend_patterns import find_patterns

    sidereal = set_zodiac_mode(request.get("zodiac", "tropical"), warnings)
    house_system = request.get("house_system", "whole_sign")
    node_mode = request.get("node_mode", "true_node")
    aspect_specs = request.get("aspects", [])

    person_a = request["person_a"]
    person_b = request["person_b"]
    a_jd, a_utc = moment_to_jd(person_a["moment"])
    b_jd, b_utc = moment_to_jd(person_b["moment"])
    a_lat = float(person_a["latitude"])
    a_lon = float(person_a["longitude"])
    b_lat = float(person_b["latitude"])
    b_lon = float(person_b["longitude"])

    effective_point_set = resolve_point_set(
        request.get("point_set"),
        default_body_ids=COMPOSITE_BODY_IDS,
        default_include_nodes=True,
        default_angle_ids=("ASC", "MC", "DSC", "IC"),
        node_mode=node_mode,
    )
    body_ids = list(effective_point_set["resolved_body_ids"])
    specs = resolve_bodies(
        body_ids,
        list(effective_point_set["custom_asteroids"]),
        warnings,
    )
    specs_by_id = {spec.body_id: spec for spec in specs}

    a_positions = _positions_for(a_jd, specs, sidereal, warnings)
    b_positions = _positions_for(b_jd, specs, sidereal, warnings)

    composite_lons: dict[str, float] = {}
    for body_id in body_ids:
        if body_id in a_positions and body_id in b_positions:
            mid = circular_midpoint(
                a_positions[body_id]["longitude"],
                b_positions[body_id]["longitude"],
            )
            composite_lons[body_id] = mid

    # ASC/MC midpoints
    comp_jd = (a_jd + b_jd) / 2.0
    asc_lat = (a_lat + b_lat) / 2.0
    asc_lon = geographic_longitude_midpoint(a_lon, b_lon)
    a_cusps, a_angles, _ = build_houses(a_jd, a_lat, a_lon, house_system, sidereal, warnings)
    b_cusps, b_angles, _ = build_houses(b_jd, b_lat, b_lon, house_system, sidereal, warnings)

    # ASC/MC are needed internally for the existing composite house rebuild,
    # even when the caller did not request those angle rows.
    comp_asc = circular_midpoint(a_angles["ASC"], b_angles["ASC"])
    comp_mc = circular_midpoint(a_angles["MC"], b_angles["MC"])

    # Rebuild houses from composite ASC/MC
    if house_system == "whole_sign":
        first_cusp = (int(comp_asc // 30)) * 30.0
        comp_cusps = [norm360(first_cusp + 30.0 * i) for i in range(12)]
    else:
        try:
            raw_cusps, raw_angles, _ = build_houses(comp_jd, asc_lat, asc_lon, house_system, sidereal, warnings)
            mc_delta = norm360(comp_mc - raw_angles["MC"])
            comp_cusps = [norm360(c + mc_delta) for c in raw_cusps]
        except Exception as exc:
            warnings.append(
                f"Composite 宫位重建失败，已回退等宫：{exc}"
            )
            comp_cusps = [norm360(comp_asc + 30.0 * i) for i in range(12)]

    comp_angles = _requested_angle_values(
        list(effective_point_set["angle_ids"]),
        a_angles,
        b_angles,
    )

    comp_planet_rows: list[dict[str, Any]] = []
    all_ephemerides: set[str] = set()
    for body_id in body_ids:
        if body_id not in composite_lons:
            continue
        lon = composite_lons[body_id]
        spec = specs_by_id.get(body_id)
        if spec is None:
            continue
        sign, degree_text = "", ""
        try:
            sign, degree_text = format_longitude(lon)
        except Exception as exc:
            warnings.append(f"composite 计算局部失败: {exc}")
        h = house_for_longitude(lon, comp_cusps)
        a_src = a_positions.get(body_id, {})
        b_src = b_positions.get(body_id, {})
        comp_planet_rows.append({
            "body_id": body_id,
            "name": spec.name,
            "longitude": lon,
            "latitude": (a_src.get("latitude", 0.0) + b_src.get("latitude", 0.0)) / 2.0,
            "speed": (a_src.get("speed", 0.0) + b_src.get("speed", 0.0)) / 2.0,
            "sign": sign,
            "degree_text": degree_text,
            "house": h,
        })
        eph = a_src.get("_ephemeris", "") or b_src.get("_ephemeris", "")
        if eph:
            all_ephemerides.add(eph)

    requested_angle_ids = list(effective_point_set["angle_ids"])
    effective_point_set["angle_ids"] = [
        angle_id for angle_id in requested_angle_ids if angle_id in comp_angles
    ]
    comp_angle_rows = _angle_rows(
        effective_point_set["angle_ids"],
        comp_angles,
        comp_cusps,
    )
    comp_house_rows = house_rows(comp_cusps)

    section_errors: dict[str, str] = {}
    aspects: list[dict[str, Any]] = []
    try:
        aspects = find_aspects(comp_planet_rows, comp_planet_rows, aspect_specs, skip_self_aspects=True)
    except Exception as exc:
        warnings.append(f"Composite 相位计算失败：{exc}")
        section_errors["aspects"] = str(exc)

    body_lons_for_patterns = {row["body_id"]: row["longitude"] for row in comp_planet_rows}
    house_map_for_patterns = {row["body_id"]: row["house"] for row in comp_planet_rows if "house" in row}
    patterns: list[dict[str, Any]] = []
    try:
        patterns = find_patterns(body_lons_for_patterns, aspects, house_map_for_patterns, warnings=warnings)
    except Exception as exc:
        warnings.append(f"Composite 图形识别失败：{exc}")
        section_errors["patterns"] = str(exc)

    return {
        "meta": {
            "method": "composite_midpoint",
            "person_a_utc": a_utc,
            "person_b_utc": b_utc,
            "ephemeris": ", ".join(sorted(all_ephemerides)) if all_ephemerides else "unknown",
            "effective_point_set": effective_point_set,
        },
        "angles": comp_angle_rows,
        "houses": comp_house_rows,
        "planets": comp_planet_rows,
        "aspects": aspects,
        "patterns": patterns,
        "warnings": warnings,
        "section_errors": section_errors if section_errors else None,
    }
