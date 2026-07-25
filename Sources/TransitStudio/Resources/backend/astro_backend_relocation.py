"""Relocation chart: same birth UTC/JD, new geographic houses/angles.

Method key: ``same_birth_utc_new_location_houses``.

Contract (v1):
- Birth moment is interpreted once in the birth timezone → fixed JD/UTC.
- Planet longitudes are computed once at that JD and shared by natal and
  relocated charts (must match within 1e-9°).
- Houses/angles are rebuilt independently for birth place and relocation place.
- No invented planet→planet cross-chart aspects; value is house changes and
  bidirectional angle overlays.
"""

from __future__ import annotations

import math
from datetime import timezone
from typing import Any

from astro_backend_core import (
    moment_to_jd,
    moment_to_local_datetime,
    public_position,
    resolve_timezone,
    set_zodiac_mode,
)
from astro_backend_ephemeris import (
    HOUSE_SYSTEMS,
    build_houses,
    calculate_positions,
    house_for_longitude,
    house_rows,
    point_row,
    resolve_bodies,
)
from astro_backend_modern_points import finalize_point_set, resolve_point_set

METHOD = "same_birth_utc_new_location_houses"
SCHEMA_VERSION = 1

ANGLE_NAMES = {
    "ASC": "ASC",
    "MC": "MC",
    "DSC": "DSC",
    "IC": "IC",
    "VERTEX": "Vertex",
    "ANTIVERTEX": "Antivertex",
    "EQUATORIAL_ASCENDANT": "East Point (Equatorial Ascendant)",
}


def _require_finite_coord(value: Any, field: str, lower: float, upper: float) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(float(value)):
        raise ValueError(f"{field} must be a finite number in [{lower:g}, {upper:g}]")
    number = float(value)
    if not lower <= number <= upper:
        raise ValueError(f"{field} must be a finite number in [{lower:g}, {upper:g}]")
    return number


def _validate_place(place: dict[str, Any], label: str) -> dict[str, Any]:
    if not isinstance(place, dict):
        raise ValueError(f"{label} must be an object")
    for field in ("name", "latitude", "longitude", "timezone"):
        if field not in place:
            raise ValueError(f"{label}.{field} is required")
    name = str(place["name"]).strip()
    if not name:
        raise ValueError(f"{label}.name must not be empty")
    latitude = _require_finite_coord(place["latitude"], f"{label}.latitude", -90.0, 90.0)
    longitude = _require_finite_coord(place["longitude"], f"{label}.longitude", -180.0, 180.0)
    timezone_name = str(place["timezone"]).strip()
    if not timezone_name:
        raise ValueError(f"{label}.timezone must not be empty")
    # Validate IANA / fixed offset via the project parser (rejects unknown zones).
    moment_to_local_datetime(
        {
            "year": 2026,
            "month": 1,
            "day": 15,
            "hour": 12,
            "minute": 0,
            "timezone": timezone_name,
        }
    )
    return {
        "name": name,
        "latitude": latitude,
        "longitude": longitude,
        "timezone": timezone_name,
    }


