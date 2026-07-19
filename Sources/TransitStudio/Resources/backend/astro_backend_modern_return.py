"""Modern Solar/Lunar Return calculations.

This module intentionally has its own response contract.  The classical
``return_summary`` remains unchanged and continues to serve the classical
schema; modern Return uses exact UTC roots and a modern chart snapshot.
"""

from __future__ import annotations

import math
from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_core import (
    find_declination_aspects,
    jd_from_datetime,
    moment_to_jd,
    moment_to_local_datetime,
    public_position,
    set_zodiac_mode,
    signed_orb,
)
from astro_backend_ephemeris import (
    body_longitude_at,
    build_houses,
    calculate_positions,
    house_for_longitude,
    house_rows,
    point_row,
    resolve_bodies,
)
from astro_backend_fixed_stars import compute_star_positions, find_star_conjunctions
from astro_backend_modern_points import finalize_point_set, resolve_point_set
from astro_backend_patterns import find_patterns
from astro_backend_return_solver import search_return_exacts
from astro_backend_scan import find_aspects


ANGLE_NAMES = {
    "ASC": "ASC",
    "MC": "MC",
    "DSC": "DSC",
    "IC": "IC",
    "VERTEX": "Vertex",
    "ANTIVERTEX": "Antivertex",
    "EQUATORIAL_ASCENDANT": "East Point (Equatorial Ascendant)",
}


def _iso_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _iso_local(dt: datetime) -> str:
    return dt.isoformat()


def _location(request: dict[str, Any], birth: dict[str, Any]) -> tuple[str, dict[str, Any], float, float, str]:
    source = request.get("location_source", "birth")
    if source == "birth":
        moment = birth["moment"]
        return (
            "birth",
            {
                "name": str(birth.get("name", "Birth place")),
                "latitude": float(birth["latitude"]),
                "longitude": float(birth["longitude"]),
                "timezone": str(moment["timezone"]),
            },
            float(birth["latitude"]),
            float(birth["longitude"]),
            str(moment["timezone"]),
        )

    if source != "custom":
        raise ValueError("location_source must be birth or custom")
    location = request.get("location")
    if not isinstance(location, dict):
        raise ValueError("custom location must be an object")
    for field in ("name", "latitude", "longitude", "timezone"):
        if field not in location:
            raise ValueError(f"location.{field} is required")
    latitude = float(location["latitude"])
    longitude = float(location["longitude"])
    if not math.isfinite(latitude) or not -90 <= latitude <= 90:
        raise ValueError("location.latitude must be finite and in [-90, 90]")
    if not math.isfinite(longitude) or not -180 <= longitude <= 180:
        raise ValueError("location.longitude must be finite and in [-180, 180]")
    timezone_name = str(location["timezone"]).strip()
    if not timezone_name:
        raise ValueError("location.timezone must not be empty")
    # Validate the IANA/fixed-offset spelling with the project's own parser.
    moment_to_local_datetime({
        "year": 2026, "month": 1, "day": 15, "hour": 12, "minute": 0,
        "timezone": timezone_name,
    })
    return (
        "custom",
        {
            "name": str(location["name"]),
            "latitude": latitude,
            "longitude": longitude,
            "timezone": timezone_name,
        },
        latitude,
        longitude,
        timezone_name,
    )


# Search half-windows sized for at least ~2 synodic/orbital cycles of context
# so previous/current/next can be labelled around an arbitrary reference.
RETURN_BODY_SEARCH: dict[str, tuple[int, float]] = {
    # body_id -> (half_window_days, step_hours)
    # Step sizes keep total iterations under return_solver's default cap while
    # still bracketing the body's mean motion for reliable root refinement.
    "MOON": (120, 2.0),
    "SUN": (800, 6.0),
    "MERCURY": (200, 3.0),
    "VENUS": (500, 4.0),
    "MARS": (900, 6.0),
    "JUPITER": (4500, 24.0),
    "SATURN": (11000, 48.0),
    "URANUS": (32000, 96.0),
    "NEPTUNE": (60000, 168.0),
    "PLUTO": (90000, 240.0),
    "CHIRON": (20000, 72.0),
}

SUPPORTED_RETURN_BODIES = set(RETURN_BODY_SEARCH.keys())


