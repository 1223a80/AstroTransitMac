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
            from astro_backend_core import SIGN_RULERS, planet_name, zodiac_sign_index
            from astro_backend_ephemeris import house_for_longitude

            by = {p["body_id"]: p for p in positions}
            sun_row = by.get("SUN")
            asc = float(angles.get("ASC", 0.0))
            mc = float(angles.get("MC", 0.0))
            asc_ruler = SIGN_RULERS[zodiac_sign_index(asc)]
            ingress_sign_ruler = SIGN_RULERS[zodiac_sign_index(target)]
            angular_planets = []
            planet_houses = []
            for p in positions:
                h = house_for_longitude(float(p["longitude"]), cusps)
                planet_houses.append({
                    "body_id": p["body_id"],
                    "house": h,
                    "longitude": round(float(p["longitude"]), 6),
                })
                if h in {1, 4, 7, 10}:
                    angular_planets.append(p["body_id"])
            # Only claim house system when angles/houses were computed for a real location.
            ingresses.append(
                {
                    "ingress": name,
                    "target_longitude": target,
                    "exact_utc": exact.isoformat().replace("+00:00", "Z"),
                    "exact_local": exact.astimezone(zone).isoformat(),
                    "exact_orb": orb,
                    "location": {
                        "latitude": lat,
                        "longitude": lon,
                        "timezone": display_timezone,
                        "source": location.get("source") or location.get("name") or "request.location",
                    },
                    "planets": positions,
                    "planet_houses": planet_houses,
                    "angles": {
                        "ASC": round(asc, 6),
                        "MC": round(mc, 6),
                        "DSC": round(float(angles.get("DSC", asc + 180.0)), 6),
                        "IC": round(float(angles.get("IC", mc + 180.0)), 6),
                    },
                    "house_cusps": [round(float(c), 6) for c in cusps],
                    "house_system": label,
                    "asc_ruler": planet_name(asc_ruler),
                    "asc_ruler_id": asc_ruler,
                    "ingress_sign_ruler": planet_name(ingress_sign_ruler),
                    "ingress_sign_ruler_id": ingress_sign_ruler,
                    "angular_planets": angular_planets,
                    "method_key": "sun_sign_ingress_bisection",
                    "chart_complete": bool(angles and cusps),
                }
            )

    # Electional fact scanner — samples, not ranked candidates.
    topic_house = int(request.get("topic_house") or request.get("target_house") or 7)
    election_type = request.get("election_type")
    scan_samples = []
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
        nearest_aspects = []
        if moon:
            for pid, p in by.items():
                if pid == "MOON":
                    continue
                sep = abs(signed_orb(float(moon["longitude"]), float(p["longitude"])))
                # Map separation to nearest major aspect
                majors = [(0, "conjunction"), (60, "sextile"), (90, "square"), (120, "trine"), (180, "opposition")]
                best = min(majors, key=lambda a: abs(sep - a[0]))
                orb = abs(sep - best[0])
                nearest_aspects.append({
                    "body": pid,
                    "aspect": best[1],
                    "orb": round(orb, 4),
                    "applying": None,
                    "separating": None,
                    "exact_time": None,
                    "separation_deg": round(sep, 4),
                })
            nearest_aspects.sort(key=lambda x: x["orb"])
        ph = _planetary_hours(
            reference_utc=cursor,
            latitude=lat,
            longitude=lon,
            altitude_m=float(location.get("altitude_m") or 0.0),
            display_zone=zone,  # type: ignore[arg-type]
            warnings=warnings,
        )
        elongation = None
        phase_name = None
        waxing = None
        if moon and sunp:
            elongation = ((float(moon["longitude"]) - float(sunp["longitude"]) + 180) % 360) - 180
            phase_name = "new" if abs(elongation) < 15 else "full" if abs(abs(elongation) - 180) < 15 else ("waxing" if elongation > 0 else "waning")
            waxing = elongation > 0
        cur_hour = ph.get("current_hour") if isinstance(ph.get("current_hour"), dict) else {}
        scan_samples.append(
            {
                "sample_utc": cursor.isoformat().replace("+00:00", "Z"),
                "sample_local": cursor.astimezone(zone).isoformat(),
                "utc": cursor.isoformat().replace("+00:00", "Z"),
                "local_time": cursor.astimezone(zone).isoformat(),
                "moon_longitude": moon and round(float(moon["longitude"]), 6),
                "moon_speed": moon and round(float(moon["speed"]), 6),
                "moon_signed_elongation": round(elongation, 4) if elongation is not None else None,
                "lunar_phase": phase_name,
                "waxing": waxing,
                "waning": (not waxing) if waxing is not None else None,
                "moon_sign_exit_distance": moon and round(30.0 - (float(moon["longitude"]) % 30.0), 4),
                "time_to_sign_exit_hours": (
                    round((30.0 - (float(moon["longitude"]) % 30.0)) / max(abs(float(moon["speed"])), 1e-6) * 24.0, 2)
                    if moon and moon.get("speed") is not None
                    else None
                ),
                "sun_moon_separation": (
                    round(abs(signed_orb(float(moon["longitude"]), float(sunp["longitude"]))), 4)
                    if moon and sunp
                    else None
                ),
                "nearest_aspects": nearest_aspects[:5],
                "nearest_moon_aspects": nearest_aspects[:3],  # legacy
                "asc_longitude": round(float(angles.get("ASC", 0.0)), 6) if angles else None,
                "topic_house": topic_house,
                "planetary_day_ruler": ph.get("day_ruler") or ph.get("planetary_day_ruler"),
                "planetary_hour_ruler": (cur_hour or {}).get("ruler") or ph.get("hour_ruler"),
                "hour_start": (cur_hour or {}).get("start_local") or (cur_hour or {}).get("start"),
                "hour_end": (cur_hour or {}).get("end_local") or (cur_hour or {}).get("end"),
                "planetary_hour": ph.get("current_hour"),
                "planetary_hours_status": ph.get("status"),
                "method_key": "electional_fact_matrix_v1",
                "row_type": "daily_fact_snapshot",
                "is_candidate": False,
                "note": "Fact sample only; not a ranked electional candidate.",
            }
        )
        cursor += timedelta(hours=scan_step_hours)

    # Only after explicit filters can samples become candidates (none applied by default).
    electional_candidates: list[dict[str, Any]] = []
    if election_type:
        warnings.append(
            f"election_type={election_type} provided but automatic lucky-time ranking is disabled; "
            "returning fact matrix only."
        )

    return {
        "meta": {
            "mode": "mundane_electional",
            "method": METHOD,
            "schema_version": 2,
            "start_utc": start.isoformat().replace("+00:00", "Z"),
            "end_utc": end.isoformat().replace("+00:00", "Z"),
            "ingress_count": len(ingresses),
            "scan_sample_count": len(scan_samples),
            "candidate_count": len(electional_candidates),
            "ephemeris": "Swiss Ephemeris",
            "display_timezone": display_timezone,
            "location": {"latitude": lat, "longitude": lon, "timezone": display_timezone},
        },
        "requested_config": {
            "location": location,
            "topic_house": topic_house,
            "target_house": topic_house,
            "election_type": election_type,
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
            "coarse_step_suggestion_minutes": 15,
            "fine_step_suggestion_minutes": 1,
        },
        "mundane_ingresses": ingresses,
        "daily_fact_snapshots": scan_samples,
        "scan_samples": scan_samples,
        # Legacy key: previously misnamed "candidates" — these are samples only.
        "electional_candidates": scan_samples,
        "electional_candidates_note": "Legacy key; rows are daily_fact_snapshots, not ranked candidates.",
        "filtered_candidates": electional_candidates,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": None,
        "calculation_assumptions": [
            "Mundane: Sun cardinal ingresses via relative longitude roots with full angles/houses at location.",
            "Electional scanner emits daily_fact_snapshots only; does not rank or pick lucky times without filters.",
            "Without election_type filters, automatic 'lucky time' selection is prohibited.",
            "location.latitude/longitude required; invalid/missing timezone raises (no silent UTC/0,0).",
            "Planetary hour attached when rise/set available; polar cases status=unavailable.",
            "House system label only emitted when ASC/MC/cusps were computed.",
        ],
    }


__all__ = ["calculate_mundane_electional"]
