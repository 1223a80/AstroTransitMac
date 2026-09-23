from __future__ import annotations

import json
import math
import sys
from datetime import datetime
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from backend_runtime import apply_runtime_options

from astro_backend_constants import (
    ALL_BOUNDS_SYSTEMS,
    ALL_HOUSE_SYSTEMS,
    ALL_TRIPLICITY_SYSTEMS,
    ALL_ZODIACS,
)

from astro_backend_classical import (
    calculate_almuten_figuris,
    calculate_antiscia,
    calculate_hyleg_alcocoden,
    calculate_prenatal_syzygy,
    classical_snapshot,
    decennials_summary,
    firdaria_summary,
    profection_summary,
    return_summary,
    timing_timeline,
    zodiacal_releasing_summary,
)
from astro_backend_horary import calculate_horary
from astro_backend_horary_v2 import calculate_horary_v2
from astro_backend_core import (
    BODY_REGISTRY,
    CLASSICAL_BODY_IDS,
    fail,
    find_declination_aspects,
    format_local,
    moment_to_jd,
    moment_to_local_datetime,
    public_position,
    set_zodiac_mode,
    swe,
    zodiac_mode_label,
)
from astro_backend_ephemeris import (
    build_houses,
    calculate_positions,
    configure_runtime,
    house_for_longitude,
    house_rows,
    point_row,
    resolve_bodies,
)
from astro_backend_scan import find_aspects, scan_window
from astro_backend_fixed_stars import compute_star_positions, find_star_conjunctions
from astro_backend_modern_points import (
    DEFAULT_MODERN_BODY_IDS,
    NODE_BODY_IDS,
    SUPPORTED_ANGLE_IDS,
    finalize_point_set,
    resolve_point_set,
    validate_point_set,
)
from astro_backend_patterns import find_patterns
from astro_backend_classical_medieval import (
    sect_light_triplicity_rulers,
    determine_kurios,
    profection_solar_return_synthesis,
)

HORARY_V1_PACKET_VERSIONS = {"1", "v1", "legacy", "1.0"}
HORARY_V2_PACKET_VERSIONS = {"2", "v2", "2.0", "2.1"}


def _bundled_ephemeris_path(module_file: Path | None = None) -> Path | None:
    """Return the bundled Swiss Ephemeris path for source and app layouts."""
    backend_dir = Path(module_file or __file__).resolve().parent
    candidates = [
        backend_dir.parent / "ephemeris",  # Source tree: Resources/backend + Resources/ephemeris
        backend_dir,  # Packaged SwiftPM resource bundle flattens files into the bundle root.
    ]
    for candidate in candidates:
        if (candidate / "sefstars.txt").exists() or (candidate / "seas_18.se1").exists():
            return candidate
    return next((candidate for candidate in candidates if candidate.exists()), None)


def _resolve_ephe_path(user_path: str, bundled: Path | None) -> str | None:
    """Combine the user ephemeris dir with the bundled dir for Swiss Ephemeris.

    Swiss Ephemeris accepts multiple colon-separated directories; keeping the
    bundled path as fallback ensures files like ``sefstars.txt`` stay reachable
    when the user directory only holds planet/asteroid ``.se1`` files.
    """
    if user_path and bundled is not None and str(bundled) != user_path:
        return f"{user_path}:{bundled}"
    if user_path:
        return user_path
    if bundled is not None:
        return str(bundled)
    return None