def _search_exacts(
    return_body_id: str,
    target_longitude: float,
    reference_dt: datetime,
    sidereal: bool,
    warnings: list[str],
) -> tuple[list[datetime], datetime, datetime]:
    """Find all target crossings in a generous UTC window and refine them."""
    half_days, step_hours = RETURN_BODY_SEARCH.get(return_body_id, (800, 6.0))
    step = timedelta(hours=step_hours)
    start = reference_dt - timedelta(days=half_days)
    end = reference_dt + timedelta(days=half_days)
    specs = resolve_bodies([return_body_id], [], warnings)
    if not specs:
        raise ValueError(f"无法解析返照目标：{return_body_id}")
    spec = specs[0]
    exacts = search_return_exacts(
        body_spec=spec,
        target_longitude=target_longitude,
        start=start,
        end=end,
        step_hours=step.total_seconds() / 3600,
        sidereal=sidereal,
        warnings=warnings,
        title=f"{return_body_id} Return",
    )
    return exacts, start, end


def _angle_rows(angle_ids: list[str], angle_values: dict[str, float], cusps: list[float]) -> list[dict[str, Any]]:
    return [
        point_row(angle_id, ANGLE_NAMES.get(angle_id, angle_id), angle_values[angle_id], cusps)
        for angle_id in angle_ids
        if angle_id in angle_values and math.isfinite(float(angle_values[angle_id]))
    ]


def _snapshot(
    exact_dt: datetime,
    label: str,
    request: dict[str, Any],
    point_set: dict[str, Any],
    natal_jd: float,
    natal_latitude: float,
    natal_longitude: float,
    return_latitude: float,
    return_longitude: float,
    sidereal: bool,
    aspect_specs: list[dict[str, Any]],
    warnings: list[str],
) -> dict[str, Any]:
    house_system = request.get("house_system", "whole_sign")
    return_jd = jd_from_datetime(exact_dt)
    body_ids = list(point_set["resolved_body_ids"])
    if request["return_body_id"] not in body_ids:
        body_ids.append(request["return_body_id"])
    specs = resolve_bodies(
        [body_id for body_id in body_ids if not body_id.startswith("AST:")],
        list(point_set["custom_asteroids"]),
        warnings,
    )
    natal_positions_raw = calculate_positions(natal_jd, specs, warnings, sidereal=sidereal)
    return_positions_raw = calculate_positions(return_jd, specs, warnings, sidereal=sidereal)
    natal_cusps, natal_angles, _ = build_houses(
        natal_jd, natal_latitude, natal_longitude, house_system, sidereal, warnings,
    )
    return_cusps, return_angles, house_effective = build_houses(
        return_jd, return_latitude, return_longitude, house_system, sidereal, warnings,
    )
    natal_positions = [
        {**row, "house": house_for_longitude(row["longitude"], natal_cusps)}
        for row in natal_positions_raw
    ]
    return_positions = [
        {**row, "house": house_for_longitude(row["longitude"], return_cusps)}
        for row in return_positions_raw
    ]
    available_body_ids = [row["body_id"] for row in return_positions]
    effective = finalize_point_set(
        point_set,
        available_body_ids,
        available_angle_ids=[angle_id for angle_id in point_set["angle_ids"] if angle_id in return_angles],
        warnings=warnings,
    )
    angles = _angle_rows(effective["angle_ids"], return_angles, return_cusps)
    natal_angle_rows = _angle_rows(effective["angle_ids"], natal_angles, natal_cusps)
    return_public = [public_position(row) for row in return_positions]
    natal_public = [public_position(row) for row in natal_positions]
    return_to_natal = find_aspects(return_positions, natal_positions, aspect_specs)
    dec_aspects = find_declination_aspects(return_positions)
    star_positions = compute_star_positions(return_jd, warnings=warnings, sidereal=sidereal)
    star_conjunctions = find_star_conjunctions(return_positions, star_positions)
    pattern_lons = {
        row["body_id"]: row["longitude"]
        for row in return_positions
        if row["body_id"] in {"SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO"}
    }
    patterns = find_patterns(pattern_lons, [], warnings=warnings) if pattern_lons else []
    chart = {
        "angles": angles,
        "houses": house_rows(return_cusps),
        "planets": return_public,
        "natal_houses": house_rows(natal_cusps),
        "natal_planets": natal_public,
        "natal_angles": natal_angle_rows,
        "aspects": [],
        "declination_aspects": dec_aspects,
        "fixed_star_conjunctions": star_conjunctions,
        "patterns": patterns,
    }
    overlays = [
        {
            "id": f"{row['body_id']}|return|{row.get('house', 0)}|natal|{house_for_longitude(row['longitude'], natal_cusps)}",
            "body_id": row["body_id"],
            "body_name": row["name"],
            "return_house": row.get("house", 0),
            "natal_house": house_for_longitude(row["longitude"], natal_cusps),
        }
        for row in return_positions
    ]
    return {
        "label": label,
        "exact_utc": _iso_utc(exact_dt),
        "exact_local": _iso_local(exact_dt.astimezone(timezone.utc)),
        "return_longitude": return_positions[0]["longitude"] if return_positions and return_positions[0]["body_id"] == request["return_body_id"] else next(
            (row["longitude"] for row in return_positions if row["body_id"] == request["return_body_id"]),
            float("nan"),
        ),
        "exact_error": 0.0,
        "chart": chart,
        "return_to_natal_aspects": return_to_natal,
        "house_overlay": overlays,
        "_effective_point_set": effective,
        "_house_system_effective": house_effective,
    }


