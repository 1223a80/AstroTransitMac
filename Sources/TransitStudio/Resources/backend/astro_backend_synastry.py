from __future__ import annotations

import math
from typing import Any

from astro_backend_core import (
    find_declination_aspects,
    moment_to_jd,
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
from astro_backend_modern_points import finalize_point_set, resolve_point_set
from astro_backend_scan import find_aspects


SYNASTRY_MAIN_BODIES = [
    "SUN", "MOON", "MERCURY", "VENUS", "MARS",
    "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
]

SYNASTRY_ANGLE_IDS = ["ASC", "MC", "DSC", "IC"]
SYNASTRY_ANGLE_NAMES = {
    "ASC": "ASC",
    "MC": "MC",
    "DSC": "DSC",
    "IC": "IC",
    "VERTEX": "Vertex",
    "ANTIVERTEX": "Antivertex",
    "EQUATORIAL_ASCENDANT": "East Point (Equatorial Ascendant)",
}


def _resolve_point_specs(
    point_set: dict[str, Any],
    warnings: list[str],
) -> list[Any]:
    """Resolve one effective body list for both sides of the relationship."""
    body_ids = [
        body_id
        for body_id in point_set["resolved_body_ids"]
        if not body_id.startswith("AST:")
    ]
    return resolve_bodies(body_ids, point_set["custom_asteroids"], warnings)


def _angle_rows(
    angle_ids: list[str],
    angle_values: dict[str, float],
    cusps: list[float],
) -> list[dict[str, Any]]:
    """Render only requested and available house angles."""
    rows: list[dict[str, Any]] = []
    for angle_id in angle_ids:
        value = angle_values.get(angle_id)
        if value is None:
            continue
        rows.append(
            point_row(
                angle_id,
                SYNASTRY_ANGLE_NAMES.get(angle_id, angle_id),
                value,
                cusps,
            )
        )
    return rows


def _declination_orb(request: dict[str, Any], warnings: list[str]) -> float:
    raw_orb = request.get("declination_orb", request.get("declinationOrb", 1.0))
    try:
        orb = float(raw_orb)
    except (TypeError, ValueError, OverflowError):
        warnings.append("赤纬相位 orb 无效，已使用默认 1°。")
        return 1.0
    if not math.isfinite(orb) or orb < 0:
        warnings.append("赤纬相位 orb 无效，已使用默认 1°。")
        return 1.0
    return orb


def _cross_declination_aspects(
    person_a_positions: list[dict[str, Any]],
    person_b_positions: list[dict[str, Any]],
    orb: float = 1.0,
) -> list[dict[str, Any]]:
    """Return only A-vs-B declination aspects with unambiguous point IDs."""
    aspects: list[dict[str, Any]] = []
    for person_a in person_a_positions:
        person_a_id = person_a.get("body_id")
        person_a_dec = person_a.get("declination")
        if person_a_id is None or person_a_dec is None:
            continue
        for person_b in person_b_positions:
            person_b_id = person_b.get("body_id")
            person_b_dec = person_b.get("declination")
            if person_b_id is None or person_b_dec is None:
                continue

            pair_aspects = find_declination_aspects(
                [
                    {
                        "body_id": f"A_{person_a_id}",
                        "declination": person_a_dec,
                    },
                    {
                        "body_id": f"B_{person_b_id}",
                        "declination": person_b_dec,
                    },
                ],
                orb=orb,
            )
            for aspect in pair_aspects:
                aspects.append(
                    {
                        **aspect,
                        "person_a_body_id": person_a_id,
                        "person_a_body_name": person_a.get("name", person_a_id),
                        "person_b_body_id": person_b_id,
                        "person_b_body_name": person_b.get("name", person_b_id),
                    }
                )

    aspects.sort(key=lambda row: (row["diff"], row["body1"], row["body2"]))
    return aspects


def _calculate_full_chart(
    jd: float,
    latitude: float,
    longitude: float,
    house_system: str,
    sidereal: bool,
    specs: list[Any],
    point_set: dict[str, Any],
    warnings: list[str],
) -> dict[str, Any]:
    positions = calculate_positions(jd, specs, warnings, sidereal=sidereal)
    cusps, angle_values, system_label = build_houses(
        jd, latitude, longitude, house_system, sidereal, warnings,
    )
    positioned = [
        {**row, "house": house_for_longitude(row["longitude"], cusps)}
        for row in positions
    ]
    angles = _angle_rows(point_set["angle_ids"], angle_values, cusps)
    houses = house_rows(cusps)
    ephemerides = {row.get("_ephemeris", "Swiss Ephemeris") for row in positions}
    return {
        "positions": positioned,
        "angles": angles,
        "available_angle_ids": [row["id"] for row in angles],
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
    point_set = resolve_point_set(
        request.get("point_set"),
        default_body_ids=SYNASTRY_MAIN_BODIES,
        default_include_nodes=True,
        default_angle_ids=SYNASTRY_ANGLE_IDS,
        node_mode=node_mode,
    )
    specs = _resolve_point_specs(point_set, warnings)

    chart_a = _calculate_full_chart(
        a_jd, a_lat, a_lon, house_system, sidereal, specs, point_set, warnings,
    )
    chart_b = _calculate_full_chart(
        b_jd, b_lat, b_lon, house_system, sidereal, specs, point_set, warnings,
    )

    cross_aspects: list[dict[str, Any]] = []
    try:
        cross_aspects = find_aspects(chart_a["positions"], chart_b["positions"], aspect_specs)
    except Exception as exc:
        warnings.append(f"跨盘相位计算失败：{exc}")
        section_errors["cross_aspects"] = str(exc)

    cross_declination_aspects: list[dict[str, Any]] = []
    try:
        cross_declination_aspects = _cross_declination_aspects(
            chart_a["positions"],
            chart_b["positions"],
            orb=_declination_orb(request, warnings),
        )
    except Exception as exc:
        warnings.append(f"跨盘赤纬相位计算失败：{exc}")
        section_errors["cross_declination_aspects"] = str(exc)

    a_in_b = _cross_house_placements(chart_a["positions"], chart_b["cusps"])
    b_in_a = _cross_house_placements(chart_b["positions"], chart_a["cusps"])

    all_ephemerides = chart_a["ephemerides"] | chart_b["ephemerides"]
    available_body_ids = [
        row["body_id"]
        for row in chart_a["positions"] + chart_b["positions"]
    ]
    available_angle_ids = [
        angle_id
        for angle_id in point_set["angle_ids"]
        if angle_id in chart_a["available_angle_ids"]
        and angle_id in chart_b["available_angle_ids"]
    ]
    effective_point_set = finalize_point_set(
        point_set,
        available_body_ids,
        available_angle_ids=available_angle_ids,
        warnings=warnings,
    )

    return {
        "meta": {
            "method": "synastry_cross_aspect",
            "person_a_utc": a_utc,
            "person_b_utc": b_utc,
            "ephemeris": ", ".join(sorted(all_ephemerides)) if all_ephemerides else "unknown",
            "effective_point_set": effective_point_set,
        },
        "person_a_planets": chart_a["positions"],
        "person_b_planets": chart_b["positions"],
        "person_a_angles": chart_a["angles"],
        "person_b_angles": chart_b["angles"],
        "person_a_houses": chart_a["houses"],
        "person_b_houses": chart_b["houses"],
        "cross_aspects": cross_aspects,
        "cross_declination_aspects": cross_declination_aspects,
        "a_in_b_houses": a_in_b,
        "b_in_a_houses": b_in_a,
        "patterns": [],
        "warnings": warnings,
        "section_errors": section_errors if section_errors else None,
    }