def _cross_declination_aspects(
    natal_positions: list[dict[str, Any]],
    transit_positions: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Return only natal-vs-transit declination aspects with prefixed IDs."""
    aspects: list[dict[str, Any]] = []
    for natal in natal_positions:
        natal_id = natal.get("body_id")
        natal_dec = natal.get("declination")
        if natal_id is None or natal_dec is None:
            continue
        for transit in transit_positions:
            transit_id = transit.get("body_id")
            transit_dec = transit.get("declination")
            if transit_id is None or transit_dec is None:
                continue
            pair = [
                {"body_id": f"natal_{natal_id}", "declination": natal_dec},
                {"body_id": f"transit_{transit_id}", "declination": transit_dec},
            ]
            aspects.extend(find_declination_aspects(pair))
    aspects.sort(key=lambda row: row["diff"])
    return aspects


def _legacy_moment_point_set(
    body_ids: list[str],
    custom_asteroids: list[int],
) -> dict[str, Any]:
    """Describe the pre-point_set moment request without changing its output."""
    selected_nodes = [body_id for body_id in body_ids if body_id in NODE_BODY_IDS]
    body_ids = [body_id for body_id in body_ids if body_id not in NODE_BODY_IDS]
    resolved = list(dict.fromkeys(body_ids + selected_nodes + [f"AST:{number}" for number in custom_asteroids]))
    node_mode = "mean_node" if any("MEAN" in node_id for node_id in selected_nodes) else "true_node"
    return {
        "body_ids": body_ids,
        "include_nodes": bool(selected_nodes),
        "node_mode": node_mode,
        "custom_asteroids": custom_asteroids,
        "angle_ids": ["ASC", "MC", "DSC", "IC"],
        "house_cusps": [],
        "lot_ids": [],
        "resolved_body_ids": resolved,
    }


def _modern_chart_profile(
    positions: list[dict[str, Any]],
    point_ids: list[str],
    *,
    reliable_houses: bool,
) -> dict[str, Any]:
    """Return transparent counts; deliberately no interpretive conclusion."""
    from astro_backend_core import zodiac_sign_index

    element_names = ("fire", "earth", "air", "water")
    modality_names = ("cardinal", "fixed", "mutable")
    elements = {name: 0 for name in element_names}
    modalities = {name: 0 for name in modality_names}
    polarities = {"positive": 0, "negative": 0}
    hemispheres = {"east": 0, "west": 0, "above": 0, "below": 0}
    quadrants = {"q1": 0, "q2": 0, "q3": 0, "q4": 0}
    by_id = {row.get("body_id"): row for row in positions}
    included_ids = [body_id for body_id in point_ids if body_id in by_id]

    for body_id in included_ids:
        row = by_id[body_id]
        sign = zodiac_sign_index(float(row["longitude"]))
        elements[element_names[sign % 4]] += 1
        modalities[modality_names[sign % 3]] += 1
        polarities["positive" if sign % 2 == 0 else "negative"] += 1
        house = row.get("house")
        if reliable_houses and isinstance(house, int) and 1 <= house <= 12:
            if house in {10, 11, 12, 1, 2, 3}:
                hemispheres["east"] += 1
            else:
                hemispheres["west"] += 1
            if house >= 7:
                hemispheres["above"] += 1
            else:
                hemispheres["below"] += 1
            quadrants[f"q{((house - 1) // 3) + 1}"] += 1

    omitted_sections: list[str] = []
    if not reliable_houses:
        omitted_sections.extend(["hemispheres", "quadrants"])
    return {
        "point_ids": included_ids,
        "elements": elements,
        "modalities": modalities,
        "polarities": polarities,
        "hemispheres": hemispheres,
        "quadrants": quadrants,
        "omitted_sections": omitted_sections,
    }


def _closest_primary_directions(
    primary_directions: list[dict[str, Any]],
    reference_age: float,
    limit: int = 3,
) -> list[dict[str, Any]]:
    """Return directions nearest the requested age, not merely the first rows."""
    return sorted(
        primary_directions,
        key=lambda entry: abs(float(entry.get("age_from_abs_arc", 0)) - reference_age),
    )[:limit]


def calculate_moment(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    natal_jd, natal_utc = moment_to_jd(request["natal"])
    transit_jd, transit_utc = moment_to_jd(request["transit"])
    birth = request.get("birth")
    zodiac = (birth or {}).get("zodiac", request.get("zodiac", "tropical"))
    sidereal = set_zodiac_mode(zodiac, warnings)
    same_chart = bool(request.get("sameChart", request.get("same_chart", False)))
    legacy_custom_asteroids = [int(value) for value in request.get("customAsteroids", [])]
    legacy_natal_body_ids = list(request.get("natalBodies", []))
    if "point_set" in request:
        point_set = resolve_point_set(
            request.get("point_set"),
            default_body_ids=[
                body_id for body_id in legacy_natal_body_ids if body_id not in NODE_BODY_IDS
            ] or DEFAULT_MODERN_BODY_IDS,
            default_include_nodes=any(body_id in NODE_BODY_IDS for body_id in legacy_natal_body_ids),
            node_mode=str(request.get("node_mode", "true_node")),
            legacy_custom_asteroids=legacy_custom_asteroids,
        )
    else:
        point_set = _legacy_moment_point_set(legacy_natal_body_ids, legacy_custom_asteroids)
    custom_asteroids = list(point_set["custom_asteroids"])
    natal_specs = resolve_bodies(request.get("natalBodies", []), custom_asteroids, warnings)
    transit_specs = resolve_bodies(request.get("transitBodies", []), custom_asteroids, warnings)

    natal_positions = calculate_positions(natal_jd, natal_specs, warnings, sidereal=sidereal)
    transit_positions = calculate_positions(transit_jd, transit_specs, warnings, sidereal=sidereal)
    aspects = find_aspects(
        transit_positions,
        natal_positions,
        request.get("aspects", []),
        skip_self_aspects=same_chart,
    )
    ephemerides = {row.get("_ephemeris", "Swiss Ephemeris") for row in natal_positions + transit_positions}

    angles: list[dict[str, Any]] = []
    houses: list[dict[str, Any]] = []
    lots: list[dict[str, Any]] = []
    if birth:
        latitude = float(birth["latitude"])
        longitude = float(birth["longitude"])
        house_system = birth.get("houseSystem", "whole_sign")
        cusps, angle_values, _ = build_houses(natal_jd, latitude, longitude, house_system, sidereal, warnings)
        natal_positions = [
            {**row, "house": house_for_longitude(row["longitude"], cusps)}
            for row in natal_positions
        ]
        angle_names = {
            "ASC": "ASC",
            "MC": "MC",
            "DSC": "DSC",
            "IC": "IC",
            "VERTEX": "Vertex",
            "ANTIVERTEX": "Antivertex",
            "EQUATORIAL_ASCENDANT": "East Point (Equatorial Ascendant)",
        }
        available_angle_ids: list[str] = []
        for angle_id in point_set["angle_ids"]:
            value = angle_values.get(angle_id)
            if value is None:
                warnings.append(f"轴点 {angle_id} 不可用，已从 effective_point_set 移除。")
                continue
            angles.append(point_row(angle_id, angle_names.get(angle_id, angle_id), value, cusps))
            available_angle_ids.append(angle_id)
        point_set["angle_ids"] = available_angle_ids
        houses = house_rows(cusps)
        lot_specs = [BODY_REGISTRY[body_id] for body_id in CLASSICAL_BODY_IDS]
        lot_positions = calculate_positions(natal_jd, lot_specs, warnings, sidereal=sidereal)
        lot_positions_by_id = {row["body_id"]: row for row in lot_positions}
        sun_house = house_for_longitude(lot_positions_by_id["SUN"]["longitude"], cusps)
        is_day = sun_house >= 7
        from astro_backend_classical import calculate_lots

        mc_lon = angle_values.get("MC", 270.0)  # default MC if not available
        lots = calculate_lots(angle_values, lot_positions_by_id, cusps, is_day, mc=mc_lon, warnings=warnings)

    # 赤纬相位（平行/反平行）
    # Compute separately for natal-natal, transit-transit, and cross-aspects
    # to avoid ambiguous "SUN parallel SUN" entries.
    nn_aspects = find_declination_aspects(natal_positions)
    tt_aspects = [] if same_chart else find_declination_aspects(transit_positions)
    # Cross-aspects: tag with natal_/transit_ prefix to disambiguate.
    nt_aspects = [] if same_chart else _cross_declination_aspects(natal_positions, transit_positions)
    declination_aspects = nn_aspects + tt_aspects + nt_aspects

    # 恒星合相
    natal_star_positions = compute_star_positions(natal_jd, warnings=warnings, sidereal=sidereal)
    natal_star_conj = find_star_conjunctions(natal_positions, natal_star_positions)
    transit_star_positions = [] if same_chart else compute_star_positions(
        transit_jd, warnings=warnings, sidereal=sidereal
    )
    transit_star_conj = [] if same_chart else find_star_conjunctions(transit_positions, transit_star_positions)
    point_set = finalize_point_set(
        point_set,
        [row.get("body_id") for row in natal_positions + transit_positions],
        available_angle_ids=point_set.get("angle_ids", []) if birth else [],
        warnings=warnings,
    )
    response: dict[str, Any] = {
        "meta": {
            "natal_utc": natal_utc,
            "transit_utc": transit_utc,
            "ephemeris": ", ".join(sorted(ephemerides)) if ephemerides else "unknown",
            "effective_point_set": point_set,
        },
        "natal_positions": [public_position(row) for row in natal_positions],
        "transit_positions": [public_position(row) for row in transit_positions],
        "declination_aspects": declination_aspects,
        "natal_star_conjunctions": natal_star_conj,
        "transit_star_conjunctions": transit_star_conj,
        "angles": angles,
        "houses": houses,
        "lots": lots,
        "aspects": aspects,
        "warnings": warnings,
    }

    if same_chart and bool(request.get("patterns_enabled", False)):
        analysis_ids = [
            body_id for body_id in point_set["resolved_body_ids"]
            if body_id in {row.get("body_id") for row in natal_positions}
        ]
        analysis_positions = {
            row["body_id"]: float(row["longitude"])
            for row in natal_positions
            if row.get("body_id") in analysis_ids
        }
        analysis_house_map = {
            row["body_id"]: int(row["house"])
            for row in natal_positions
            if row.get("body_id") in analysis_ids and isinstance(row.get("house"), int)
        }
        response["patterns"] = find_patterns(
            analysis_positions,
            aspects,
            house_map=analysis_house_map,
            warnings=warnings,
        )
        response["chart_profile"] = _modern_chart_profile(
            natal_positions,
            analysis_ids,
            reliable_houses=bool(birth),
        )
    return response


def _zr_level_ruler_id(zr: dict[str, Any], level: str) -> str:
    """Extract L1/L2/L3 ruler body id from a ZR packet without collapsing levels into one label."""
    if not isinstance(zr, dict) or not level.startswith("L"):
        return ""
    digit = level[-1]
    key = f"l{digit}_ruler_id"
    if zr.get(key):
        return str(zr[key])
    periods = zr.get(f"l{digit}_periods")
    if isinstance(periods, list):
        active = next((p for p in periods if p.get("is_active")), None)
        if active:
            if active.get("ruler_id"):
                return str(active["ruler_id"])
            if active.get("sign_index") is not None:
                from astro_backend_core import SIGN_RULERS

                return str(SIGN_RULERS[int(active["sign_index"])])
    if level == "L1":
        if zr.get("ruler_id"):
            return str(zr["ruler_id"])
        if zr.get("l1_ruler_id"):
            return str(zr["l1_ruler_id"])
    return ""


def _zr_technique_lords_summary(zodiacal_releasing: list[dict[str, Any]]) -> dict[str, Any]:
    """Layered ZR lords for technique_lords_summary (never label L1 sign as LL3)."""
    spirit = zodiacal_releasing[0] if len(zodiacal_releasing) > 0 else {}
    fortune = zodiacal_releasing[1] if len(zodiacal_releasing) > 1 else {}
    summary = {
        "zr_spirit_l1_lord": _zr_level_ruler_id(spirit, "L1") if spirit else "",
        "zr_spirit_l2_lord": _zr_level_ruler_id(spirit, "L2") if spirit else "",
        "zr_spirit_l3_lord": _zr_level_ruler_id(spirit, "L3") if spirit else "",
        "zr_fortune_l1_lord": _zr_level_ruler_id(fortune, "L1") if fortune else "",
        "zr_fortune_l2_lord": _zr_level_ruler_id(fortune, "L2") if fortune else "",
        "zr_fortune_l3_lord": _zr_level_ruler_id(fortune, "L3") if fortune else "",
        "zr_spirit_l1_sign": spirit.get("l1_sign") or spirit.get("sign") or "",
        "zr_spirit_l2_sign": spirit.get("l2_sign") or "",
        "zr_spirit_l3_sign": spirit.get("l3_sign") or "",
        "zr_fortune_l1_sign": fortune.get("l1_sign") or fortune.get("sign") or "",
        "zr_fortune_l2_sign": fortune.get("l2_sign") or "",
        "zr_fortune_l3_sign": fortune.get("l3_sign") or "",
        "note": "L1/L2/L3 are distinct layers. current_zr_lord uses finest active level when present.",
    }
    if spirit:
        summary["zr_spirit_current_lord"] = spirit.get("current_zr_lord") or spirit.get("current_level_ruler") or ""
        summary["zr_spirit_current_lord_level"] = spirit.get("current_zr_lord_level") or spirit.get("current_active_level") or ""
    if fortune:
        summary["zr_fortune_current_lord"] = fortune.get("current_zr_lord") or fortune.get("current_level_ruler") or ""
        summary["zr_fortune_current_lord_level"] = fortune.get("current_zr_lord_level") or fortune.get("current_active_level") or ""
    return summary


def calculate_classical(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    birth_dt = moment_to_local_datetime(birth["moment"])
    reference_dt = moment_to_local_datetime(request["reference"])
    birth_jd, birth_utc = moment_to_jd(birth["moment"])
    _, reference_utc = moment_to_jd(request["reference"])
    timezone_str = str(birth["moment"].get("timezone", ""))
    latitude = float(birth["latitude"])
    longitude = float(birth["longitude"])
    house_system = birth.get("houseSystem", "whole_sign")
    zodiac = birth.get("zodiac", "tropical")
    bounds_system = birth.get("boundsSystem", "egyptian")
    triplicity_system = birth.get("triplicitySystem", "dorothean")
    aspect_orb = float(request.get("aspectOrb", 3.0))
    sidereal = set_zodiac_mode(zodiac, warnings)

    snapshot = classical_snapshot(
        birth_jd,
        latitude,
        longitude,
        house_system,
        sidereal,
        bounds_system,
        triplicity_system,
        aspect_orb,
        warnings,
    )
    is_day = snapshot["is_day"]
    planet_rows = snapshot["planets"]
    planet_positions = snapshot["planet_positions"]
    lot_rows = snapshot["lots"]
    main_lots = [row for row in lot_rows if row.get("lot_group") != "experimental"]
    experimental_lots = [row for row in lot_rows if row.get("lot_group") == "experimental"]
    natal_cusps = [h["cusp_longitude"] for h in snapshot["houses"]] if snapshot["houses"] else []

    fortune_lot = next((row for row in main_lots if row["id"] == "fortune"), None)
    spirit_lot = next((row for row in main_lots if row["id"] == "spirit"), None)
    asc_row = next(row for row in snapshot["angles"] if row["id"] == "ASC")
    natal_asc_lon = asc_row["longitude"]

    profection = profection_summary(birth_dt, reference_dt, natal_asc_lon, planet_rows)
    firdaria = firdaria_summary(birth_dt, reference_dt, is_day)

    firdaria_ruler_id = "SUN"
    ruler_map: dict[str, str] = {}
    for bid in ["SUN","MOON","MERCURY","VENUS","MARS","JUPITER","SATURN","NORTH_NODE","SOUTH_NODE"]:
        name = "北交点" if bid == "NORTH_NODE" else ("南交点" if bid == "SOUTH_NODE" else BODY_REGISTRY[bid].name)
        ruler_map[name] = bid
    firdaria_ruler_id = ruler_map.get(firdaria.get("ruler", ""), "")
    if firdaria_ruler_id:
        firdaria_house = next((r["house"] for r in planet_rows if r["id"] == firdaria_ruler_id), 0)
        firdaria["activated_houses"] = [firdaria_house] if firdaria_house else []
    decennials = decennials_summary(birth_dt, reference_dt, is_day)
    zodiacal_releasing = [
        zodiacal_releasing_summary(spirit_lot, birth_dt, reference_dt),
        zodiacal_releasing_summary(fortune_lot, birth_dt, reference_dt),
    ]

    returns = [
        return_summary(
            body_id,
            birth_dt,
            reference_dt,
            planet_positions[body_id]["longitude"],
            planet_positions,
            latitude,
            longitude,
            sidereal,
            house_system,
            bounds_system,
            triplicity_system,
            aspect_orb,
            warnings,
            natal_asc_lon=natal_asc_lon,
            natal_cusps=natal_cusps,
        )
        for body_id in ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]
    ]

    # Filter returns by return_mode
    return_mode = request.get("returnMode", "full")
    if return_mode not in {"full", "compact", "relationship", "study"}:
        return_mode = "full"
    if return_mode != "full":
        # Always include Solar + Lunar
        keep_ids = {"SUN", "MOON"}
        prof_lord_id = profection.get("lordId", "")
        if return_mode == "compact":
            # Add profection lord's return
            if prof_lord_id and prof_lord_id in BODY_REGISTRY:
                keep_ids.add(prof_lord_id)
        elif return_mode == "relationship":
            keep_ids |= {"VENUS"}
        elif return_mode == "study":
            keep_ids |= {"MERCURY", "JUPITER"}
        returns = [r for r in returns if r["body_id"] in keep_ids]

    antiscia = calculate_antiscia(planet_rows, planet_positions, aspect_orb)
    section_errors: dict[str, str] = {}

    primary_directions: list[dict[str, Any]] = []
    try:
        from astro_backend_primary_directions import calculate_primary_directions
        primary_directions = calculate_primary_directions(
            birth_jd, birth_dt, latitude, longitude, house_system, sidereal, warnings,
            reference_dt=reference_dt,
        )
    except Exception as exc:
        warnings.append(f"Primary Directions 计算失败：{exc}")
        section_errors["primary_directions"] = str(exc)

    circumambulations: list[dict[str, Any]] = []
    try:
        from astro_backend_circumambulations import calculate_circumambulations
        circumambulations = [calculate_circumambulations(
            natal_asc_lon, birth_dt, bounds_system, max_age=120,
            reference_dt=reference_dt,
        )]
    except Exception as exc:
        warnings.append(f"Circumambulations 计算失败：{exc}")
        section_errors["circumambulations"] = str(exc)

    prenatal_syzygy: dict[str, Any] = {}
    try:
        prenatal_syzygy = calculate_prenatal_syzygy(birth_jd, birth_dt, warnings, sidereal=sidereal)
    except Exception as exc:
        warnings.append(f"Prenatal Syzygy 计算失败：{exc}")
        section_errors["prenatal_syzygy"] = str(exc)

    fortune_lot = next((row for row in lot_rows if row["id"] == "fortune"), None)
    spirit_lot = next((row for row in lot_rows if row["id"] == "spirit"), None)
    fortune_lon = fortune_lot["longitude"] if fortune_lot else 0.0
    spirit_lon = spirit_lot["longitude"] if spirit_lot else 0.0

    almuten: dict[str, Any] = {}
    try:
        angle_dict: dict[str, float] = {r["id"]: r["longitude"] for r in snapshot["angles"]}
        almuten = calculate_almuten_figuris(
            angle_dict, planet_positions, fortune_lon,
            prenatal_syzygy or {"longitude": 0.0}, is_day, bounds_system, triplicity_system,
        )
    except Exception as exc:
        warnings.append(f"Almuten Figuris 计算失败：{exc}")
        section_errors["almuten_figuris"] = str(exc)

    hyleg: dict[str, Any] = {}
    try:
        hyleg = calculate_hyleg_alcocoden(
            birth_jd, angle_dict, planet_positions,
            fortune_lon, spirit_lon, natal_cusps, is_day,
            bounds_system, triplicity_system, warnings, sidereal=sidereal,
        )
    except Exception as exc:
        warnings.append(f"Hyleg/Alcocoden 计算失败：{exc}")
        section_errors["hyleg_alcocoden"] = str(exc)

    # Medieval deep-dive computations
    medieval: dict[str, Any] = {}
    try:
        # Triplicity rulers of the sect light
        light_trip = sect_light_triplicity_rulers(
            planet_positions.get("SUN", {}).get("longitude", 0.0),
            planet_positions.get("MOON", {}).get("longitude", 0.0),
            is_day, natal_asc_lon, planet_rows,
            triplicity_system=triplicity_system,
        )
        medieval["sect_light_triplicity"] = light_trip

        # Kurios determination
        medieval["kurios"] = determine_kurios(
            natal_asc_lon, is_day, light_trip, almuten,
            profection.get("lordId"), planet_rows,
        )

        # Profection + Solar Return synthesis
        # Use the Sun's actual solar return chart (current_cycle_return)
        # to analyze the Lord of the Year in the return chart context.
        sr_snapshot = None
        for ret in returns:
            if ret.get("body_id") == "SUN":
                sr_snapshot = ret.get("current_cycle_return")
                break
        if profection and sr_snapshot:
            medieval["profection_sr_synthesis"] = profection_solar_return_synthesis(
                profection, sr_snapshot, natal_asc_lon, planet_rows, is_day,
            )
    except Exception as exc:
        warnings.append(f"中世纪技法计算失败：{exc}")
        section_errors["medieval"] = str(exc)

    timing = {
        "profection": profection,
        "firdaria": firdaria,
        "decennials": decennials,
        "zodiacal_releasing": zodiacal_releasing,
        "_method": "Hellenistic_time_lords",
        "_source_tradition": "Hellenistic",
        "timeline": timing_timeline(profection, firdaria, decennials, zodiacal_releasing, returns, birth_dt, reference_dt),
    }

    # Build activated lord focus
    activated_lord_focus: dict[str, Any] | None = None
    prof_lord_id = profection.get("lordId") or ""
    prof_lord_name = profection.get("lord") or ""
    if prof_lord_id:
        lord_return = next((r for r in returns if r["body_id"] == prof_lord_id), None)
        lord_natal = next((p for p in planet_rows if p["id"] == prof_lord_id), None)
        activated_lord_focus = {
            "lord_id": prof_lord_id,
            "lord_name": prof_lord_name,
            "natal_condition": lord_natal.get("score_label", "") if lord_natal else "",
            "natal_score": lord_natal.get("score", 0) if lord_natal else 0,
            "natal_house": lord_natal.get("house", 0) if lord_natal else 0,
            "return_title": lord_return["title"] if lord_return else None,
            "return_exact_local": (lord_return.get("current_cycle_return") or {}).get("exact_local") if lord_return else None,
            "keywords": {
                "SUN": "自我、权威、 vitality",
                "MOON": "情绪、家庭、习惯",
                "MERCURY": "沟通、学习、旅行",
                "VENUS": "关系、价值、美感",
                "MARS": "行动、竞争、冲突",
                "JUPITER": "扩张、好运、智慧",
                "SATURN": "责任、限制、结构",
            }.get(prof_lord_id, ""),
        }

    # Birthday transition detection
    birthday_transition: dict[str, Any] | None = None
    solar_return = next((r for r in returns if r["body_id"] == "SUN"), None)
    if solar_return:
        current_sr = solar_return.get("current_cycle_return")
        next_sr = solar_return.get("next_return")
        prof_start_local = profection.get("start_local", "")
        prof_end_local = profection.get("end_local", "")
        if current_sr and next_sr:
            # A transition window exists when profection has turned over to the
            # new age, but this year's exact Solar Return still falls on a
            # later calendar date.
            try:
                sr_exact = datetime.strptime(current_sr["exact_local"], "%Y-%m-%d %H:%M")
                prof_start = datetime.strptime(prof_start_local, "%Y-%m-%d %H:%M")
                if sr_exact.date() < prof_start.date():
                    birthday_transition = {
                        "detected": True,
                        "note": "年小限已换岁，但 Solar Return 尚未精确。此为生日过渡窗口。",
                        "profection_age": profection.get("age"),
                        "profection_start": prof_start_local,
                        "current_solar_return": current_sr["exact_local"],
                        "next_solar_return": next_sr.get("exact_local", ""),
                    }
            except (ValueError, TypeError, KeyError):
                pass

    # Top signatures
    top_signatures: list[dict[str, Any]] = []

    # Best aspects (closest orb)
    all_aspects = snapshot.get("aspects", [])
    sorted_aspects = sorted(all_aspects, key=lambda a: a.get("orb") if a.get("orb") is not None else 999)
    for a in sorted_aspects[:5]:
        top_signatures.append({
            "type": "aspect",
            "description": f"{a.get('body_a', '')} {a.get('aspect', '')} {a.get('body_b', '')}",
            "orb": a.get("orb"),
            "strength": "tight" if a.get("orb") is not None and abs(a["orb"]) < 1.0 else "moderate",
        })

    # Current cycle returns
    for r in returns:
        curr = r.get("current_cycle_return")
        if curr:
            top_signatures.append({
                "type": "return",
                "description": f"{r['title']} — {curr['exact_local']}",
                "orb": None,
                "strength": "active",
            })

    # Profection lord highlight
    if activated_lord_focus:
        top_signatures.append({
            "type": "profection_lord",
            "description": f"年主 {activated_lord_focus['lord_name']}（评分 {activated_lord_focus['natal_score']}，{activated_lord_focus['natal_condition']}）",
            "orb": None,
            "strength": "active",
        })

    # Top primary directions (closest to reference age)
    try:
        ref_age = max(0, (reference_dt - birth_dt).days / 365.2425)
    except Exception:
        ref_age = 0
    if primary_directions:
        closest_directions = _closest_primary_directions(primary_directions, ref_age)
        for pd_entry in closest_directions:
            top_signatures.append({
                "type": "primary_direction",
                "description": f"{pd_entry['promissor']} → {pd_entry['significator']} {pd_entry['aspect_name']} @ {pd_entry['age_from_abs_arc']:.1f}y",
                "orb": None,
                "strength": "approaching" if pd_entry.get("age_from_abs_arc", 0) > ref_age else "past",
            })
    declination_aspects = find_declination_aspects(planet_rows, id_key="id")
    star_positions = compute_star_positions(birth_jd, warnings=warnings, sidereal=sidereal)
    natal_star_conj = find_star_conjunctions(
        [{"body_id": r["id"], "longitude": r["longitude"]} for r in planet_rows],
        star_positions,
    )
    house_system_note = (
        "宫头为各星座 0°（Whole Sign），角点度数为实际计算值"
        if house_system == "whole_sign"
        else "宫头与角点均为 Swiss Ephemeris 实际计算值"
    )
    return {
        "meta": {
            "birth_utc": birth_utc,
            "birth_local": format_local(birth_dt),
            "reference_utc": reference_utc,
            "reference_local": format_local(reference_dt),
            "timezone": timezone_str,
            "latitude": latitude,
            "longitude": longitude,
            "sect": "昼盘" if is_day else "夜盘",
            "house_system": snapshot["house_label"],
            "house_system_note": house_system_note,
            "zodiac": zodiac_mode_label(zodiac),
            "bounds_system": "Ptolemaic" if bounds_system == "ptolemaic" else "Egyptian",
            "triplicity_system": "Ptolemaic" if triplicity_system == "ptolemaic" else "Dorothean",
            "aspect_orb": aspect_orb,
            "ephemeris": ", ".join(sorted(snapshot["ephemerides"])) if snapshot["ephemerides"] else "unknown",
        },
        "angles": snapshot["angles"],
        "houses": snapshot["houses"],
        "planets": planet_rows,
        "lots": main_lots,
        "experimental_lots": experimental_lots,
        "aspects": snapshot["aspects"],
        "receptions": snapshot["receptions"],
        "antiscia": antiscia,
        "primary_directions": primary_directions,
        "circumambulations": circumambulations,
        "timing": timing,
        "top_signatures": top_signatures[:10],
        "birthday_transition": birthday_transition,
        "activated_lord_focus": activated_lord_focus,
        "declination_aspects": declination_aspects,
        "natal_star_conjunctions": natal_star_conj,
        "medieval": medieval,
        "planetary_returns": returns,
        "prenatal_syzygy": prenatal_syzygy,
        "almuten_figuris": almuten,
        "hyleg_alcocoden": hyleg,
        "warnings": warnings,
        "section_errors": section_errors if section_errors else None,
        "ambiguity": {
            "technique_rulers": {
                "profection_lord": profection.get("lord", ""),
                "firdaria_lord": firdaria.get("ruler", ""),
                "decennials_lord": decennials.get("ruler", ""),
                # Legacy single fields keep L1 major lords (not finest level).
                "zr_spirit": zodiacal_releasing[0].get("ruler", "") if len(zodiacal_releasing) > 0 else "",
                "zr_fortune": zodiacal_releasing[1].get("ruler", "") if len(zodiacal_releasing) > 1 else "",
                "circumambulation_lord": circumambulations[0].get("current_ruler", "") if circumambulations else "",
                "almuten_figuris": almuten.get("winner", "") if almuten else "",
                "hyleg": hyleg.get("hyleg", {}).get("selected", "") if hyleg else "",
            },
            "technique_lords_summary": _zr_technique_lords_summary(zodiacal_releasing),
            "conflicting_signals": [],
            "confidence": "medium",
        },
        "calculation_assumptions": {
            "cazimi_orb_arcmin": 17.0,
            "combust_orb_deg": 8.5,
            "under_beams_orb_deg": 15.0,
            "naibod_rate": 0.9856,
            "primary_directions_method": "Naibod",
            "modern_planets_excluded_from_scoring": True,
            "scoring_includes_conditioning": True,
            "sign_based_receptions_downgraded": True,
            "return_schema": "previous_return/current_cycle_return/next_return",
        },
    }


def _is_finite_number(value: Any) -> bool:
    return (
        not isinstance(value, bool)
        and isinstance(value, (int, float))
        and math.isfinite(float(value))
    )


def _validate_horary_moment(moment: dict[str, Any], invalid: list[str]) -> None:
    integer_fields = ("year", "month", "day", "hour", "minute")
    wrong_types = [
        field
        for field in integer_fields
        if isinstance(moment.get(field), bool) or not isinstance(moment.get(field), int)
    ]
    if wrong_types:
        invalid.append(
            "chart.moment fields must be integers: " + ", ".join(wrong_types)
        )

    timezone_value = moment.get("timezone")
    if not isinstance(timezone_value, str) or not timezone_value.strip():
        invalid.append("chart.moment.timezone must be a non-empty string")

    fold = moment.get("fold")
    if fold is not None and (isinstance(fold, bool) or not isinstance(fold, int) or fold not in (0, 1)):
        invalid.append("chart.moment.fold must be 0 or 1")

    if wrong_types or not isinstance(timezone_value, str) or not timezone_value.strip():
        return

    try:
        moment_to_local_datetime(moment)
    except (OverflowError, TypeError, ValueError) as exc:
        invalid.append(f"chart.moment is invalid: {exc}")


def validate_required_fields(request: dict[str, Any]) -> dict[str, Any] | None:
    """Return the structured input error for missing or invalid fields."""
    mode = request.get("mode", "")
    supported_modes = {
        "moment", "classical", "vedic", "horary", "kp_horary", "scan", "rectify", "rectify_evidence",
        "synastry", "composite", "davison", "progression", "solar_arc", "harmonic",
        "modern_return", "modern_timing", "midpoint", "progressed_composite",
        "relocation", "modern_cycles", "astrocartography", "local_space",
        "declination_timing", "retrograde_cycles", "classical_visibility",
        "planetary_synodic", "hellenistic_condition_audit", "draconic_heliocentric", "classical_derivatives",
        "time_lords_extended",
        "method_families",
        "primary_directions_audit",
        "distributions_pd",
        "prenatal_parans",
        "orbital_dial",
        "mundane_electional",
    }
    if mode not in supported_modes:
        return {"error": f"不支持的 mode：{mode or '<empty>'}", "mode": mode}
    required_by_mode: dict[str, list[str]] = {
        "mundane_electional": ["start", "end", "location"],
        "orbital_dial": ["birth"],
        "prenatal_parans": ["birth"],
        "distributions_pd": ["birth"],
        "primary_directions_audit": ["birth"],
        "method_families": ["birth", "reference"],
        "time_lords_extended": ["birth", "reference"],
        "classical": ["birth", "reference"],
        "vedic": ["birth"],
        "horary": ["chart"],
        "kp_horary": ["chart", "horary_number"],
        "scan": ["start", "end"],
        "rectify": ["birth_date", "center_time"],
        "rectify_evidence": ["birth", "events", "display_timezone"],
        "synastry": ["person_a", "person_b"],
        "composite": ["person_a", "person_b"],
        "davison": ["person_a", "person_b"],
        "progression": ["birth", "reference"],
        "solar_arc": ["birth", "reference"],
        "harmonic": ["birth"],
        "modern_return": ["birth", "reference"],
        "modern_timing": ["birth", "start", "end", "display_timezone", "techniques"],
        "midpoint": ["birth", "point_set", "focus_point_ids", "activation_sources"],
        "progressed_composite": ["person_a", "person_b", "reference", "point_set"],
        "relocation": ["birth", "relocation"],
        "modern_cycles": ["start", "end", "display_timezone"],
        "astrocartography": ["moment"],
        "local_space": ["moment", "location"],
        "declination_timing": ["birth", "start", "end", "display_timezone"],
        "retrograde_cycles": ["start", "end", "display_timezone"],
        "classical_visibility": ["moment", "location"],
        "planetary_synodic": ["start", "end", "display_timezone", "pair"],
        "hellenistic_condition_audit": ["birth"],
        "draconic_heliocentric": ["birth"],
        "classical_derivatives": ["birth"],
    }
    default_required = ["natal", "transit"]
    required = required_by_mode.get(mode, default_required)
    missing = [f for f in required if f not in request]
    invalid: list[str] = []

    def validate_exact_person(value: Any, prefix: str) -> None:
        if not isinstance(value, dict):
            invalid.append(f"{prefix} must be an object")
            return
        moment = value.get("moment")
        exact_fields = ("year", "month", "day", "hour", "minute", "timezone")
        if not isinstance(moment, dict):
            missing.append(f"{prefix}.moment")
        else:
            for field in exact_fields:
                if field not in moment:
                    missing.append(f"{prefix}.moment.{field}")
            if all(field in moment for field in exact_fields):
                try:
                    parsed = moment_to_local_datetime(moment)
                    if not 1800 <= parsed.year <= 2100:
                        invalid.append(f"{prefix}.moment.year must be in [1800, 2100]")
                except Exception as exc:
                    invalid.append(f"{prefix}.moment is invalid: {exc}")
        for field, lower, upper in (("latitude", -90.0, 90.0), ("longitude", -180.0, 180.0)):
            if field not in value:
                missing.append(f"{prefix}.{field}")
                continue
            coordinate = value.get(field)
            if (
                isinstance(coordinate, bool)
                or not isinstance(coordinate, (int, float))
                or not math.isfinite(float(coordinate))
                or not lower <= float(coordinate) <= upper
            ):
                invalid.append(f"{prefix}.{field} must be a finite number in [{lower:g}, {upper:g}]")

    def validate_aspect_specs(
        value: Any,
        prefix: str,
        *,
        require_nonempty: bool = False,
    ) -> None:
        if not isinstance(value, list):
            invalid.append(f"{prefix} must be an array")
            return
        if require_nonempty and not value:
            invalid.append(f"{prefix} must be non-empty when event_types contains aspect")
        seen_aspect_ids: set[str] = set()
        for aspect_index, aspect in enumerate(value):
            aspect_prefix = f"{prefix}[{aspect_index}]"
            if not isinstance(aspect, dict):
                invalid.append(f"{aspect_prefix} must be an object")
                continue
            aspect_id = aspect.get("id")
            name = aspect.get("name")
            angle = aspect.get("angle")
            orb = aspect.get("orb")
            if not isinstance(aspect_id, str) or not aspect_id.strip():
                invalid.append(f"{aspect_prefix}.id must be a non-empty string")
            elif aspect_id in seen_aspect_ids:
                invalid.append(f"{aspect_prefix}.id is duplicated: {aspect_id}")
            else:
                seen_aspect_ids.add(aspect_id)
            if not isinstance(name, str) or not name.strip():
                invalid.append(f"{aspect_prefix}.name must be a non-empty string")
            if (
                isinstance(angle, bool)
                or not isinstance(angle, (int, float))
                or not math.isfinite(float(angle))
                or not 0 <= float(angle) <= 180
            ):
                invalid.append(f"{aspect_prefix}.angle must be a finite number in [0, 180]")
            if (
                isinstance(orb, bool)
                or not isinstance(orb, (int, float))
                or not math.isfinite(float(orb))
                or not 0 <= float(orb) <= 15
            ):
                invalid.append(f"{aspect_prefix}.orb must be a finite number in [0, 15]")
    if "birth" in request:
        birth = request["birth"]
        if not isinstance(birth, dict):
            invalid.append("birth must be an object")
        else:
            for f in ("latitude", "longitude"):
                if f not in birth:
                    missing.append(f"birth.{f}")
    if mode == "classical" and "reference" in request:
        ref = request["reference"]
        for f in ("year", "month", "day"):
            if f not in ref:
                missing.append(f"reference.{f}")
    if mode == "moment":
        for field in ("natal", "transit"):
            moment = request.get(field)
            if not isinstance(moment, dict):
                invalid.append(f"{field} must be an object with an exact moment")
                continue
            for key in ("year", "month", "day", "hour", "minute", "timezone"):
                if key not in moment:
                    missing.append(f"{field}.{key}")
        if isinstance(request.get("birth"), dict):
            birth_moment = request["birth"].get("moment")
            if not isinstance(birth_moment, dict):
                missing.append("birth.moment")
            else:
                for key in ("year", "month", "day", "hour", "minute", "timezone"):
                    if key not in birth_moment:
                        missing.append(f"birth.moment.{key}")
    if mode in {"horary", "kp_horary"} and "chart" in request:
        chart = request["chart"]
        if not isinstance(chart, dict):
            invalid.append("chart must be an object")
        else:
            moment = chart.get("moment")
            if not isinstance(moment, dict):
                missing.append("chart.moment")
            else:
                moment_fields = ("year", "month", "day", "hour", "minute", "timezone")
                missing_moment_fields = []
                for field in moment_fields:
                    if field not in moment:
                        missing.append(f"chart.moment.{field}")
                        missing_moment_fields.append(field)
                if not missing_moment_fields:
                    _validate_horary_moment(moment, invalid)
            for field in ("latitude", "longitude"):
                if field not in chart:
                    missing.append(f"chart.{field}")
            latitude = chart.get("latitude")
            longitude = chart.get("longitude")
            if latitude is not None and (not _is_finite_number(latitude) or not -90 <= float(latitude) <= 90):
                invalid.append("chart.latitude must be a number in [-90, 90]")
            if longitude is not None and (not _is_finite_number(longitude) or not -180 <= float(longitude) <= 180):
                invalid.append("chart.longitude must be a number in [-180, 180]")

            if mode == "horary":
                option_contracts = {
                    "houseSystem": ("regiomontanus", ALL_HOUSE_SYSTEMS),
                    "zodiac": ("tropical", ALL_ZODIACS),
                    "boundsSystem": ("egyptian", ALL_BOUNDS_SYSTEMS),
                    "triplicitySystem": ("dorothean", ALL_TRIPLICITY_SYSTEMS),
                }
                for field, (default, allowed) in option_contracts.items():
                    value = chart.get(field, default)
                    if not isinstance(value, str) or value not in allowed:
                        invalid.append(
                            f"chart.{field} must be one of: {', '.join(allowed)}"
                        )
        if mode == "horary":
            question_text = request.get("questionText")
            if not isinstance(question_text, str) or not question_text.strip():
                missing.append("questionText")
            aspect_orb = request.get("aspectOrb", 3.0)
            if not _is_finite_number(aspect_orb) or not 0 <= float(aspect_orb) <= 10:
                invalid.append("aspectOrb must be a number in [0, 10]")
            packet_version = str(
                request.get("packetVersion")
                or request.get("packet_version")
                or "2"
            ).strip().lower()
            if packet_version not in HORARY_V1_PACKET_VERSIONS | HORARY_V2_PACKET_VERSIONS:
                invalid.append("packetVersion is unsupported; use 2 (default) or 1/legacy")
        else:
            number = request.get("horary_number")
            if isinstance(number, bool) or not isinstance(number, int) or not 1 <= number <= 249:
                invalid.append("horary_number must be an integer in [1, 249]")
            focus_house = request.get("focus_house", 1)
            if isinstance(focus_house, bool) or not isinstance(focus_house, int) or not 1 <= focus_house <= 12:
                invalid.append("focus_house must be an integer in [1, 12]")
            node_mode = request.get("node_mode", "mean")
            if not isinstance(node_mode, str) or node_mode not in {"mean", "true"}:
                invalid.append("node_mode must be mean or true")
            question_text = request.get("question_text")
            if not isinstance(question_text, str) or not question_text.strip():
                missing.append("question_text")
    _PERSON_MOMENT_FIELDS = ("year", "month", "day", "hour", "minute", "timezone")
    if mode == "rectify_evidence" and "birth" in request:
        validate_exact_person(request["birth"], "birth")
    if mode in ("synastry", "composite", "davison", "progressed_composite"):
        for side in ("person_a", "person_b"):
            if side in request:
                validate_exact_person(request[side], side)
    if mode == "progressed_composite":
        reference = request.get("reference")
        if isinstance(reference, dict):
            for field in _PERSON_MOMENT_FIELDS:
                if field not in reference:
                    missing.append(f"reference.{field}")
            if all(field in reference for field in _PERSON_MOMENT_FIELDS):
                try:
                    parsed_reference = moment_to_local_datetime(reference)
                    if not 1800 <= parsed_reference.year <= 2100:
                        invalid.append("reference.year must be in [1800, 2100]")
                except Exception as exc:
                    invalid.append(f"reference is invalid: {exc}")
        elif "reference" in request:
            invalid.append("reference must be an object with an exact moment")

        progressed_point_set = request.get("point_set")
        if isinstance(progressed_point_set, dict):
            for field in ("angle_ids", "angles", "house_cusps", "lot_ids", "midpoint_pairs"):
                value = progressed_point_set.get(field, [])
                if value not in (None, []):
                    invalid.append(f"point_set.{field} is not supported by progressed_composite v1")
        validate_aspect_specs(request.get("aspects", []), "aspects")
    if mode in ("progression", "solar_arc", "harmonic", "vedic", "modern_return", "modern_timing", "midpoint", "relocation", "declination_timing"):
        if "birth" in request:
            b = request["birth"]
            if isinstance(b, dict):
                moment = b.get("moment")
                if not isinstance(moment, dict):
                    missing.append("birth.moment")
                else:
                    required_fields = ("year", "month", "day", "hour", "minute")
                    if mode != "vedic":
                        required_fields = _PERSON_MOMENT_FIELDS
                    for f in required_fields:
                        if f not in moment:
                            missing.append(f"birth.moment.{f}")
        # Shared exact-reference checks for time-based modern modes (not map modes).
        reference_field = "reference" if "reference" in request else None
        if reference_field is not None:
            ref = request[reference_field]
            ref_fields = ("year", "month", "day", "hour", "minute")
            if mode != "vedic":
                ref_fields = ("year", "month", "day", "hour", "minute", "timezone")
            if not isinstance(ref, dict):
                invalid.append("reference must be an object with an exact moment")
            else:
                for f in ref_fields:
                    if f not in ref:
                        missing.append(f"reference.{f}")
    if mode == "relocation":
        relocation = request.get("relocation")
        if not isinstance(relocation, dict):
            invalid.append("relocation must be an object")
        else:
            for field in ("name", "latitude", "longitude", "timezone"):
                if field not in relocation:
                    missing.append(f"relocation.{field}")
            latitude = relocation.get("latitude")
            longitude = relocation.get("longitude")
            if latitude is not None and (
                isinstance(latitude, bool)
                or not isinstance(latitude, (int, float))
                or not math.isfinite(float(latitude))
                or not -90 <= float(latitude) <= 90
            ):
                invalid.append("relocation.latitude must be a finite number in [-90, 90]")
            if longitude is not None and (
                isinstance(longitude, bool)
                or not isinstance(longitude, (int, float))
                or not math.isfinite(float(longitude))
                or not -180 <= float(longitude) <= 180
            ):
                invalid.append("relocation.longitude must be a finite number in [-180, 180]")
            timezone_text = relocation.get("timezone")
            if timezone_text is not None and (not isinstance(timezone_text, str) or not timezone_text.strip()):
                invalid.append("relocation.timezone must be a non-empty string")
    if mode == "modern_cycles":
        for field in ("start", "end"):
            moment = request.get(field)
            if not isinstance(moment, dict):
                invalid.append(f"{field} must be an object with an exact moment")
                continue
            for key in _PERSON_MOMENT_FIELDS:
                if key not in moment:
                    missing.append(f"{field}.{key}")
        display_timezone = request.get("display_timezone")
        if display_timezone is not None and (not isinstance(display_timezone, str) or not display_timezone.strip()):
            invalid.append("display_timezone must be a non-empty string")
        visibility = request.get("visibility", "global")
        if visibility not in (None, "global", "location"):
            invalid.append("visibility must be global or location")
        if visibility == "location":
            location = request.get("location")
            if not isinstance(location, dict):
                missing.append("location")
            else:
                for field in ("latitude", "longitude"):
                    if field not in location:
                        missing.append(f"location.{field}")
    if mode == "declination_timing":
        birth = request.get("birth")
        if isinstance(birth, dict):
            latitude = birth.get("latitude")
            longitude = birth.get("longitude")
            if isinstance(latitude, bool) or not isinstance(latitude, (int, float)) or not math.isfinite(float(latitude)) or not -90 <= float(latitude) <= 90:
                invalid.append("birth.latitude must be a finite number in [-90, 90]")
            if isinstance(longitude, bool) or not isinstance(longitude, (int, float)) or not math.isfinite(float(longitude)) or not -180 <= float(longitude) <= 180:
                invalid.append("birth.longitude must be a finite number in [-180, 180]")
        parsed_moments: dict[str, datetime] = {}
        for field in ("start", "end"):
            moment = request.get(field)
            if not isinstance(moment, dict):
                invalid.append(f"{field} must be an object with an exact moment")
                continue
            for key in _PERSON_MOMENT_FIELDS:
                if key not in moment:
                    missing.append(f"{field}.{key}")
            if all(key in moment for key in _PERSON_MOMENT_FIELDS):
                try:
                    parsed_moments[field] = moment_to_local_datetime(moment)
                except Exception as exc:
                    invalid.append(f"{field} is invalid: {exc}")
        if "start" in parsed_moments and "end" in parsed_moments:
            if parsed_moments["end"] <= parsed_moments["start"]:
                invalid.append("end must be later than start")
            for field, value in parsed_moments.items():
                if not 1800 <= value.year <= 2100:
                    invalid.append(f"{field}.year must be in [1800, 2100]")
        display_timezone = request.get("display_timezone")
        if not isinstance(display_timezone, str) or not display_timezone.strip():
            invalid.append("display_timezone must be a non-empty string")
        event_types = request.get("event_types")
        if event_types is not None:
            if not isinstance(event_types, list) or not event_types:
                invalid.append("event_types must be a non-empty array when provided")
            else:
                supported_decl_events = {
                    "parallel", "contraparallel", "oob_entry", "oob_exit", "declination_station",
                }
                for index, item in enumerate(event_types):
                    if item not in supported_decl_events:
                        invalid.append(f"event_types[{index}] is unsupported: {item}")
        moving_body_ids = request.get("moving_body_ids")
        if moving_body_ids is not None:
            if not isinstance(moving_body_ids, list) or not moving_body_ids:
                invalid.append("moving_body_ids must be a non-empty array when provided")
            else:
                for index, item in enumerate(moving_body_ids):
                    if not isinstance(item, str) or not item.strip():
                        invalid.append(f"moving_body_ids[{index}] must be a non-empty string")
        declination_orb = request.get("declination_orb")
        if declination_orb is not None and (
            isinstance(declination_orb, bool)
            or not isinstance(declination_orb, (int, float))
            or not math.isfinite(float(declination_orb))
            or not 0 <= float(declination_orb) <= 5
        ):
            invalid.append("declination_orb must be a finite number in [0, 5]")
    if mode == "retrograde_cycles":
        parsed_moments: dict[str, datetime] = {}
        for field in ("start", "end"):
            moment = request.get(field)
            if not isinstance(moment, dict):
                invalid.append(f"{field} must be an object with an exact moment")
                continue
            for key in _PERSON_MOMENT_FIELDS:
                if key not in moment:
                    missing.append(f"{field}.{key}")
            if all(key in moment for key in _PERSON_MOMENT_FIELDS):
                try:
                    parsed_moments[field] = moment_to_local_datetime(moment)
                except Exception as exc:
                    invalid.append(f"{field} is invalid: {exc}")
        if "start" in parsed_moments and "end" in parsed_moments:
            if parsed_moments["end"] <= parsed_moments["start"]:
                invalid.append("end must be later than start")
        display_timezone = request.get("display_timezone")
        if not isinstance(display_timezone, str) or not display_timezone.strip():
            invalid.append("display_timezone must be a non-empty string")
        body_ids = request.get("body_ids")
        if body_ids is not None:
            if not isinstance(body_ids, list) or not body_ids:
                invalid.append("body_ids must be a non-empty array when provided")
            else:
                supported = {
                    "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN",
                    "URANUS", "NEPTUNE", "PLUTO", "CHIRON",
                }
                for index, item in enumerate(body_ids):
                    if item not in supported:
                        invalid.append(f"body_ids[{index}] is unsupported: {item}")
    if mode == "classical_visibility":
        moment = request.get("moment")
        if not isinstance(moment, dict):
            invalid.append("moment must be an object with an exact moment")
        else:
            for key in _PERSON_MOMENT_FIELDS:
                if key not in moment:
                    missing.append(f"moment.{key}")
        location = request.get("location")
        if not isinstance(location, dict):
            invalid.append("location must be an object")
        else:
            for field in ("latitude", "longitude"):
                if field not in location:
                    missing.append(f"location.{field}")
            latitude = location.get("latitude")
            longitude = location.get("longitude")
            if latitude is not None and (
                isinstance(latitude, bool)
                or not isinstance(latitude, (int, float))
                or not math.isfinite(float(latitude))
                or not -90 <= float(latitude) <= 90
            ):
                invalid.append("location.latitude must be a finite number in [-90, 90]")
            if longitude is not None and (
                isinstance(longitude, bool)
                or not isinstance(longitude, (int, float))
                or not math.isfinite(float(longitude))
                or not -180 <= float(longitude) <= 180
            ):
                invalid.append("location.longitude must be a finite number in [-180, 180]")
    if mode in ("astrocartography", "local_space"):
        moment = request.get("moment")
        if not isinstance(moment, dict):
            invalid.append("moment must be an object with an exact moment")
        else:
            for key in _PERSON_MOMENT_FIELDS:
                if key not in moment:
                    missing.append(f"moment.{key}")
        if mode == "local_space":
            location = request.get("location")
            if not isinstance(location, dict):
                invalid.append("location must be an object")
            else:
                for field in ("latitude", "longitude"):
                    if field not in location:
                        missing.append(f"location.{field}")
    if mode == "midpoint":
        birth = request.get("birth")
        if isinstance(birth, dict):
            latitude = birth.get("latitude")
            longitude = birth.get("longitude")
            if isinstance(latitude, bool) or not isinstance(latitude, (int, float)) or not math.isfinite(float(latitude)) or not -90 <= float(latitude) <= 90:
                invalid.append("birth.latitude must be a finite number in [-90, 90]")
            if isinstance(longitude, bool) or not isinstance(longitude, (int, float)) or not math.isfinite(float(longitude)) or not -180 <= float(longitude) <= 180:
                invalid.append("birth.longitude must be a finite number in [-180, 180]")
            birth_moment = birth.get("moment")
            if isinstance(birth_moment, dict) and all(field in birth_moment for field in _PERSON_MOMENT_FIELDS):
                try:
                    parsed_birth = moment_to_local_datetime(birth_moment)
                    if not 1800 <= parsed_birth.year <= 2100:
                        invalid.append("birth.moment.year must be in [1800, 2100]")
                except Exception as exc:
                    invalid.append(f"birth.moment is invalid: {exc}")
        reference = request.get("reference")
        if isinstance(reference, dict) and all(field in reference for field in _PERSON_MOMENT_FIELDS):
            try:
                parsed_reference = moment_to_local_datetime(reference)
                if not 1800 <= parsed_reference.year <= 2100:
                    invalid.append("reference.year must be in [1800, 2100]")
            except Exception as exc:
                invalid.append(f"reference is invalid: {exc}")

        modulus = request.get("modulus", 360)
        if isinstance(modulus, bool) or not isinstance(modulus, (int, float)) or not math.isfinite(float(modulus)) or float(modulus) != 360.0:
            invalid.append("modulus currently only supports 360")
        activation_orb = request.get("activation_orb", 1.0)
        if isinstance(activation_orb, bool) or not isinstance(activation_orb, (int, float)) or not math.isfinite(float(activation_orb)) or not 0 <= float(activation_orb) <= 15:
            invalid.append("activation_orb must be a finite number in [0, 15]")
        if not isinstance(request.get("include_opposite_axis", True), bool):
            invalid.append("include_opposite_axis must be a boolean")

        focus_point_ids = request.get("focus_point_ids")
        if not isinstance(focus_point_ids, list):
            invalid.append("focus_point_ids must be an array")
        else:
            seen_focus_ids: set[str] = set()
            for index, point_id in enumerate(focus_point_ids):
                if not isinstance(point_id, str) or not point_id.strip():
                    invalid.append(f"focus_point_ids[{index}] must be a non-empty string")
                elif point_id in seen_focus_ids:
                    invalid.append(f"focus_point_ids contains duplicate value: {point_id}")
                else:
                    seen_focus_ids.add(point_id)

        activation_sources = request.get("activation_sources")
        supported_activation_sources = {"natal", "transit", "secondary_progression", "solar_arc"}
        if not isinstance(activation_sources, list):
            invalid.append("activation_sources must be an array")
        else:
            seen_sources: set[str] = set()
            for index, source in enumerate(activation_sources):
                if not isinstance(source, str) or source not in supported_activation_sources:
                    invalid.append(f"activation_sources[{index}] is unsupported: {source}")
                elif source in seen_sources:
                    invalid.append(f"activation_sources contains duplicate value: {source}")
                else:
                    seen_sources.add(source)
    if mode == "modern_timing":
        birth = request.get("birth")
        if isinstance(birth, dict):
            latitude = birth.get("latitude")
            longitude = birth.get("longitude")
            if isinstance(latitude, bool) or not isinstance(latitude, (int, float)) or not math.isfinite(float(latitude)) or not -90 <= float(latitude) <= 90:
                invalid.append("birth.latitude must be a finite number in [-90, 90]")
            if isinstance(longitude, bool) or not isinstance(longitude, (int, float)) or not math.isfinite(float(longitude)) or not -180 <= float(longitude) <= 180:
                invalid.append("birth.longitude must be a finite number in [-180, 180]")
            birth_moment = birth.get("moment")
            if isinstance(birth_moment, dict) and all(key in birth_moment for key in _PERSON_MOMENT_FIELDS):
                try:
                    parsed_birth = moment_to_local_datetime(birth_moment)
                    if not 1800 <= parsed_birth.year <= 2100:
                        invalid.append("birth.moment.year must be in [1800, 2100]")
                except Exception as exc:
                    invalid.append(f"birth.moment is invalid: {exc}")

        parsed_moments: dict[str, datetime] = {}
        for field in ("start", "end"):
            moment = request.get(field)
            if not isinstance(moment, dict):
                invalid.append(f"{field} must be an object with an exact moment")
                continue
            for key in _PERSON_MOMENT_FIELDS:
                if key not in moment:
                    missing.append(f"{field}.{key}")
            if all(key in moment for key in _PERSON_MOMENT_FIELDS):
                try:
                    parsed_moments[field] = moment_to_local_datetime(moment)
                except Exception as exc:
                    invalid.append(f"{field} is invalid: {exc}")
        if "start" in parsed_moments and "end" in parsed_moments:
            if parsed_moments["end"] <= parsed_moments["start"]:
                invalid.append("end must be later than start")
            for field, value in parsed_moments.items():
                if not 1800 <= value.year <= 2100:
                    invalid.append(f"{field}.year must be in [1800, 2100]")

        display_timezone = request.get("display_timezone")
        if not isinstance(display_timezone, str) or not display_timezone.strip():
            invalid.append("display_timezone must be a non-empty IANA timezone")
        else:
            try:
                ZoneInfo(display_timezone)
            except (ZoneInfoNotFoundError, ValueError) as exc:
                invalid.append(f"display_timezone is invalid: {exc}")

        confirmed = request.get("confirmed_heavy_scan", False)
        if not isinstance(confirmed, bool):
            invalid.append("confirmed_heavy_scan must be a boolean")

        target_chart = request.get("target_chart")
        target_chart_type: str | None = None
        target_point_set = request.get("target_point_set")
        target_point_set_label = "target_point_set"
        if target_chart is not None:
            if not isinstance(target_chart, dict):
                invalid.append("target_chart must be an object")
                target_point_set = None
            else:
                raw_target_chart_type = target_chart.get("type")
                if raw_target_chart_type not in {"natal", "composite", "davison"}:
                    invalid.append(
                        f"target_chart.type must be one of natal, composite, davison: {raw_target_chart_type}"
                    )
                else:
                    target_chart_type = str(raw_target_chart_type)
                if "target_point_set" in request:
                    invalid.append("target_point_set and target_chart must not both be provided")
                target_point_set = target_chart.get("point_set")
                target_point_set_label = "target_chart.point_set"
                if "point_set" not in target_chart:
                    missing.append("target_chart.point_set")
                if target_chart_type in {"composite", "davison"}:
                    for side in ("person_a", "person_b"):
                        if side not in target_chart:
                            missing.append(f"target_chart.{side}")
                        else:
                            validate_exact_person(
                                target_chart[side],
                                f"target_chart.{side}",
                            )
                    if isinstance(target_point_set, dict):
                        if target_point_set.get("lot_ids") not in (None, []):
                            invalid.append(
                                "target_chart.point_set.lot_ids is not supported for relationship timing v1"
                            )
                        if target_point_set.get("midpoint_pairs") not in (None, []):
                            invalid.append(
                                "target_chart.point_set.midpoint_pairs is not supported for relationship timing v1"
                            )
        elif "target_point_set" not in request:
            missing.append("target_point_set")

        target_node_mode = (
            str(target_point_set.get("node_mode", request.get("node_mode", "true_node")))
            if isinstance(target_point_set, dict)
            else str(request.get("node_mode", "true_node"))
        )
        if target_point_set is not None:
            invalid.extend(
                f"{target_point_set_label}: {error}"
                for error in validate_point_set(target_point_set, node_mode=target_node_mode)
            )
        if isinstance(target_point_set, dict):
            midpoint_pairs = target_point_set.get("midpoint_pairs", [])
            if not isinstance(midpoint_pairs, list):
                invalid.append(f"{target_point_set_label}.midpoint_pairs must be an array")
            else:
                seen_midpoint_pairs: set[tuple[str, str]] = set()
                for pair_index, pair in enumerate(midpoint_pairs):
                    pair_prefix = f"{target_point_set_label}.midpoint_pairs[{pair_index}]"
                    if not isinstance(pair, dict):
                        invalid.append(f"{pair_prefix} must be an object")
                        continue
                    point_a_id = pair.get("point_a_id")
                    point_b_id = pair.get("point_b_id")
                    if not isinstance(point_a_id, str) or not point_a_id.strip():
                        invalid.append(f"{pair_prefix}.point_a_id must be a non-empty string")
                    if not isinstance(point_b_id, str) or not point_b_id.strip():
                        invalid.append(f"{pair_prefix}.point_b_id must be a non-empty string")
                    if not isinstance(point_a_id, str) or not isinstance(point_b_id, str):
                        continue
                    if point_a_id == point_b_id:
                        invalid.append(f"{pair_prefix} must contain two different point IDs")
                        continue
                    canonical_pair = tuple(sorted((point_a_id, point_b_id)))
                    if canonical_pair in seen_midpoint_pairs:
                        invalid.append(
                            f"{target_point_set_label}.midpoint_pairs contains duplicate pair: {canonical_pair[0]}|{canonical_pair[1]}"
                        )
                    else:
                        seen_midpoint_pairs.add(canonical_pair)

        allowed_event_types = {
            "transit": {"aspect", "ingress", "station"},
            "secondary_progression": {"aspect", "moon_ingress", "lunation"},
            "solar_arc": {"aspect"},
        }
        techniques = request.get("techniques")
        seen_techniques: set[str] = set()
        if not isinstance(techniques, list) or not techniques:
            invalid.append("techniques must be a non-empty array")
        else:
            for index, technique in enumerate(techniques):
                prefix = f"techniques[{index}]"
                if not isinstance(technique, dict):
                    invalid.append(f"{prefix} must be an object")
                    continue
                technique_id = technique.get("id")
                if not isinstance(technique_id, str) or technique_id not in allowed_event_types:
                    invalid.append(f"{prefix}.id is unsupported: {technique_id}")
                    continue
                if technique_id in seen_techniques:
                    invalid.append(f"{prefix}.id is duplicated: {technique_id}")
                seen_techniques.add(technique_id)

                moving_ids = technique.get("moving_body_ids")
                if not isinstance(moving_ids, list) or not moving_ids:
                    invalid.append(f"{prefix}.moving_body_ids must be a non-empty array")
                    moving_ids = []
                valid_moving_ids: set[str] = set()
                for moving_index, point_id in enumerate(moving_ids):
                    valid_body = isinstance(point_id, str) and (
                        point_id in BODY_REGISTRY
                        or (
                            point_id.startswith("AST:")
                            and point_id.split(":", 1)[1].isdigit()
                            and int(point_id.split(":", 1)[1]) > 0
                        )
                    )
                    valid_solar_angle = (
                        technique_id == "solar_arc"
                        and isinstance(point_id, str)
                        and point_id in SUPPORTED_ANGLE_IDS
                    )
                    if not valid_body and not valid_solar_angle:
                        invalid.append(f"{prefix}.moving_body_ids[{moving_index}] is unknown: {point_id}")
                    elif isinstance(point_id, str):
                        valid_moving_ids.add(point_id)

                event_types = technique.get("event_types")
                if not isinstance(event_types, list) or not event_types:
                    invalid.append(f"{prefix}.event_types must be a non-empty array")
                    event_types = []
                seen_event_types: set[str] = set()
                for event_index, event_type in enumerate(event_types):
                    if not isinstance(event_type, str):
                        invalid.append(f"{prefix}.event_types[{event_index}] must be a string")
                    elif event_type not in allowed_event_types[technique_id]:
                        invalid.append(f"{prefix}.event_types contains unsupported value: {event_type}")
                    elif event_type in seen_event_types:
                        invalid.append(f"{prefix}.event_types must not contain duplicates")
                    else:
                        seen_event_types.add(event_type)

                if target_chart_type in {"composite", "davison"}:
                    if technique_id != "transit":
                        invalid.append(
                            f"{prefix}.id must be transit for relationship target_chart v1"
                        )
                    if seen_event_types != {"aspect"}:
                        invalid.append(
                            f"{prefix}.event_types must contain only aspect for relationship target_chart v1"
                        )

                validate_aspect_specs(
                    technique.get("aspects"),
                    f"{prefix}.aspects",
                    require_nonempty="aspect" in event_types,
                )

                if technique_id == "secondary_progression":
                    if "moon_ingress" in seen_event_types and "MOON" not in valid_moving_ids:
                        invalid.append(f"{prefix}.moving_body_ids must include MOON for moon_ingress")
                    if "lunation" in seen_event_types and not {"SUN", "MOON"}.issubset(valid_moving_ids):
                        invalid.append(f"{prefix}.moving_body_ids must include SUN and MOON for lunation")
    if mode == "modern_return":
        def validate_timezone_text(value: Any, label: str) -> None:
            if not isinstance(value, str) or not value.strip():
                invalid.append(f"{label} must be a non-empty timezone")
                return
            try:
                moment_to_local_datetime({
                    "year": 2026, "month": 1, "day": 15,
                    "hour": 12, "minute": 0, "timezone": value,
                })
            except Exception as exc:
                invalid.append(f"{label} is invalid: {exc}")

        return_body_id = request.get("return_body_id")
        supported_return_bodies = {
            "SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN",
            "URANUS", "NEPTUNE", "PLUTO", "CHIRON",
        }
        if return_body_id not in supported_return_bodies:
            invalid.append(
                "return_body_id must be one of "
                + ", ".join(sorted(supported_return_bodies))
            )
        location_source = request.get("location_source", "birth")
        if location_source not in {"birth", "custom"}:
            invalid.append("location_source must be birth or custom")
        precession = request.get("precession_correction", "none")
        if precession != "none":
            invalid.append("precession_correction currently only supports none")
        birth_moment = request.get("birth", {}).get("moment") if isinstance(request.get("birth"), dict) else None
        reference_moment = request.get("reference")
        if isinstance(birth_moment, dict):
            validate_timezone_text(birth_moment.get("timezone"), "birth.moment.timezone")
            if all(field in birth_moment for field in ("year", "month", "day", "hour", "minute", "timezone")):
                try:
                    moment_to_local_datetime(birth_moment)
                except Exception as exc:
                    invalid.append(f"birth.moment is invalid: {exc}")
        if isinstance(reference_moment, dict):
            validate_timezone_text(reference_moment.get("timezone"), "reference.timezone")
            if all(field in reference_moment for field in ("year", "month", "day", "hour", "minute", "timezone")):
                try:
                    moment_to_local_datetime(reference_moment)
                except Exception as exc:
                    invalid.append(f"reference is invalid: {exc}")
        if location_source == "custom":
            location = request.get("location")
            if not isinstance(location, dict):
                missing.append("location")
            else:
                for field in ("name", "latitude", "longitude", "timezone"):
                    if field not in location:
                        missing.append(f"location.{field}")
                latitude = location.get("latitude")
                longitude = location.get("longitude")
                if isinstance(latitude, bool) or not isinstance(latitude, (int, float)) or not -90 <= latitude <= 90:
                    invalid.append("location.latitude must be a number in [-90, 90]")
                if isinstance(longitude, bool) or not isinstance(longitude, (int, float)) or not -180 <= longitude <= 180:
                    invalid.append("location.longitude must be a number in [-180, 180]")
                validate_timezone_text(location.get("timezone"), "location.timezone")
    modern_point_modes = {
        "moment", "synastry", "composite", "davison", "progression", "solar_arc", "harmonic",
        "modern_return", "midpoint", "progressed_composite", "relocation",
    }
    if mode in modern_point_modes and "point_set" in request:
        point_set_value = request.get("point_set")
        node_mode = str(
            point_set_value.get("node_mode", request.get("node_mode", "true_node"))
            if isinstance(point_set_value, dict)
            else request.get("node_mode", "true_node")
        )
        invalid.extend(f"point_set: {error}" for error in validate_point_set(request.get("point_set"), node_mode=node_mode))
    if mode in modern_point_modes:
        node_mode_value = request.get("node_mode", "true_node")
        if not isinstance(node_mode_value, str) or node_mode_value not in {"true_node", "mean_node"}:
            invalid.append("node_mode must be one of: true_node, mean_node")
    if mode == "moment" and "patterns_enabled" in request and not isinstance(request["patterns_enabled"], bool):
        invalid.append("patterns_enabled must be a boolean")

    # B13–B20 expansion modes: nested moment / arrays / numeric range checks.
    expansion_birth_modes = {
        "classical_derivatives",
        "time_lords_extended",
        "method_families",
        "primary_directions_audit",
        "distributions_pd",
        "prenatal_parans",
        "orbital_dial",
        "hellenistic_condition_audit",
        "draconic_heliocentric",
    }
    if mode in expansion_birth_modes:
        birth = request.get("birth")
        if not isinstance(birth, dict):
            invalid.append("birth must be an object")
        else:
            moment = birth.get("moment")
            if not isinstance(moment, dict):
                missing.append("birth.moment")
            else:
                for key in _PERSON_MOMENT_FIELDS:
                    if key not in moment:
                        missing.append(f"birth.moment.{key}")
                if all(key in moment for key in _PERSON_MOMENT_FIELDS):
                    try:
                        parsed_birth = moment_to_local_datetime(moment)
                        if not 1800 <= parsed_birth.year <= 2100:
                            invalid.append("birth.moment.year must be in [1800, 2100]")
                    except Exception as exc:
                        invalid.append(f"birth.moment is invalid: {exc}")
            for field, lower, upper in (("latitude", -90.0, 90.0), ("longitude", -180.0, 180.0)):
                value = birth.get(field)
                if value is None:
                    continue
                if (
                    isinstance(value, bool)
                    or not isinstance(value, (int, float))
                    or not math.isfinite(float(value))
                    or not lower <= float(value) <= upper
                ):
                    invalid.append(f"birth.{field} must be a finite number in [{lower:g}, {upper:g}]")
        if mode in {"time_lords_extended", "method_families"}:
            reference = request.get("reference")
            if not isinstance(reference, dict):
                invalid.append("reference must be an object with an exact moment")
            else:
                for key in _PERSON_MOMENT_FIELDS:
                    if key not in reference:
                        missing.append(f"reference.{key}")
                if all(key in reference for key in _PERSON_MOMENT_FIELDS):
                    try:
                        parsed_reference = moment_to_local_datetime(reference)
                        if not 1800 <= parsed_reference.year <= 2100:
                            invalid.append("reference.year must be in [1800, 2100]")
                    except Exception as exc:
                        invalid.append(f"reference is invalid: {exc}")
        if mode == "method_families":
            if "solar_arc_rate_deg_per_year" in request and not _is_finite_number(
                request["solar_arc_rate_deg_per_year"]
            ):
                invalid.append("solar_arc_rate_deg_per_year must be a finite number")
            if "include_experimental_profiles" in request and not isinstance(
                request["include_experimental_profiles"], bool
            ):
                invalid.append("include_experimental_profiles must be a boolean")
        body_ids = request.get("body_ids")
        if body_ids is not None:
            if not isinstance(body_ids, list):
                invalid.append("body_ids must be an array when provided")
            else:
                for index, item in enumerate(body_ids):
                    if not isinstance(item, str) or not item.strip():
                        invalid.append(f"body_ids[{index}] must be a non-empty string")
        picture_orb = request.get("picture_orb")
        if picture_orb is not None and (
            isinstance(picture_orb, bool)
            or not isinstance(picture_orb, (int, float))
            or not math.isfinite(float(picture_orb))
            or float(picture_orb) < 0
            or float(picture_orb) > 15
        ):
            invalid.append("picture_orb must be a finite number in [0, 15]")
        if mode == "prenatal_parans":
            event_orb = request.get("paran_event_orb_seconds", 240)
            if (
                isinstance(event_orb, bool)
                or not isinstance(event_orb, (int, float))
                or not math.isfinite(float(event_orb))
                or not 0 < float(event_orb) <= 3600
            ):
                invalid.append("paran_event_orb_seconds must be a finite number in (0, 3600]")
            ra_orb = request.get("paran_ra_orb_deg", 1.0)
            if (
                isinstance(ra_orb, bool)
                or not isinstance(ra_orb, (int, float))
                or not math.isfinite(float(ra_orb))
                or not 0 <= float(ra_orb) <= 15
            ):
                invalid.append("paran_ra_orb_deg must be a finite number in [0, 15]")
            include_legacy = request.get("include_legacy_paran_proxy", True)
            if not isinstance(include_legacy, bool):
                invalid.append("include_legacy_paran_proxy must be a boolean")
        modulus = request.get("modulus")
        if modulus is not None and modulus not in (45, 90, 360):
            invalid.append("modulus must be 45, 90, or 360")
    if mode == "mundane_electional":
        for field in ("start", "end"):
            moment = request.get(field)
            if not isinstance(moment, dict):
                invalid.append(f"{field} must be an object with an exact moment")
            else:
                for key in _PERSON_MOMENT_FIELDS:
                    if key not in moment:
                        missing.append(f"{field}.{key}")
        location = request.get("location")
        if not isinstance(location, dict):
            invalid.append("location must be an object")
        else:
            for field in ("latitude", "longitude"):
                if field not in location:
                    missing.append(f"location.{field}")
                else:
                    value = location.get(field)
                    bounds = (-90.0, 90.0) if field == "latitude" else (-180.0, 180.0)
                    if (
                        isinstance(value, bool)
                        or not isinstance(value, (int, float))
                        or not math.isfinite(float(value))
                        or not bounds[0] <= float(value) <= bounds[1]
                    ):
                        invalid.append(
                            f"location.{field} must be a finite number in [{bounds[0]:g}, {bounds[1]:g}]"
                        )
        scan_step = request.get("scan_step_hours", 24)
        if (
            isinstance(scan_step, bool)
            or not isinstance(scan_step, (int, float))
            or not math.isfinite(float(scan_step))
            or float(scan_step) <= 0
            or float(scan_step) > 24 * 60
        ):
            invalid.append("scan_step_hours must be a finite positive number in (0, 1440]")
        topic_house = request.get("topic_house", 7)
        if (
            isinstance(topic_house, bool)
            or not isinstance(topic_house, (int, float))
            or not math.isfinite(float(topic_house))
            or int(topic_house) != float(topic_house)
            or not 1 <= int(topic_house) <= 12
        ):
            invalid.append("topic_house must be an integer in [1, 12]")

    missing = list(dict.fromkeys(missing))
    if missing or invalid:
        parts: list[str] = []
        if missing:
            parts.append(f"缺少必需字段：{', '.join(missing)}")
        if invalid:
            parts.append(f"字段无效：{'; '.join(invalid)}")
        response: dict[str, Any] = {"error": "；".join(parts), "mode": mode}
        if missing:
            response["missing"] = missing
        if invalid:
            response["invalid"] = invalid
        return response
    return None


def main() -> None:
    request: dict[str, Any] = {}
    try:
        request = json.load(sys.stdin)
        validation_error = validate_required_fields(request)
        if validation_error:
            print(json.dumps(validation_error, ensure_ascii=False, indent=2, allow_nan=False))
            return

        warnings: list[str] = []
        no_asteroids, require_ephemeris = apply_runtime_options(
            request,
            sys.argv,
            "warn",
        )
        configure_runtime(no_asteroids, require_ephemeris)

        ephemeris_path = (request.get("ephemeris_path") or request.get("ephemerisPath") or "").strip()
        resolved_ephe = _resolve_ephe_path(ephemeris_path, _bundled_ephemeris_path())
        if resolved_ephe:
            swe.set_ephe_path(resolved_ephe)

        mode = request.get("mode", "")
        if mode == "scan":
            response = scan_window(request, warnings)
        elif mode == "horary":
            packet_version = str(
                request.get("packetVersion")
                or request.get("packet_version")
                or "2"
            ).strip().lower()
            if packet_version in HORARY_V1_PACKET_VERSIONS:
                # Legacy interpretive / judgment-bearing packet (v1).
                response = calculate_horary(request, warnings)
                response.setdefault("schema", {
                    "name": "horary-data-packet",
                    "version": "1.0",
                    "schema_id": "horary-data-packet/1.0",
                    "legacy": True,
                    "deprecated": True,
                    "migration": "Use packetVersion=2 for judgment-free data packet",
                })
            elif packet_version in HORARY_V2_PACKET_VERSIONS:
                response = calculate_horary_v2(request, warnings)
            else:
                # validate_required_fields rejects this path; keep an explicit
                # guard so future refactors cannot silently route version typos.
                raise ValueError(f"unsupported horary packetVersion: {packet_version}")
        elif mode == "kp_horary":
            from astro_backend_kp import calculate_kp_horary
            response = calculate_kp_horary(request, warnings)
        elif mode == "classical":
            response = calculate_classical(request, warnings)
        elif mode == "vedic":
            from astro_backend_jyotish import calculate_vedic
            response = calculate_vedic(request, warnings)
        elif mode == "rectify":
            from astro_backend_rectify import compute_window
            response = compute_window(request)
        elif mode == "rectify_evidence":
            from astro_backend_rectify_evidence import compute_rectification_evidence
            response = compute_rectification_evidence(request)
        elif mode == "synastry":
            from astro_backend_synastry import calculate_synastry
            response = calculate_synastry(request, warnings)
        elif mode == "composite":
            from astro_backend_composite import calculate_composite
            response = calculate_composite(request, warnings)
        elif mode == "davison":
            from astro_backend_davison import calculate_davison
            response = calculate_davison(request, warnings)
        elif mode == "progression":
            from astro_backend_progressions import calculate_progressions
            response = calculate_progressions(request, warnings)
        elif mode == "solar_arc":
            from astro_backend_solar_arc import calculate_solar_arc
            response = calculate_solar_arc(request, warnings)
        elif mode == "harmonic":
            from astro_backend_harmonic import calculate_harmonic
            response = calculate_harmonic(request, warnings)
        elif mode == "modern_return":
            from astro_backend_modern_return import calculate_modern_return
            response = calculate_modern_return(request, warnings)
        elif mode == "modern_timing":
            from astro_backend_modern_timing import calculate_modern_timing
            response = calculate_modern_timing(request, warnings)
        elif mode == "midpoint":
            from astro_backend_midpoints import calculate_midpoints
            response = calculate_midpoints(request, warnings)
        elif mode == "progressed_composite":
            from astro_backend_progressed_composite import calculate_progressed_composite
            response = calculate_progressed_composite(request, warnings)
        elif mode == "relocation":
            from astro_backend_relocation import calculate_relocation
            response = calculate_relocation(request, warnings)
        elif mode == "modern_cycles":
            from astro_backend_cycles import calculate_modern_cycles
            response = calculate_modern_cycles(request, warnings)
        elif mode == "declination_timing":
            from astro_backend_declination_timing import calculate_declination_timing
            response = calculate_declination_timing(request, warnings)
        elif mode == "retrograde_cycles":
            from astro_backend_retrograde_cycles import calculate_retrograde_cycles
            response = calculate_retrograde_cycles(request, warnings)
        elif mode == "classical_visibility":
            from astro_backend_visibility import calculate_classical_visibility
            response = calculate_classical_visibility(request, warnings)
        elif mode == "planetary_synodic":
            from astro_backend_planetary_synodic import calculate_planetary_synodic
            response = calculate_planetary_synodic(request, warnings)
        elif mode == "hellenistic_condition_audit":
            from astro_backend_hellenistic_audit import calculate_hellenistic_condition_audit
            response = calculate_hellenistic_condition_audit(request, warnings)
        elif mode == "draconic_heliocentric":
            from astro_backend_draconic_heliocentric import calculate_draconic_heliocentric
            response = calculate_draconic_heliocentric(request, warnings)
        elif mode == "classical_derivatives":
            from astro_backend_classical_derivatives import calculate_classical_derivatives
            response = calculate_classical_derivatives(request, warnings)
        elif mode == "time_lords_extended":
            from astro_backend_time_lords_extended import calculate_time_lords_extended
            response = calculate_time_lords_extended(request, warnings)
        elif mode == "method_families":
            from astro_backend_method_families import calculate_method_families
            response = calculate_method_families(request, warnings)
        elif mode == "primary_directions_audit":
            from astro_backend_pd_audit import calculate_primary_directions_audit
            response = calculate_primary_directions_audit(request, warnings)
        elif mode == "distributions_pd":
            from astro_backend_distributions_pd import calculate_distributions_pd
            response = calculate_distributions_pd(request, warnings)
        elif mode == "prenatal_parans":
            from astro_backend_prenatal_parans import calculate_prenatal_parans
            response = calculate_prenatal_parans(request, warnings)
        elif mode == "orbital_dial":
            from astro_backend_orbital_dial import calculate_orbital_dial
            response = calculate_orbital_dial(request, warnings)
        elif mode == "mundane_electional":
            from astro_backend_mundane_electional import calculate_mundane_electional
            response = calculate_mundane_electional(request, warnings)
        elif mode in {"astrocartography", "local_space"}:
            from astro_backend_map import calculate_map_mode
            response = calculate_map_mode(request, warnings)
        else:
            response = calculate_moment(request, warnings)

        print(json.dumps(response, ensure_ascii=False, indent=2, allow_nan=False))
    except Exception as exc:
        mode_val = str(request.get("mode", "N/A")) if isinstance(request, dict) and isinstance(request.get("mode"), str) else "NOT_A_STRING"
        fail(f"计算失败(mode={mode_val})：{exc}")
    finally:
        swe.close()
