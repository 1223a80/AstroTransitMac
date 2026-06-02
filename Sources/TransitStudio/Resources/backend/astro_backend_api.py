from __future__ import annotations

import json
import sys
from typing import Any

from backend_runtime import apply_runtime_options

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
from astro_backend_core import (
    BODY_REGISTRY,
    CLASSICAL_BODY_IDS,
    fail,
    format_local,
    moment_to_jd,
    moment_to_local_datetime,
    public_position,
    set_zodiac_mode,
    swe,
)
from astro_backend_ephemeris import (
    build_houses,
    calculate_positions,
    clear_position_cache,
    configure_runtime,
    house_for_longitude,
    house_rows,
    point_row,
    resolve_bodies,
)
from astro_backend_scan import find_aspects, scan_window


def calculate_moment(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    natal_jd, natal_utc = moment_to_jd(request["natal"])
    transit_jd, transit_utc = moment_to_jd(request["transit"])
    custom_asteroids = [int(value) for value in request.get("customAsteroids", [])]
    natal_specs = resolve_bodies(request.get("natalBodies", []), custom_asteroids, warnings)
    transit_specs = resolve_bodies(request.get("transitBodies", []), custom_asteroids, warnings)

    natal_positions = calculate_positions(natal_jd, natal_specs, warnings)
    transit_positions = calculate_positions(transit_jd, transit_specs, warnings)
    aspects = find_aspects(transit_positions, natal_positions, request.get("aspects", []))
    ephemerides = {row.get("_ephemeris", "Swiss Ephemeris") for row in natal_positions + transit_positions}

    angles: list[dict[str, Any]] = []
    houses: list[dict[str, Any]] = []
    lots: list[dict[str, Any]] = []
    birth = request.get("birth")
    if birth:
        latitude = float(birth["latitude"])
        longitude = float(birth["longitude"])
        house_system = birth.get("houseSystem", "whole_sign")
        zodiac = birth.get("zodiac", "tropical")
        sidereal = set_zodiac_mode(zodiac)
        cusps, angle_values, _ = build_houses(natal_jd, latitude, longitude, house_system, sidereal, warnings)
        natal_positions = [
            {**row, "house": house_for_longitude(row["longitude"], cusps)}
            for row in natal_positions
        ]
        angles = [
            point_row("ASC", "ASC", angle_values["ASC"], cusps),
            point_row("MC", "MC", angle_values["MC"], cusps),
            point_row("DSC", "DSC", angle_values["DSC"], cusps),
            point_row("IC", "IC", angle_values["IC"], cusps),
        ]
        houses = house_rows(cusps)
        lot_specs = [BODY_REGISTRY[body_id] for body_id in CLASSICAL_BODY_IDS]
        lot_positions = calculate_positions(natal_jd, lot_specs, warnings, sidereal=sidereal)
        lot_positions_by_id = {row["body_id"]: row for row in lot_positions}
        sun_house = house_for_longitude(lot_positions_by_id["SUN"]["longitude"], cusps)
        is_day = sun_house >= 7
        from astro_backend_classical import calculate_lots

        lots = calculate_lots(angle_values, lot_positions_by_id, cusps, is_day)

    return {
        "meta": {
            "natal_utc": natal_utc,
            "transit_utc": transit_utc,
            "ephemeris": ", ".join(sorted(ephemerides)) if ephemerides else "unknown",
        },
        "natal_positions": [public_position(row) for row in natal_positions],
        "transit_positions": [public_position(row) for row in transit_positions],
        "angles": angles,
        "houses": houses,
        "lots": lots,
        "aspects": aspects,
        "warnings": warnings,
    }


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
    sidereal = set_zodiac_mode(zodiac)

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

    antiscia = calculate_antiscia(planet_rows, planet_positions, aspect_orb)
    section_errors: dict[str, str] = {}

    primary_directions: list[dict[str, Any]] = []
    try:
        from astro_backend_primary_directions import calculate_primary_directions
        primary_directions = calculate_primary_directions(
            birth_jd, birth_dt, latitude, longitude, house_system, sidereal, warnings,
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

    timing = {
        "profection": profection,
        "firdaria": firdaria,
        "decennials": decennials,
        "zodiacal_releasing": zodiacal_releasing,
        "_method": "Hellenistic_time_lords",
        "_source_tradition": "Hellenistic",
        "timeline": timing_timeline(profection, firdaria, decennials, zodiacal_releasing, returns, birth_dt, reference_dt),
    }
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
            "house_system_note": "宫头为各星座 0°（Whole Sign），角点度数为实际计算值",
            "zodiac": "Lahiri Sidereal" if sidereal else "Tropical",
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
                "zr_spirit": zodiacal_releasing[0].get("ruler", "") if len(zodiacal_releasing) > 0 else "",
                "zr_fortune": zodiacal_releasing[1].get("ruler", "") if len(zodiacal_releasing) > 1 else "",
                "circumambulation_lord": circumambulations[0].get("current_ruler", "") if circumambulations else "",
                "almuten_figuris": almuten.get("winner", "") if almuten else "",
                "hyleg": hyleg.get("hyleg", {}).get("selected", "") if hyleg else "",
            },
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


def validate_required_fields(request: dict[str, Any]) -> dict[str, Any] | None:
    """Return an error dict if required fields are missing, otherwise None."""
    mode = request.get("mode", "")
    required_by_mode: dict[str, list[str]] = {
        "classical": ["birth", "reference"],
        "horary": ["chart"],
        "scan": ["start", "end"],
        "rectify": ["birth_date", "center_time"],
        "synastry": ["person_a", "person_b"],
        "composite": ["person_a", "person_b"],
        "davison": ["person_a", "person_b"],
        "progression": ["birth", "reference"],
        "solar_arc": ["birth", "reference"],
        "harmonic": ["birth"],
    }
    # For any mode not explicitly listed, assume transit/natal requirements
    default_required = ["natal", "transit"]
    required = required_by_mode.get(mode, default_required)
    missing = [f for f in required if f not in request]
    if "birth" in request:
        birth = request["birth"]
        for f in ("latitude", "longitude"):
            if f not in birth:
                missing.append(f"birth.{f}")
    if mode == "classical" and "reference" in request:
        ref = request["reference"]
        for f in ("year", "month", "day"):
            if f not in ref:
                missing.append(f"reference.{f}")
    _PERSON_MOMENT_FIELDS = ("year", "month", "day", "hour", "minute", "timezone")
    if mode in ("synastry", "composite", "davison"):
        for side in ("person_a", "person_b"):
            if side not in request:
                continue
            p = request[side]
            if "moment" not in p:
                missing.append(f"{side}.moment")
            else:
                for f in _PERSON_MOMENT_FIELDS:
                    if f not in p["moment"]:
                        missing.append(f"{side}.moment.{f}")
            for f in ("latitude", "longitude"):
                if f not in p:
                    missing.append(f"{side}.{f}")
    if mode in ("progression", "solar_arc", "harmonic"):
        if "birth" in request:
            b = request["birth"]
            if "moment" not in b:
                missing.append("birth.moment")
            else:
                for f in _PERSON_MOMENT_FIELDS:
                    if f not in b["moment"]:
                        missing.append(f"birth.moment.{f}")
        if "reference" in request:
            ref = request["reference"]
            for f in ("year", "month", "day", "hour", "minute", "timezone"):
                if f not in ref:
                    missing.append(f"reference.{f}")
    if missing:
        return {"error": f"缺少必需字段：{', '.join(missing)}", "missing": missing, "mode": mode}
    return None


def main() -> None:
    try:
        request = json.load(sys.stdin)
        validation_error = validate_required_fields(request)
        if validation_error:
            print(json.dumps(validation_error, ensure_ascii=False, indent=2))
            return

        warnings: list[str] = []
        no_asteroids, require_ephemeris = apply_runtime_options(
            request,
            sys.argv,
            "warn",
        )
        configure_runtime(no_asteroids, require_ephemeris)
        clear_position_cache()

        ephemeris_path = (request.get("ephemeris_path") or request.get("ephemerisPath") or "").strip()
        if ephemeris_path:
            swe.set_ephe_path(ephemeris_path)

        mode = request.get("mode", "")
        if mode == "scan":
            response = scan_window(request, warnings)
        elif mode == "horary":
            response = calculate_horary(request, warnings)
        elif mode == "classical":
            response = calculate_classical(request, warnings)
        elif mode == "rectify":
            from astro_backend_rectify import compute_window
            response = compute_window(request)
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
        else:
            response = calculate_moment(request, warnings)

        print(json.dumps(response, ensure_ascii=False, indent=2))
    except Exception as exc:
        mode_val = str(request.get("mode", "N/A")) if isinstance(request.get("mode"), str) else "NOT_A_STRING"
        fail(f"计算失败(mode={mode_val})：{exc}")
    finally:
        swe.close()
