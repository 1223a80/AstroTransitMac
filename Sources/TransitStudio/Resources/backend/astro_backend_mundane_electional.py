"""Mundane ingress pack + electional fact scanner (B20). mode=mundane_electional"""

from __future__ import annotations

import math
from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_core import (
    moment_to_local_datetime,
    resolve_timezone,
    set_zodiac_mode,
    signed_orb,
)
from astro_backend_ephemeris import body_longitude_at, build_houses, calculate_positions, resolve_bodies
from astro_backend_modern_timing import _find_roots, _step_for
from astro_backend_visibility import _planetary_hours

METHOD = "mundane_electional_v1"
INGRESS_TARGETS = {
    "aries": 0.0,
    "cancer": 90.0,
    "libra": 180.0,
    "capricorn": 270.0,
}


def calculate_mundane_electional(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    start = moment_to_local_datetime(request["start"]).astimezone(timezone.utc)
    end = moment_to_local_datetime(request["end"]).astimezone(timezone.utc)
    if end <= start:
        raise ValueError("end must be after start")
    location = request.get("location")
    if not isinstance(location, dict):
        raise ValueError("location must be an object with latitude/longitude")
    if "latitude" not in location or "longitude" not in location:
        raise ValueError("location.latitude and location.longitude are required")
    lat = float(location["latitude"])
    lon = float(location["longitude"])
    if not (-90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0):
        raise ValueError("location coordinates out of range")
    display_timezone = str(request.get("display_timezone") or location.get("timezone") or "").strip()
    if not display_timezone:
        raise ValueError("display_timezone or location.timezone is required")
    try:
        zone = resolve_timezone(display_timezone)
    except ValueError as exc:
        raise ValueError(str(exc)) from exc
    zodiac = request.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    hs = request.get("house_system", "whole_sign")

    raw_step = request.get("scan_step_hours", 24)
    try:
        scan_step_hours = float(raw_step if raw_step is not None else 24)
    except (TypeError, ValueError) as exc:
        raise ValueError("scan_step_hours must be a finite positive number") from exc
    if (
        isinstance(raw_step, bool)
        or not math.isfinite(scan_step_hours)
        or scan_step_hours <= 0
        or scan_step_hours > 24 * 60
    ):
        raise ValueError("scan_step_hours must be a finite positive number in (0, 1440]")

    # Sun ingresses
    sun = resolve_bodies(["SUN"], [], warnings)[0]
    warning_keys: set[str] = set()
    step = _step_for("transit", "SUN", warnings)
    ingresses = []
    for name, target in INGRESS_TARGETS.items():
        def residual(at, t=target):
            val = body_longitude_at(at, sun, warnings, warning_keys, sidereal=sidereal)
            if val is None:
                return None
            return signed_orb(float(val[0]), t)

        for exact, orb in _find_roots(residual, start, end, step):
            from astro_backend_core import jd_from_datetime

            jd = jd_from_datetime(exact)
            positions = calculate_positions(
                jd,
                resolve_bodies(
                    ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"], [], warnings
                ),
                warnings,
                sidereal=sidereal,
            )
            cusps, angles, label = build_houses(jd, lat, lon, hs, sidereal, warnings)
            ingresses.append(
                {
                    "ingress": name,
                    "target_longitude": target,
                    "exact_utc": exact.isoformat().replace("+00:00", "Z"),
                    "exact_local": exact.astimezone(zone).isoformat(),
                    "exact_orb": orb,
                    "planets": positions,
                    "angles": angles,
                    "house_system": label,
                    "method_key": "sun_sign_ingress_bisection",
                }
            )

    # Electional fact scanner over daily samples
    topic_house = int(request.get("topic_house") or 7)
    candidates = []
    cursor = start
    while cursor <= end:
        from astro_backend_core import jd_from_datetime

        jd = jd_from_datetime(cursor)
        positions = calculate_positions(
            jd,
            resolve_bodies(["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"], [], warnings),
            warnings,
            sidereal=sidereal,
        )
        by = {p["body_id"]: p for p in positions}
        moon = by.get("MOON")
        sunp = by.get("SUN")
        cusps, angles, _ = build_houses(jd, lat, lon, hs, sidereal, warnings)
        next_aspects = []
        if moon:
            for pid, p in by.items():
                if pid == "MOON":
                    continue
                sep = abs(signed_orb(float(moon["longitude"]), float(p["longitude"])))
                next_aspects.append({"body_id": pid, "separation_deg": round(sep, 4)})
            next_aspects.sort(key=lambda x: x["separation_deg"])
        ph = _planetary_hours(
            reference_utc=cursor,
            latitude=lat,
            longitude=lon,
            altitude_m=float(location.get("altitude_m") or 0.0),
            display_zone=zone,  # type: ignore[arg-type]
            warnings=warnings,
        )
        candidates.append(
            {
                "candidate_utc": cursor.isoformat().replace("+00:00", "Z"),
                "candidate_local": cursor.astimezone(zone).isoformat(),
                "moon_longitude": moon and round(float(moon["longitude"]), 6),
                "moon_speed": moon and round(float(moon["speed"]), 6),
                "moon_sign_exit_distance": moon and round(30.0 - (float(moon["longitude"]) % 30.0), 4),
                "sun_moon_separation": (
                    round(abs(signed_orb(float(moon["longitude"]), float(sunp["longitude"]))), 4)
                    if moon and sunp
                    else None
                ),
                "nearest_moon_aspects": next_aspects[:3],
                "asc_longitude": round(float(angles.get("ASC", 0.0)), 6) if angles else None,
                "topic_house": topic_house,
                "planetary_hour": ph.get("current_hour"),
                "planetary_hours_status": ph.get("status"),
                "method_key": "electional_fact_matrix_v1",
                "note": "Facts only; no automatic ranking of best times.",
            }
        )
        cursor += timedelta(hours=scan_step_hours)

    return {
        "meta": {
            "mode": "mundane_electional",
            "method": METHOD,
            "schema_version": 1,
            "start_utc": start.isoformat().replace("+00:00", "Z"),
            "end_utc": end.isoformat().replace("+00:00", "Z"),
            "ingress_count": len(ingresses),
            "candidate_count": len(candidates),
            "ephemeris": "Swiss Ephemeris",
            "display_timezone": display_timezone,
            "location": {"latitude": lat, "longitude": lon},
        },
        "requested_config": {
            "location": location,
            "topic_house": topic_house,
            "scan_step_hours": request.get("scan_step_hours", 24),
            "display_timezone": request.get("display_timezone"),
        },
        "effective_config": {
            "ingress_targets": list(INGRESS_TARGETS),
            "house_system": hs,
            "method": METHOD,
            "display_timezone": display_timezone,
            "latitude": lat,
            "longitude": lon,
            "scan_step_hours": scan_step_hours,
        },
        "mundane_ingresses": ingresses,
        "electional_candidates": candidates,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": None,
        "calculation_assumptions": [
            "Mundane: Sun cardinal ingresses via relative longitude roots.",
            "Electional scanner emits evidence matrix only; does not rank or pick lucky times.",
            "location.latitude/longitude required; invalid/missing timezone raises (no silent UTC/0,0).",
            "Planetary hour attached when rise/set available; polar cases status=unavailable.",
        ],
    }


__all__ = ["calculate_mundane_electional"]
