from __future__ import annotations

from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    angular_separation,
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


SYNASTRY_MAIN_BODIES = [
    "SUN", "MOON", "MERCURY", "VENUS", "MARS",
    "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
]

SYNASTRY_ANGLE_IDS = ["ASC", "MC", "DSC", "IC"]


def _resolve_modern_bodies(
    node_mode: str,
    warnings: list[str],
) -> list[dict[str, Any]]:
    body_ids = list(SYNASTRY_MAIN_BODIES)
    if node_mode == "true_node":
        body_ids += ["TRUE_NODE", "SOUTH_TRUE_NODE"]
    elif node_mode == "mean_node":
        body_ids += ["MEAN_NODE", "SOUTH_MEAN_NODE"]
    return resolve_bodies(body_ids, [], warnings)


def _calculate_full_chart(
    jd: float,
    latitude: float,
    longitude: float,
    house_system: str,
    sidereal: bool,
    node_mode: str,
    warnings: list[str],
) -> dict[str, Any]:
    specs = _resolve_modern_bodies(node_mode, warnings)
    positions = calculate_positions(jd, specs, warnings, sidereal=sidereal)
    cusps, angle_values, system_label = build_houses(
        jd, latitude, longitude, house_system, sidereal, warnings,
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
    houses = house_rows(cusps)
    ephemerides = {row.get("_ephemeris", "Swiss Ephemeris") for row in positions}
    return {
        "positions": positioned,
        "angles": angles,
        "houses": houses,
        "cusps": cusps,
        "ephemerides": ephemerides,
    }


def _cross_house_placements(
    positions: list[dict[str, Any]],
    cusps: list[float],
) -> list[dict[str, Any]]:
    placements: list[dict[str, Any]] = []
    for row in positions:
        h = house_for_longitude(row["longitude"], cusps)
        placements.append({
            "body_id": row["body_id"],
            "body_name": row["name"],
            "house": h,
        })
    placements.sort(key=lambda p: (p["house"], p["body_id"]))
    return placements


def calculate_synastry(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
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

    section_errors: dict[str, str] = {}

    chart_a = _calculate_full_chart(a_jd, a_lat, a_lon, house_system, sidereal, node_mode, warnings)
    chart_b = _calculate_full_chart(b_jd, b_lat, b_lon, house_system, sidereal, node_mode, warnings)

    cross_aspects: list[dict[str, Any]] = []
    try:
        cross_aspects = find_aspects(chart_a["positions"], chart_b["positions"], aspect_specs)
    except Exception as exc:
        warnings.append(f"跨盘相位计算失败：{exc}")
        section_errors["cross_aspects"] = str(exc)

    a_in_b = _cross_house_placements(chart_a["positions"], chart_b["cusps"])
    b_in_a = _cross_house_placements(chart_b["positions"], chart_a["cusps"])

    all_ephemerides = chart_a["ephemerides"] | chart_b["ephemerides"]

    return {
        "meta": {
            "method": "synastry_cross_aspect",
            "person_a_utc": a_utc,
            "person_b_utc": b_utc,
            "ephemeris": ", ".join(sorted(all_ephemerides)) if all_ephemerides else "unknown",
        },
        "person_a_planets": chart_a["positions"],
        "person_b_planets": chart_b["positions"],
        "person_a_angles": chart_a["angles"],
        "person_b_angles": chart_b["angles"],
        "person_a_houses": chart_a["houses"],
        "person_b_houses": chart_b["houses"],
        "cross_aspects": cross_aspects,
        "a_in_b_houses": a_in_b,
        "b_in_a_houses": b_in_a,
        "patterns": [],
        "warnings": warnings,
        "section_errors": section_errors if section_errors else None,
    }