def _occurrence(
    exact_dt: datetime,
    label: str,
    request: dict[str, Any],
    point_set: dict[str, Any],
    target_longitude: float,
    natal_jd: float,
    natal_latitude: float,
    natal_longitude: float,
    return_latitude: float,
    return_longitude: float,
    sidereal: bool,
    aspect_specs: list[dict[str, Any]],
    warnings: list[str],
) -> tuple[dict[str, Any], dict[str, Any]]:
    snapshot = _snapshot(
        exact_dt, label, request, point_set, natal_jd, natal_latitude, natal_longitude,
        return_latitude, return_longitude, sidereal, aspect_specs, warnings,
    )
    specs = resolve_bodies([request["return_body_id"]], [], warnings)
    warning_keys: set[str] = set()
    calculated = body_longitude_at(exact_dt, specs[0], warnings, warning_keys, sidereal=sidereal)
    exact_error = abs(signed_orb(calculated[0], target_longitude)) if calculated else 360.0
    snapshot["return_longitude"] = calculated[0] if calculated else target_longitude
    snapshot["exact_error"] = exact_error
    effective = snapshot.pop("_effective_point_set")
    house_effective = snapshot.pop("_house_system_effective")
    return snapshot, {"effective_point_set": effective, "house_system_effective": house_effective}


def _group_cycle_crossings(
    exacts: list[datetime],
    reference_dt: datetime,
) -> list[dict[str, Any]]:
    """Label every refined crossing with pass index within the search window.

    Outer-planet returns may hit the natal longitude more than once near a
    station.  Callers keep previous/current/next semantics while also receiving
    the full multi-pass list for audit.
    """
    ordered = sorted(exacts)
    rows: list[dict[str, Any]] = []
    total = len(ordered)
    for index, exact in enumerate(ordered, start=1):
        relation = "at_or_before_reference" if exact <= reference_dt else "after_reference"
        rows.append(
            {
                "pass_index_in_window": index,
                "pass_count_in_window": total,
                "exact_utc": _iso_utc(exact),
                "relation_to_reference": relation,
            }
        )
    return rows


