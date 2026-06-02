from __future__ import annotations

from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    circular_midpoint,
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
from astro_backend_scan import find_aspects


COMPOSITE_BODY_IDS = [
    "SUN", "MOON", "MERCURY", "VENUS", "MARS",
    "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
]


def _positions_for(jd: float, specs: list[dict[str, Any]], sidereal: bool, warnings: list[str]) -> dict[str, dict[str, Any]]:
    rows = calculate_positions(jd, specs, warnings, sidereal=sidereal)
    return {row["body_id"]: row for row in rows}


def calculate_composite(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    from astro_backend_patterns import find_patterns

    sidereal = set_zodiac_mode(request.get("zodiac", "tropical"))
    house_system = request.get("house_system", "whole_sign")
    node_mode = request.get("node_mode", "true_node")
    aspect_specs = request.get("aspects", [])

    person_a = request["person_a"]
    person_b = request["person_b"]
    a_jd, _ = moment_to_jd(person_a["moment"])
    b_jd, _ = moment_to_jd(person_b["moment"])
    a_lat = float(person_a["latitude"])
    a_lon = float(person_a["longitude"])
    b_lat = float(person_b["latitude"])
    b_lon = float(person_b["longitude"])

    body_ids = list(COMPOSITE_BODY_IDS)
    if node_mode == "true_node":
        body_ids += ["TRUE_NODE", "SOUTH_TRUE_NODE"]
    elif node_mode == "mean_node":
        body_ids += ["MEAN_NODE", "SOUTH_MEAN_NODE"]

    specs = resolve_bodies(body_ids, [], warnings)

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
    asc_lat = (a_lat + b_lat) / 2.0
    asc_lon = (a_lon + b_lon) / 2.0
    a_cusps, a_angles, _ = build_houses(a_jd, a_lat, a_lon, house_system, sidereal, warnings)
    b_cusps, b_angles, _ = build_houses(b_jd, b_lat, b_lon, house_system, sidereal, warnings)
    comp_asc = circular_midpoint(a_angles["ASC"], b_angles["ASC"])
    comp_mc = circular_midpoint(a_angles["MC"], b_angles["MC"])

    # Rebuild houses from composite ASC/MC
    if house_system == "whole_sign":
        first_cusp = (int(comp_asc // 30)) * 30.0
        comp_cusps = [norm360(first_cusp + 30.0 * i) for i in range(12)]
    else:
        try:
            raw_cusps, _ = build_houses(a_jd, asc_lat, asc_lon, house_system, sidereal, warnings)
            mc_delta = norm360(comp_mc - a_angles["MC"])
            comp_cusps = [norm360(c + mc_delta) for c in raw_cusps]
        except Exception:
            comp_cusps = [norm360(comp_asc + 30.0 * i) for i in range(12)]

    comp_angles = {
        "ASC": comp_asc,
        "MC": comp_mc,
        "DSC": norm360(comp_asc + 180.0),
        "IC": norm360(comp_mc + 180.0),
    }

    comp_planet_rows: list[dict[str, Any]] = []
    all_ephemerides: set[str] = set()
    for body_id in body_ids:
        if body_id not in composite_lons:
            continue
        lon = composite_lons[body_id]
        spec = BODY_REGISTRY.get(body_id)
        if spec is None:
            continue
        sign, degree_text = "", ""
        try:
            from astro_backend_core import format_longitude
            sign, degree_text = format_longitude(lon)
        except Exception:
            pass
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

    comp_angle_rows = [
        point_row("ASC", "ASC", comp_angles["ASC"], comp_cusps),
        point_row("MC", "MC", comp_angles["MC"], comp_cusps),
        point_row("DSC", "DSC", comp_angles["DSC"], comp_cusps),
        point_row("IC", "IC", comp_angles["IC"], comp_cusps),
    ]
    comp_house_rows = house_rows(comp_cusps)

    section_errors: dict[str, str] = {}
    aspects: list[dict[str, Any]] = []
    try:
        aspects = find_aspects(comp_planet_rows, comp_planet_rows, aspect_specs)
    except Exception as exc:
        warnings.append(f"Composite 相位计算失败：{exc}")
        section_errors["aspects"] = str(exc)

    body_lons_for_patterns = {row["body_id"]: row["longitude"] for row in comp_planet_rows}
    house_map_for_patterns = {row["body_id"]: row["house"] for row in comp_planet_rows if "house" in row}
    patterns: list[dict[str, Any]] = []
    try:
        patterns = find_patterns(body_lons_for_patterns, aspects, house_map_for_patterns)
    except Exception as exc:
        warnings.append(f"Composite 图形识别失败：{exc}")
        section_errors["patterns"] = str(exc)

    meta_utc = ""
    try:
        mid_jd = (a_jd + b_jd) / 2.0
        from astro_backend_core import swe
        meta_utc = swe.revjul(mid_jd - 0.5)
    except Exception:
        pass

    return {
        "meta": {
            "method": "composite_midpoint",
            "person_a_utc": "",
            "person_b_utc": "",
            "ephemeris": ", ".join(sorted(all_ephemerides)) if all_ephemerides else "unknown",
        },
        "angles": comp_angle_rows,
        "houses": comp_house_rows,
        "planets": comp_planet_rows,
        "aspects": aspects,
        "patterns": patterns,
        "warnings": warnings,
        "section_errors": section_errors if section_errors else None,
    }
