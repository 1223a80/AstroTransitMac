from __future__ import annotations

from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
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


HARMONIC_BODY_IDS = [
    "SUN", "MOON", "MERCURY", "VENUS", "MARS",
    "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
]


def calculate_harmonic(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    house_system = request.get("house_system") or birth.get("houseSystem", "whole_sign")
    sidereal = set_zodiac_mode(zodiac)
    node_mode = request.get("node_mode", "true_node")
    aspect_specs = request.get("aspects", [])
    harmonic_order = int(request.get("harmonic_order", 4))

    birth_jd, birth_utc_str = moment_to_jd(birth["moment"])
    latitude = float(birth["latitude"])
    longitude = float(birth["longitude"])

    body_ids = list(HARMONIC_BODY_IDS)
    if node_mode == "true_node":
        body_ids += ["TRUE_NODE", "SOUTH_TRUE_NODE"]
    elif node_mode == "mean_node":
        body_ids += ["MEAN_NODE", "SOUTH_MEAN_NODE"]

    specs = resolve_bodies(body_ids, [], warnings)
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
    for body_id in body_ids:
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

    harmonic_angle_rows = [
        point_row("ASC", "ASC", harmonic_ASC, harmonic_cusps),
        point_row("MC", "MC", harmonic_MC, harmonic_cusps),
        point_row("DSC", "DSC", harmonic_DSC, harmonic_cusps),
        point_row("IC", "IC", harmonic_IC, harmonic_cusps),
    ]
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

    return {
        "meta": {
            "method": f"harmonic_{harmonic_order}",
            "natal_utc": birth_utc_str,
            "progressed_utc": None,
            "ephemeris": ", ".join(sorted(all_ephemerides)) if all_ephemerides else "unknown",
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
