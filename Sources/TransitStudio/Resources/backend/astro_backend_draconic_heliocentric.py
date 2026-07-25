"""Draconic chart packet and heliocentric comparison.

mode=draconic_heliocentric
"""

from __future__ import annotations

from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    CLASSICAL_BODY_IDS,
    format_longitude,
    moment_to_jd,
    norm360,
    set_zodiac_mode,
    swe,
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

METHOD = "draconic_heliocentric_v1"
SCHEMA_VERSION = 1


def _public(row: dict[str, Any], *, coordinate_center: str, coordinate_system: str) -> dict[str, Any]:
    return {
        "body_id": row["body_id"],
        "name": row["name"],
        "longitude": round(float(row["longitude"]), 9),
        "latitude": row.get("latitude"),
        "speed": row.get("speed"),
        "sign": row.get("sign"),
        "degree_text": row.get("degree_text"),
        "house": row.get("house"),
        "coordinate_center": coordinate_center,
        "coordinate_system": coordinate_system,
        "coordinate_kind": "ecliptic_longitude",
    }


def _draconic_shift(node_lon: float) -> float:
    """Draconic: shift so North Node is 0° Aries."""
    return norm360(0.0 - node_lon)


def calculate_draconic_heliocentric(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    moment = birth["moment"]
    jd, birth_utc = moment_to_jd(moment)
    lat = float(birth["latitude"])
    lon = float(birth["longitude"])
    house_system = birth.get("houseSystem", birth.get("house_system", "whole_sign"))
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    node_mode = str(request.get("node_mode") or "true_node")
    node_id = "TRUE_NODE" if node_mode == "true_node" else "MEAN_NODE"

    point_set = resolve_point_set(request.get("point_set"), node_mode=node_mode)
    body_ids = list(point_set["resolved_body_ids"]) or list(CLASSICAL_BODY_IDS)
    if node_id not in body_ids:
        body_ids = body_ids + [node_id]
    specs = resolve_bodies(
        [b for b in body_ids if not b.startswith("AST:")],
        list(point_set.get("custom_asteroids") or []),
        warnings,
    )
    geo_positions = calculate_positions(jd, specs, warnings, sidereal=sidereal)
    geo_by = {r["body_id"]: r for r in geo_positions}
    if node_id not in geo_by:
        raise RuntimeError(f"node {node_id} unavailable for Draconic")
    node_lon = float(geo_by[node_id]["longitude"])
    shift = _draconic_shift(node_lon)

    cusps, angles, house_label = build_houses(jd, lat, lon, house_system, sidereal, warnings)
    draconic_planets = []
    for row in geo_positions:
        dlon = norm360(float(row["longitude"]) + shift)
        sign, degree_text = format_longitude(dlon)
        drow = {
            **row,
            "longitude": dlon,
            "sign": sign,
            "degree_text": degree_text,
            "house": house_for_longitude(dlon, [norm360(c + shift) for c in cusps]),
        }
        draconic_planets.append(
            _public(drow, coordinate_center="geocentric", coordinate_system="draconic_ecliptic")
        )

    draconic_angles = []
    for aid, name in (("ASC", "ASC"), ("MC", "MC"), ("DSC", "DSC"), ("IC", "IC")):
        if aid in angles:
            alon = norm360(float(angles[aid]) + shift)
            sign, degree_text = format_longitude(alon)
            draconic_angles.append(
                {
                    "id": aid,
                    "name": name,
                    "longitude": round(alon, 9),
                    "sign": sign,
                    "degree_text": degree_text,
                    "coordinate_center": "geocentric",
                    "coordinate_system": "draconic_ecliptic",
                }
            )

    # Heliocentric positions via SE FLG_HELCTR
    # Standard set: include Earth (SE_EARTH), hide Sun (origin), hide Moon by default.
    helio_planets = []
    helio_errors: dict[str, str] = {}
    include_moon_helio = bool(request.get("include_heliocentric_moon", False))
    for spec in specs:
        if spec.body_id in ("MEAN_NODE", "TRUE_NODE", "SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE", "MEAN_LILITH", "OSCU_LILITH"):
            continue
        if spec.body_id == "SUN":
            # Sun is the heliocentric origin — omit from standard output.
            continue
        if spec.body_id == "MOON" and not include_moon_helio:
            continue
        try:
            flags = swe.FLG_SWIEPH | swe.FLG_SPEED | swe.FLG_HELCTR
            if sidereal:
                flags |= swe.FLG_SIDEREAL
            values, _ = swe.calc_ut(jd, spec.code, flags)
            hlon = (float(values[0]) + spec.longitude_offset) % 360.0
            sign, degree_text = format_longitude(hlon)
            row = _public(
                {
                    "body_id": spec.body_id,
                    "name": spec.name,
                    "longitude": hlon,
                    "latitude": float(values[1]),
                    "speed": float(values[3]),
                    "sign": sign,
                    "degree_text": degree_text,
                    "house": None,
                },
                coordinate_center="heliocentric",
                coordinate_system="tropical_ecliptic" if not sidereal else "sidereal_ecliptic",
            )
            if spec.body_id == "MOON":
                row["experimental"] = True
                row["note"] = "Heliocentric Moon is near Earth; experimental"
            helio_planets.append(row)
        except Exception as exc:
            helio_errors[spec.body_id] = str(exc)
            warnings.append(f"heliocentric {spec.name} failed: {exc}")

    # Add Earth (heliocentric Earth = geocentric Sun + 180° approximately, via SE_EARTH)
    try:
        flags = swe.FLG_SWIEPH | swe.FLG_SPEED | swe.FLG_HELCTR
        if sidereal:
            flags |= swe.FLG_SIDEREAL
        earth_code = getattr(swe, "EARTH", 14)
        values, _ = swe.calc_ut(jd, earth_code, flags)
        hlon = float(values[0]) % 360.0
        sign, degree_text = format_longitude(hlon)
        helio_planets.insert(
            0,
            _public(
                {
                    "body_id": "EARTH",
                    "name": "Earth",
                    "longitude": hlon,
                    "latitude": float(values[1]),
                    "speed": float(values[3]),
                    "sign": sign,
                    "degree_text": degree_text,
                    "house": None,
                },
                coordinate_center="heliocentric",
                coordinate_system="tropical_ecliptic" if not sidereal else "sidereal_ecliptic",
            ),
        )
    except Exception as exc:
        helio_errors["EARTH"] = str(exc)
        warnings.append(f"heliocentric Earth failed: {exc}")

    # Comparison table geo vs helio for shared bodies
    geo_map = {r["body_id"]: r for r in geo_positions}
    comparison = []
    for h in helio_planets:
        g = geo_map.get(h["body_id"])
        if not g:
            continue
        delta = abs(((float(h["longitude"]) - float(g["longitude"]) + 180) % 360) - 180)
        comparison.append(
            {
                "body_id": h["body_id"],
                "name": h["name"],
                "geocentric_longitude": round(float(g["longitude"]), 9),
                "heliocentric_longitude": h["longitude"],
                "delta_deg": round(delta, 6),
                "coordinate_center_geocentric": "geocentric",
                "coordinate_center_heliocentric": "heliocentric",
            }
        )

    effective = finalize_point_set(
        point_set,
        [r["body_id"] for r in geo_positions],
        available_angle_ids=list(angles.keys()),
        warnings=warnings,
    )

    # Draconic → tropical natal contacts (overlay priority); internal draconic aspects = natal aspects.
    draconic_to_natal: list[dict[str, Any]] = []
    try:
        from astro_backend_scan import find_aspects

        aspect_specs = request.get("aspects") or [
            {"id": "conjunction", "angle": 0, "orb": 1.0},
            {"id": "opposition", "angle": 180, "orb": 1.0},
        ]
        # Map draconic planets as "transit" against geocentric natal.
        d_pos = [
            {"body_id": p["body_id"], "name": p.get("name", p["body_id"]), "longitude": p["longitude"], "speed": 0.0}
            for p in draconic_planets
        ]
        n_pos = [
            {"body_id": p["body_id"], "name": p.get("name", p["body_id"]), "longitude": p["longitude"], "speed": p.get("speed", 0.0)}
            for p in geo_positions
        ]
        # Also add natal angles as targets
        for aid, alon in angles.items():
            if aid in {"ASC", "MC", "DSC", "IC"}:
                n_pos.append({"body_id": aid, "name": aid, "longitude": float(alon), "speed": 0.0})
        draconic_to_natal = find_aspects(d_pos, n_pos, aspect_specs)
    except Exception as exc:
        warnings.append(f"draconic→natal overlay aspects failed: {exc}")

    # Heliocentric major aspects among helio planets
    helio_aspects: list[dict[str, Any]] = []
    try:
        from astro_backend_scan import find_aspects

        aspect_specs = request.get("aspects") or [
            {"id": "conjunction", "angle": 0, "orb": 1.0},
            {"id": "opposition", "angle": 180, "orb": 1.0},
            {"id": "trine", "angle": 120, "orb": 1.0},
            {"id": "square", "angle": 90, "orb": 1.0},
            {"id": "sextile", "angle": 60, "orb": 1.0},
        ]
        h_pos = [
            {"body_id": p["body_id"], "name": p.get("name", p["body_id"]), "longitude": p["longitude"], "speed": p.get("speed", 0.0)}
            for p in helio_planets
        ]
        helio_aspects = find_aspects(h_pos, h_pos, aspect_specs, skip_self_aspects=True)
    except Exception as exc:
        warnings.append(f"heliocentric aspects failed: {exc}")

    include_draconic_houses = bool(request.get("include_draconic_houses", False))

    assumptions = [
        "Draconic: tropical/sidereal natal longitudes shifted so North Node → 0° Aries.",
        f"node_mode={node_mode}; node_longitude={node_lon:.6f}; shift={shift:.6f}.",
        "Draconic internal aspects equal natal internal aspects (uniform shift); not new structures.",
        "Primary output: Draconic→tropical natal overlay (conjunction/opposition preferred).",
        "Draconic houses: experimental_house_overlay; hidden by default.",
        "Heliocentric: FLG_HELCTR; includes Earth; Sun hidden (origin); Moon optional experimental.",
        "Nodes/Lilith skipped for heliocentric.",
        "Houses are geocentric constructs; heliocentric rows have house=null.",
        "Geo vs Helio Δ is geometric (observer center/distance), not character meaning.",
        "结果为坐标事实，不含解释性论断。",
    ]

    return {
        "meta": {
            "mode": "draconic_heliocentric",
            "method": METHOD,
            "schema_version": SCHEMA_VERSION + 1 if isinstance(SCHEMA_VERSION, int) else SCHEMA_VERSION,
            "birth_utc": birth_utc,
            "zodiac": zodiac,
            "node_mode": node_mode,
            "node_id": node_id,
            "node_longitude": round(node_lon, 9),
            "draconic_shift_deg": round(shift, 9),
            "house_system": house_system if include_draconic_houses else None,
            "house_label": house_label if include_draconic_houses else None,
            "ephemeris": "Swiss Ephemeris",
            "effective_point_set": effective,
            "draconic_houses": "experimental_house_overlay" if include_draconic_houses else "hidden",
        },
        "requested_config": {
            "node_mode": request.get("node_mode"),
            "zodiac": zodiac,
            "point_set": request.get("point_set"),
            "include_draconic_houses": include_draconic_houses,
            "include_heliocentric_moon": include_moon_helio,
        },
        "effective_config": {
            "node_mode": node_mode,
            "node_id": node_id,
            "draconic_shift_deg": round(shift, 9),
            "zodiac": zodiac,
            "house_system": house_system if include_draconic_houses else None,
            "method": METHOD,
        },
        "draconic": {
            "shift_deg": round(shift, 9),
            "node_id": node_id,
            "node_longitude": round(node_lon, 9),
            "planets": draconic_planets,
            "angles": draconic_angles,
            "coordinate_system": "draconic_ecliptic",
            "coordinate_center": "geocentric",
            "to_natal_aspects": draconic_to_natal,
            "internal_aspects_note": "equal to natal internal aspects under uniform shift; not emitted as new",
            "houses": "experimental_house_overlay" if include_draconic_houses else None,
            "experimental_house_overlay": include_draconic_houses,
        },
        "heliocentric": {
            "planets": helio_planets,
            "aspects": helio_aspects,
            "coordinate_system": "tropical_ecliptic" if not sidereal else "sidereal_ecliptic",
            "coordinate_center": "heliocentric",
            "sun_included": False,
            "earth_included": any(p.get("body_id") == "EARTH" for p in helio_planets),
            "moon_included": include_moon_helio,
            "errors": helio_errors or None,
        },
        "geocentric": {
            "planets": [
                _public(
                    {**r, "house": house_for_longitude(float(r["longitude"]), cusps)},
                    coordinate_center="geocentric",
                    coordinate_system="tropical_ecliptic" if not sidereal else "sidereal_ecliptic",
                )
                for r in geo_positions
            ],
            "angles": [
                point_row(aid, aid, angles[aid], cusps)
                for aid in ("ASC", "MC", "DSC", "IC")
                if aid in angles
            ],
            "houses": house_rows(cusps),
            "coordinate_center": "geocentric",
        },
        "geo_helio_comparison": comparison,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": None,
        "calculation_assumptions": assumptions,
    }


__all__ = ["calculate_draconic_heliocentric", "_draconic_shift"]