def calculate_modern_return(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    return_body_id = request.get("return_body_id")
    if return_body_id not in SUPPORTED_RETURN_BODIES:
        raise ValueError(
            "现代返照支持 return_body_id="
            + ", ".join(sorted(SUPPORTED_RETURN_BODIES))
            + f"；收到 {return_body_id}"
        )
    if request.get("precession_correction", "none") != "none":
        raise ValueError("现代返照的 precession_correction 只支持 none")

    birth = request["birth"]
    reference = request["reference"]
    birth_jd, birth_utc = moment_to_jd(birth["moment"])
    reference_dt = moment_to_local_datetime(reference)
    birth_dt = moment_to_local_datetime(birth["moment"])
    location_source, location, return_lat, return_lon, display_timezone = _location(request, birth)
    zodiac = request.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(zodiac, warnings)
    node_mode = request.get("node_mode", "true_node")
    point_set = resolve_point_set(
        request.get("point_set") if "point_set" in request else None,
        node_mode=node_mode,
    )
    aspect_specs = request.get("aspects", [])
    target_specs = resolve_bodies([return_body_id], [], warnings)
    if not target_specs:
        raise ValueError(f"无法解析返照目标：{return_body_id}")
    target_positions = calculate_positions(birth_jd, target_specs, warnings, sidereal=sidereal)
    if not target_positions:
        raise ValueError(f"无法计算本命返照目标：{return_body_id}")
    target_longitude = float(target_positions[0]["longitude"])
    exacts, search_start, search_end = _search_exacts(
        return_body_id, target_longitude, reference_dt, sidereal, warnings,
    )
    before = [exact for exact in exacts if exact <= reference_dt]
    after = [exact for exact in exacts if exact > reference_dt]
    current_exact = before[-1] if before else None
    previous_exact = before[-2] if len(before) >= 2 else None
    next_exact = after[0] if after else None

    effective_point_set = point_set
    occurrences: dict[str, Any] = {
        "previous_return": None,
        "current_cycle_return": None,
        "next_return": None,
    }
    for key, exact in (
        ("previous_return", previous_exact),
        ("current_cycle_return", current_exact),
        ("next_return", next_exact),
    ):
        if exact is None:
            continue
        snapshot, occurrence_meta = _occurrence(
            exact, key, request, point_set, target_longitude, birth_jd,
            float(birth["latitude"]), float(birth["longitude"]), return_lat, return_lon,
            sidereal, aspect_specs, warnings,
        )
        effective_point_set = occurrence_meta["effective_point_set"]
        display_tz = moment_to_local_datetime({
            "year": 2026, "month": 1, "day": 15, "hour": 12, "minute": 0,
            "timezone": display_timezone,
        }).tzinfo or timezone.utc
        snapshot["exact_local"] = _iso_local(exact.astimezone(display_tz))
        occurrences[key] = snapshot

    if not exacts:
        warnings.append(
            f"未能在搜索窗口内找到{return_body_id} 返照精确时间；建议扩大窗口 {search_start.date()} 至 {search_end.date()}。"
        )
    elif current_exact is None:
        warnings.append("reference 之前没有找到当前周期返照；请扩大搜索窗口。")
    if next_exact is None:
        warnings.append("reference 之后没有找到下一次返照；请扩大搜索窗口。")

    eph = {"Swiss Ephemeris"}
    half_days, step_hours = RETURN_BODY_SEARCH[return_body_id]
    cycle_crossings = _group_cycle_crossings(exacts, reference_dt)
    # Attach multi-pass facts onto the current occurrence when multiple roots
    # cluster within one orbital period of the reference (common near stations).
    if occurrences["current_cycle_return"] is not None and cycle_crossings and current_exact is not None:
        near = [
            row
            for row in cycle_crossings
            if abs(
                (
                    datetime.fromisoformat(row["exact_utc"].replace("Z", "+00:00"))
                    - current_exact
                ).total_seconds()
            )
            <= 400 * 86400
        ]
        occurrences["current_cycle_return"]["cycle_crossings"] = near or cycle_crossings
        occurrences["current_cycle_return"]["pass_count_in_window"] = len(exacts)
        for row in cycle_crossings:
            if row["exact_utc"] == _iso_utc(current_exact):
                occurrences["current_cycle_return"]["pass_index_in_window"] = row[
                    "pass_index_in_window"
                ]
                break

    calculation_assumptions = [
        f"返照 exact 为行运 {return_body_id} 黄经与本命目标黄经差的 bracket + bisection 求根。",
        f"搜索半窗 {half_days} 天，采样步长 {step_hours} 小时（按行星自适应）。",
        "previous / current_cycle / next 相对 reference 时刻选取；同一窗口内全部穿越见 cycle_crossings。",
        "返照地点仅影响宫位与轴点，不改变 exact UTC。",
        "precession_correction=none；sidereal 时目标与搜索共用 set_zodiac_mode。",
        "结果为可复算时间与盘面事实，不含解释性论断。",
    ]

    return {
        "meta": {
            "method": "planetary_return_longitude_bisection",
            "return_body_id": return_body_id,
            "target_longitude": target_longitude,
            "location_source": location_source,
            "location": location,
            "zodiac": zodiac,
            "house_system_requested": request.get("house_system", "whole_sign"),
            "house_system_effective": request.get("house_system", "whole_sign"),
            "display_timezone": display_timezone,
            "birth_utc": birth_utc,
            "reference_utc": _iso_utc(reference_dt),
            "precession_correction": "none",
            "ephemeris": ", ".join(sorted(eph)),
            "effective_point_set": effective_point_set,
            "search_half_days": half_days,
            "search_step_hours": step_hours,
            "crossing_count_in_window": len(exacts),
        },
        "requested_config": {
            "return_body_id": return_body_id,
            "location_source": location_source,
            "house_system": request.get("house_system", "whole_sign"),
            "zodiac": zodiac,
            "node_mode": node_mode,
            "precession_correction": request.get("precession_correction", "none"),
        },
        "effective_config": {
            "return_body_id": return_body_id,
            "target_longitude": target_longitude,
            "search_half_days": half_days,
            "search_step_hours": step_hours,
            "location_source": location_source,
            "display_timezone": display_timezone,
        },
        "all_crossings": cycle_crossings,
        "calculation_assumptions": calculation_assumptions,
        **occurrences,
        "no_hit_in_user_window": not bool(exacts),
        "suggested_window": f"建议搜索窗口 {search_start.date()} 至 {search_end.date()}" if not exacts else None,
        "search_start_local": _iso_local(search_start),
        "search_end_local": _iso_local(search_end),
        "warnings": warnings,
        "section_errors": None,
    }