def _angle_rows(
    angle_ids: list[str],
    angle_values: dict[str, float],
    cusps: list[float],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for angle_id in angle_ids:
        if angle_id not in angle_values:
            continue
        value = float(angle_values[angle_id])
        if not math.isfinite(value):
            continue
        rows.append(point_row(angle_id, ANGLE_NAMES.get(angle_id, angle_id), value, cusps))
    return rows


def _build_chart(
    *,
    jd: float,
    latitude: float,
    longitude: float,
    house_system_requested: str,
    sidereal: bool,
    position_rows: list[dict[str, Any]],
    angle_ids: list[str],
    warnings: list[str],
    chart_label: str,
) -> tuple[dict[str, Any], list[float], dict[str, float], str]:
    """Build houses at place; attach house numbers to shared planet longitudes."""
    pre_warning_count = len(warnings)
    cusps, angles, house_label = build_houses(
        jd, latitude, longitude, house_system_requested, sidereal, warnings
    )
    # Detect fallback when Placidus/etc. cannot be computed at high latitudes.
    house_system_effective = house_system_requested
    if house_system_requested != "whole_sign":
        fallback_msgs = [
            msg
            for msg in warnings[pre_warning_count:]
            if "Whole Sign" in msg or "改用 Whole Sign" in msg
        ]
        if fallback_msgs or house_label == "Whole Sign":
            house_system_effective = "whole_sign"
            for msg in fallback_msgs:
                # Re-tag with chart provenance so callers can audit without
                # silent success.
                tagged = f"{chart_label}: {msg}"
                if tagged not in warnings:
                    warnings.append(tagged)

    planets = []
    for row in position_rows:
        public = public_position(row)
        public["house"] = house_for_longitude(float(row["longitude"]), cusps)
        planets.append(public)

    available_angles = [aid for aid in angle_ids if aid in angles]
    angle_rows = _angle_rows(available_angles, angles, cusps)
    chart = {
        "angles": angle_rows,
        "houses": house_rows(cusps),
        "planets": planets,
        "house_system_requested": house_system_requested,
        "house_system_effective": house_system_effective,
        "house_system_label": house_label,
        "latitude": latitude,
        "longitude": longitude,
    }
    return chart, cusps, angles, house_system_effective


def _planet_house_changes(
    natal_planets: list[dict[str, Any]],
    relocated_planets: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    relocated_by_id = {row["body_id"]: row for row in relocated_planets}
    rows: list[dict[str, Any]] = []
    for natal in natal_planets:
        body_id = natal["body_id"]
        relocated = relocated_by_id.get(body_id)
        if relocated is None:
            continue
        natal_house = int(natal.get("house") or 0)
        relocated_house = int(relocated.get("house") or 0)
        rows.append(
            {
                "body_id": body_id,
                "name": natal.get("name", body_id),
                "natal_house": natal_house,
                "relocated_house": relocated_house,
                "changed": natal_house != relocated_house,
            }
        )
    return rows


def _angle_overlay(
    source_angles: list[dict[str, Any]],
    target_cusps: list[float],
    *,
    source_label: str,
    target_label: str,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for angle in source_angles:
        longitude = float(angle["longitude"])
        house = house_for_longitude(longitude, target_cusps)
        rows.append(
            {
                "id": f"{angle.get('id')}|{source_label}_in_{target_label}|h{house}",
                "angle_id": angle.get("id"),
                "name": angle.get("name"),
                "longitude": longitude,
                "sign": angle.get("sign"),
                "degree_text": angle.get("degree_text"),
                "house": house,
                "source_chart": source_label,
                "target_chart": target_label,
            }
        )
    return rows


def calculate_relocation(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request.get("birth")
    if not isinstance(birth, dict):
        raise ValueError("birth must be an object with exact moment and place")
    moment = birth.get("moment")
    if not isinstance(moment, dict):
        raise ValueError("birth.moment is required with year/month/day/hour/minute/timezone")
    for field in ("year", "month", "day", "hour", "minute", "timezone"):
        if field not in moment:
            raise ValueError(f"birth.moment.{field} is required")

    birth_lat = _require_finite_coord(birth.get("latitude"), "birth.latitude", -90.0, 90.0)
    birth_lon = _require_finite_coord(birth.get("longitude"), "birth.longitude", -180.0, 180.0)
    birth_tz = str(moment["timezone"]).strip()
    birth_name = str(birth.get("name") or "Birth place").strip() or "Birth place"

    relocation_req = request.get("relocation") or {}
    # Prefer shared location service when city name / location_id is provided.
    if relocation_req.get("location_id") or relocation_req.get("city") or relocation_req.get("query"):
        try:
            from astro_backend_location_service import resolve_location

            resolved = resolve_location(
                query=relocation_req.get("query") or relocation_req.get("city") or relocation_req.get("name"),
                location_id=relocation_req.get("location_id"),
                latitude=relocation_req.get("latitude"),
                longitude=relocation_req.get("longitude"),
                timezone=relocation_req.get("timezone"),
                name=relocation_req.get("name"),
                warnings=warnings,
            )
            if resolved.get("resolved"):
                relocation_req = {
                    **relocation_req,
                    "latitude": resolved["latitude"],
                    "longitude": resolved["longitude"],
                    "timezone": resolved.get("timezone") or relocation_req.get("timezone"),
                    "name": resolved.get("name") or relocation_req.get("name"),
                    "location_source": resolved.get("source"),
                    "location_id": resolved.get("id"),
                }
            elif resolved.get("candidates"):
                warnings.append(
                    f"relocation city ambiguous; candidates={[c.get('id') for c in resolved['candidates'][:5]]}"
                )
        except Exception as exc:
            warnings.append(f"location service unavailable: {exc}")
    relocation = _validate_place(relocation_req, "relocation")

    # Fixed birth JD: interpreted only in the birth timezone.
    birth_local = moment_to_local_datetime(moment)
    birth_jd, birth_utc = moment_to_jd(moment)
    birth_utc_dt = birth_local.astimezone(timezone.utc)

    # Relocation timezone is display-only for the same UTC instant.
    # Accept IANA and project GMT/UTC±offset labels (same as moment parsing).
    try:
        relocation_tz = resolve_timezone(relocation["timezone"])
    except Exception as exc:
        raise ValueError(f"relocation.timezone is invalid: {exc}") from exc
    relocation_local = birth_utc_dt.astimezone(relocation_tz).isoformat()

    zodiac = request.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(zodiac, warnings)
    house_system = str(request.get("house_system", "whole_sign"))
    if house_system not in HOUSE_SYSTEMS:
        warnings.append(f"未识别的宫位制 '{house_system}'，已改用 Whole Sign。")
        house_system = "whole_sign"

    node_mode = str(request.get("node_mode", "true_node"))
    point_set = resolve_point_set(
        request.get("point_set") if "point_set" in request else None,
        node_mode=node_mode,
    )

    specs = resolve_bodies(
        [body_id for body_id in point_set["resolved_body_ids"] if not str(body_id).startswith("AST:")],
        list(point_set["custom_asteroids"]),
        warnings,
    )
    # Single position computation — shared by both charts.
    position_rows = calculate_positions(birth_jd, specs, warnings, sidereal=sidereal)
    available_body_ids = [row["body_id"] for row in position_rows]

    natal_chart, natal_cusps, natal_angles, natal_effective = _build_chart(
        jd=birth_jd,
        latitude=birth_lat,
        longitude=birth_lon,
        house_system_requested=house_system,
        sidereal=sidereal,
        position_rows=position_rows,
        angle_ids=list(point_set["angle_ids"]),
        warnings=warnings,
        chart_label="natal",
    )
    relocated_chart, relocated_cusps, relocated_angles, relocated_effective = _build_chart(
        jd=birth_jd,
        latitude=relocation["latitude"],
        longitude=relocation["longitude"],
        house_system_requested=house_system,
        sidereal=sidereal,
        position_rows=position_rows,
        angle_ids=list(point_set["angle_ids"]),
        warnings=warnings,
        chart_label="relocated",
    )

    available_angle_ids = sorted(
        {
            angle_id
            for angle_id in point_set["angle_ids"]
            if angle_id in natal_angles or angle_id in relocated_angles
        }
    )
    effective = finalize_point_set(
        point_set,
        available_body_ids,
        available_angle_ids=available_angle_ids,
        warnings=warnings,
    )

    # Re-filter angles to effective set after finalize.
    natal_chart["angles"] = [
        row for row in natal_chart["angles"] if row.get("id") in effective["angle_ids"]
    ]
    relocated_chart["angles"] = [
        row for row in relocated_chart["angles"] if row.get("id") in effective["angle_ids"]
    ]
    natal_chart["planets"] = [
        row for row in natal_chart["planets"] if row.get("body_id") in set(available_body_ids)
    ]
    relocated_chart["planets"] = [
        row for row in relocated_chart["planets"] if row.get("body_id") in set(available_body_ids)
    ]

    planet_house_changes = _planet_house_changes(natal_chart["planets"], relocated_chart["planets"])
    relocated_angles_in_natal = _angle_overlay(
        relocated_chart["angles"],
        natal_cusps,
        source_label="relocated",
        target_label="natal",
    )
    natal_angles_in_relocated = _angle_overlay(
        natal_chart["angles"],
        relocated_cusps,
        source_label="natal",
        target_label="relocated",
    )

    ephemerides = sorted(
        {
            str(row.get("_ephemeris"))
            for row in position_rows
            if row.get("_ephemeris")
        }
    )

    return {
        "meta": {
            "mode": "relocation",
            "method": METHOD,
            "schema_version": SCHEMA_VERSION,
            "birth_utc": birth_utc,
            "birth_jd": birth_jd,
            "relocation_local": relocation_local,
            "birth_place": {
                "name": birth_name,
                "latitude": birth_lat,
                "longitude": birth_lon,
                "timezone": birth_tz,
            },
            "relocation": relocation,
            "house_system_requested": house_system,
            "house_system_effective_natal": natal_effective,
            "house_system_effective_relocated": relocated_effective,
            "zodiac": zodiac,
            "node_mode": node_mode,
            "ephemeris": ", ".join(ephemerides) if ephemerides else "Swiss Ephemeris",
            "effective_point_set": effective,
        },
        "natal_chart": natal_chart,
        "relocated_chart": relocated_chart,
        "planet_house_changes": planet_house_changes,
        "relocated_angles_in_natal_houses": relocated_angles_in_natal,
        "natal_angles_in_relocated_houses": natal_angles_in_relocated,
        "warnings": warnings,
        "section_errors": None,
    }
