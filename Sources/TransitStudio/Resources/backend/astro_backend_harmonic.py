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

        # Map H-chart aspects to natal harmonic families.
        # H_n conjunction = natal n-fold; H_n opposition = natal 2n family, etc.
        aspect_angle = {
            "conjunction": 0.0,
            "opposition": 180.0,
            "trine": 120.0,
            "square": 90.0,
            "sextile": 60.0,
        }
        # Need natal longitudes for equivalent angles
        natal_lon = {bid: float(natal_by_id[bid]["longitude"]) for bid in natal_by_id}
        for a in aspects:
            aid = str(a.get("aspect_id") or a.get("aspect") or "").lower()
            h_angle = aspect_angle.get(aid)
            if h_angle is None:
                # Fall back to localized aspect names when a custom aspect
                # identifier is not one of the canonical IDs.
                name = str(a.get("aspect_name") or a.get("aspect") or "")
                if "合" in name:
                    h_angle = 0.0
                    aid = "conjunction"
                elif "冲" in name:
                    h_angle = 180.0
                    aid = "opposition"
                elif "拱" in name:
                    h_angle = 120.0
                    aid = "trine"
                elif "刑" in name:
                    h_angle = 90.0
                    aid = "square"
                elif "六合" in name:
                    h_angle = 60.0
                    aid = "sextile"
            if h_angle is None:
                continue
            # family: harmonic_order * (360/gcd) mapping
            # H chart angle A corresponds to natal unit 360/(H * k) where A = k * (360/H)/something
            # Standard: natal_unit = 360 / (harmonic_order * m) where H-chart aspect is m-fold of base.
            # Conjunction (0) → family H_n; opposition (180) → H_(2n); trine 120 → H_(3n); square 90 → H_(4n); sextile 60 → H_(6n)
            mult = {0.0: 1, 180.0: 2, 120.0: 3, 90.0: 4, 60.0: 6}.get(h_angle, 1)
            family_n = harmonic_order * mult
            natal_unit = 360.0 / family_n if family_n else None
            h_orb = float(a.get("orb") or 0.0)
            natal_equiv_orb = h_orb / harmonic_order if harmonic_order else None
            ba = a.get("transit_body_id")
            bb = a.get("natal_body_id")
            natal_sep = None
            if ba in natal_lon and bb in natal_lon:
                from astro_backend_core import signed_orb
                natal_sep = abs(signed_orb(natal_lon[ba], natal_lon[bb]))
            a["harmonic_chart_angle"] = h_angle
            a["harmonic_chart_orb"] = h_orb
            a["natal_separation_deg"] = round(natal_sep, 6) if natal_sep is not None else None
            a["natal_harmonic_unit_deg"] = round(natal_unit, 6) if natal_unit is not None else None
            a["natal_equivalent_orb"] = round(natal_equiv_orb, 6) if natal_equiv_orb is not None else None
            a["harmonic_family"] = f"H{family_n}"
            a["is_primary_for_selected_harmonic"] = h_angle == 0.0
            a["priority"] = 0 if h_angle == 0.0 else 1
        # Prefer H_n conjunctions first when listing
        aspects.sort(key=lambda row: (row.get("priority", 1), abs(float(row.get("orb") or 99))))
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

    include_houses = bool(request.get("include_harmonic_houses", False))
    if not include_houses:
        warnings.append(
            "Harmonic house cusps/house numbers hidden by default (experimental overlay); "
            "angles retained as experimental multiplied axes. "
            "Pass include_harmonic_houses=true to emit house cusps."
        )

    return {
        "meta": {
            "method": f"harmonic_{harmonic_order}",
            "method_version": "harmonic_family_map_v1",
            "natal_utc": birth_utc_str,
            "progressed_utc": None,
            "ephemeris": ", ".join(sorted(all_ephemerides)) if all_ephemerides else "unknown",
            "effective_point_set": point_set,
            "houses_experimental": True,
            "angles_experimental": True,
            "include_harmonic_houses": include_houses,
        },
        "planets": [{**p, "house": p["house"] if include_houses else None} for p in harmonic_planet_rows],
        # Angles kept (experimental multiplied ASC/MC); not a complete harmonic house system.
        "angles": [{**a, "experimental": True} for a in harmonic_angle_rows],
        "houses": harmonic_house_rows if include_houses else [],
        "houses_experimental": True,
        "aspects": aspects,
        "warnings": warnings,
        "harmonic_order": harmonic_order,
        "calculation_assumptions": [
            f"H{harmonic_order} chart angles: longitude * {harmonic_order} mod 360.",
            "H-chart conjunction maps to natal H_n family; opposition→H_2n; trine→H_3n; square→H_4n; sextile→H_6n.",
            "natal_equivalent_orb = harmonic_chart_orb / harmonic_order.",
            "Primary listing prioritizes H-chart conjunctions for the selected harmonic.",
            "House cusps experimental and hidden by default; angle multiplication is experimental.",
        ],
        "section_errors": section_errors if section_errors else None,
    }
