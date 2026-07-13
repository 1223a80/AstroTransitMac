from __future__ import annotations

from typing import Any

from astro_backend_core import (
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


def _resolve_harmonic_specs(point_set: dict[str, Any], warnings: list[str]) -> list[Any]:
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


def calculate_harmonic(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    house_system = request.get("house_system") or birth.get("houseSystem", "whole_sign")
    sidereal = set_zodiac_mode(zodiac, warnings)
    node_mode = request.get("node_mode", "true_node")
    aspect_specs = request.get("aspects", [])
    harmonic_order = int(request.get("harmonic_order", 4))
    point_set = resolve_point_set(
        request.get("point_set") if "point_set" in request else None,
        node_mode=node_mode,
    )

    birth_jd, birth_utc_str = moment_to_jd(birth["moment"])
    latitude = float(birth["latitude"])
    longitude = float(birth["longitude"])

    specs = _resolve_harmonic_specs(point_set, warnings)
    natal_positions = calculate_positions(birth_jd, specs, warnings, sidereal=sidereal)

    natal_cusps, natal_angles, _ = build_houses(
        birth_jd, latitude, longitude, house_system, sidereal, warnings,
    )
    natal_by_id = {row["body_id"]: row for row in natal_positions}

    # Harmonic positions: multiply by order, normalize to [0, 360)
    harmonic_ASC = norm360(natal_angles["ASC"] * harmonic_order)
    harmonic_MC = norm360(natal_angles["MC"] * harmonic_order)
    harmonic_DSC = norm360(harmonic_ASC + 180.0)
    harmonic_IC = norm360(harmonic_MC + 180.0)

    if house_system == "whole_sign":
        first_cusp = (int(harmonic_ASC // 30)) * 30.0
        harmonic_cusps = [norm360(first_cusp + 30.0 * i) for i in range(12)]
    else:
        sidereal_mc_delta = norm360(harmonic_MC - natal_angles["MC"])
        harmonic_cusps = [norm360(c + sidereal_mc_delta) for c in natal_cusps]

    section_errors: dict[str, str] = {}

    harmonic_planet_rows: list[dict[str, Any]] = []
    for body_id in point_set["resolved_body_ids"]:
        natal = natal_by_id.get(body_id)
        if natal is None:
            continue
        h_lon = norm360(natal["longitude"] * harmonic_order)
        sign, degree_text = "", ""
        try:
            from astro_backend_core import format_longitude
            sign, degree_text = format_longitude(h_lon)
        except Exception:
            pass
        h = house_for_longitude(h_lon, harmonic_cusps)
        harmonic_planet_rows.append({
            "body_id": body_id,
            "name": natal["name"],
            "longitude": h_lon,
            "latitude": natal.get("latitude", 0.0),
            "speed": natal.get("speed", 0.0) * harmonic_order,
            "sign": sign,
            "degree_text": degree_text,
            "house": h,
        })

    harmonic_angle_values = {
        "ASC": harmonic_ASC,
        "MC": harmonic_MC,
        "DSC": harmonic_DSC,
        "IC": harmonic_IC,
    }
    for angle_id in ("VERTEX", "ANTIVERTEX", "EQUATORIAL_ASCENDANT"):
        if angle_id in natal_angles:
            harmonic_angle_values[angle_id] = norm360(natal_angles[angle_id] * harmonic_order)
    harmonic_angle_rows, available_angle_ids = _angle_rows(
        harmonic_angle_values, point_set["angle_ids"], harmonic_cusps, warnings,
    )
    harmonic_house_rows = house_rows(harmonic_cusps)

    aspects: list[dict[str, Any]] = []
    try:
        # Exclude lunar nodes from harmonic aspect calculation
        harmonic_aspect_bodies = [
            row for row in harmonic_planet_rows
            if row["body_id"] not in {"TRUE_NODE", "SOUTH_TRUE_NODE", "MEAN_NODE", "SOUTH_MEAN_NODE"}
        ]
        aspects = find_aspects(harmonic_aspect_bodies, harmonic_aspect_bodies, aspect_specs, skip_self_aspects=True)
        # Deduplicate bidirectional pairs: sort bodyA and bodyB
        seen: set[tuple[str, str, str]] = set()
        deduped: list[dict[str, Any]] = []
        for a in aspects:
            body_a = a["transit_body_id"]
            body_b = a["natal_body_id"]
            key = (min(body_a, body_b), max(body_a, body_b), a["aspect_id"])
            if key not in seen:
                seen.add(key)
                deduped.append(a)
        aspects = deduped
    except Exception as exc:
        warnings.append(f"Harmonic 相位计算失败：{exc}")
        section_errors["aspects"] = str(exc)

    all_ephemerides = {row.get("_ephemeris", "Swiss Ephemeris") for row in natal_positions}

    point_set = finalize_point_set(
        point_set,
        [row["body_id"] for row in natal_positions],
        available_angle_ids=available_angle_ids,
        warnings=warnings,
    )

    return {
        "meta": {
            "method": f"harmonic_{harmonic_order}",
            "natal_utc": birth_utc_str,
            "progressed_utc": None,
            "ephemeris": ", ".join(sorted(all_ephemerides)) if all_ephemerides else "unknown",
            "effective_point_set": point_set,
        },
        "planets": harmonic_planet_rows,
        "angles": harmonic_angle_rows,
        "houses": harmonic_house_rows,
        "houses_experimental": True,
        "aspects": aspects,
        "warnings": warnings,
        "harmonic_order": harmonic_order,
        "section_errors": section_errors if section_errors else None,
    }
