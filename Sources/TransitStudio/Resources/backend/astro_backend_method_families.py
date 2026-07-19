"""Progression and solar-arc method families. mode=method_families"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_core import moment_to_jd, moment_to_local_datetime, norm360, set_zodiac_mode
from astro_backend_ephemeris import body_longitude_at, build_houses, calculate_positions, resolve_bodies
from astro_backend_progressions import _calc_progressed_dt
from astro_backend_solar_arc import true_solar_arc_value

METHOD = "method_families_v1"

PROGRESSION_PROFILES = {
    "secondary_naibod": "Secondary planets; ASC/MC advanced by Naibod mean (0.98564733° ecliptic/year).",
    "secondary_solar_arc_mc": "Secondary planets; ASC/MC advanced by true solar arc (progressed Sun − natal Sun).",
    "secondary_armc_361": (
        "Secondary planets; ASC/MC advanced by ecliptic proxy of ARMC family: "
        "(361/365.2422)° per year ≈ mean sidereal-day excess folded to ~0.9886°/year on ecliptic MC — "
        "NOT a full 361° RAMC→MC reconstruction."
    ),
}

SOLAR_ARC_PROFILES = {
    "true_sun": "True solar arc: progressed Sun - natal Sun.",
    "naibod_mean": "Naibod mean: 0.98564733° per day * years.",
    "custom_rate": "Custom rate from request.solar_arc_rate_deg_per_year.",
}


def calculate_method_families(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    ref = request["reference"]
    birth_dt = moment_to_local_datetime(birth["moment"]).astimezone(timezone.utc)
    ref_dt = moment_to_local_datetime(ref).astimezone(timezone.utc)
    birth_jd, birth_utc = moment_to_jd(birth["moment"])
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    body_ids = request.get("body_ids") or ["SUN", "MOON", "MERCURY", "VENUS", "MARS"]
    specs = resolve_bodies(list(body_ids), [], warnings)
    natal = calculate_positions(birth_jd, specs, warnings, sidereal=sidereal)
    natal_by = {r["body_id"]: r for r in natal}
    natal_sun = natal_by.get("SUN")
    if natal_sun is None:
        sun_specs = resolve_bodies(["SUN"], [], warnings)
        sun_rows = calculate_positions(birth_jd, sun_specs, warnings, sidereal=sidereal)
        natal_sun = sun_rows[0] if sun_rows else None
    if natal_sun is None:
        raise RuntimeError("SUN required")

    progressed_utc, years = _calc_progressed_dt(birth_dt, ref_dt)
    prog_specs = resolve_bodies(list(body_ids) + ["SUN"], [], warnings)
    prog_positions = calculate_positions(
        moment_to_jd(
            {
                "year": progressed_utc.year,
                "month": progressed_utc.month,
                "day": progressed_utc.day,
                "hour": progressed_utc.hour,
                "minute": progressed_utc.minute,
                "timezone": "UTC",
            }
        )[0]
        if False
        else __import__("astro_backend_core", fromlist=["jd_from_datetime"]).jd_from_datetime(progressed_utc),
        prog_specs,
        warnings,
        sidereal=sidereal,
    )
    prog_by = {r["body_id"]: r for r in prog_positions}
    prog_sun = prog_by.get("SUN")
    true_arc = true_solar_arc_value(float(natal_sun["longitude"]), float(prog_sun["longitude"])) if prog_sun else 0.0
    age_years = max((ref_dt - birth_dt).total_seconds() / (365.2422 * 86400), 0.0)
    naibod_arc = 0.98564733 * age_years * 365.2422 / 365.2422  # deg per year * years
    naibod_arc = 0.98564733 * age_years
    custom_rate = float(request.get("solar_arc_rate_deg_per_year") or 1.0)
    custom_arc = custom_rate * age_years

    lat = float(birth["latitude"])
    lon_geo = float(birth["longitude"])
    hs = birth.get("houseSystem", birth.get("house_system", "whole_sign"))
    _, natal_angles, _ = build_houses(birth_jd, lat, lon_geo, hs, sidereal, warnings)
    armc_rate = 361.0 / 365.2422

    def _angle_progressed(profile_id: str, natal_lon: float) -> float:
        if profile_id == "secondary_naibod":
            return norm360(natal_lon + naibod_arc)
        if profile_id == "secondary_solar_arc_mc":
            return norm360(natal_lon + true_arc)
        # secondary_armc_361
        return norm360(natal_lon + age_years * armc_rate)

    progression_profiles_out = []
    for profile_id, desc in PROGRESSION_PROFILES.items():
        rows = []
        for body_id in body_ids:
            if body_id in {"ASC", "MC", "DSC", "IC"}:
                continue
            natal_row = natal_by.get(body_id)
            prog_row = prog_by.get(body_id)
            if not natal_row or not prog_row:
                continue
            # Planets: pure secondary for all progression profiles.
            lon = float(prog_row["longitude"])
            rows.append(
                {
                    "body_id": body_id,
                    "name": natal_row["name"],
                    "natal_longitude": round(float(natal_row["longitude"]), 9),
                    "progressed_longitude": round(lon, 9),
                    "method_key": profile_id,
                    "component": "secondary_planet",
                }
            )
        # Angles always included; profile methods diverge here by design.
        for aid in ("ASC", "MC"):
            if aid not in natal_angles:
                continue
            natal_lon = float(natal_angles[aid])
            lon = _angle_progressed(profile_id, natal_lon)
            rows.append(
                {
                    "body_id": aid,
                    "name": aid,
                    "natal_longitude": round(natal_lon, 9),
                    "progressed_longitude": round(lon, 9),
                    "method_key": profile_id,
                    "component": "angle",
                }
            )
        progression_profiles_out.append(
            {
                "profile_id": profile_id,
                "description": desc,
                "progressed_utc": progressed_utc.isoformat().replace("+00:00", "Z"),
                "rows": rows,
            }
        )

    solar_arc_profiles_out = []
    for profile_id, desc in SOLAR_ARC_PROFILES.items():
        arc = {"true_sun": true_arc, "naibod_mean": naibod_arc, "custom_rate": custom_arc}[profile_id]
        rows = []
        for body_id in body_ids:
            natal_row = natal_by.get(body_id)
            if not natal_row:
                continue
            lon = norm360(float(natal_row["longitude"]) + arc)
            rows.append(
                {
                    "body_id": body_id,
                    "name": natal_row["name"],
                    "natal_longitude": round(float(natal_row["longitude"]), 9),
                    "solar_arc_longitude": round(lon, 9),
                    "arc_deg": round(arc, 9),
                    "method_key": profile_id,
                }
            )
        solar_arc_profiles_out.append(
            {
                "profile_id": profile_id,
                "description": desc,
                "arc_deg": round(arc, 9),
                "rows": rows,
            }
        )

    # Prove method keys produce different arcs when profiles differ
    arcs = {p["profile_id"]: p["arc_deg"] for p in solar_arc_profiles_out}
    return {
        "meta": {
            "mode": "method_families",
            "method": METHOD,
            "schema_version": 1,
            "birth_utc": birth_utc,
            "reference_utc": ref_dt.isoformat().replace("+00:00", "Z"),
            "age_years": round(age_years, 6),
            "true_solar_arc_deg": round(true_arc, 9),
            "ephemeris": "Swiss Ephemeris",
        },
        "requested_config": {
            "body_ids": body_ids,
            "solar_arc_rate_deg_per_year": request.get("solar_arc_rate_deg_per_year"),
        },
        "effective_config": {
            "progression_profiles": list(PROGRESSION_PROFILES),
            "solar_arc_profiles": list(SOLAR_ARC_PROFILES),
            "method": METHOD,
        },
        "progression_profiles": progression_profiles_out,
        "solar_arc_profiles": solar_arc_profiles_out,
        "profile_arc_comparison": arcs,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": None,
        "calculation_assumptions": [
            "Secondary progression uses day-for-year via _calc_progressed_dt for planets.",
            "Progression profile divergence is on ASC/MC only: Naibod 0.98564733°/y vs true solar arc vs armc_ecliptic_proxy (361/365.2422)°/y.",
            "secondary_armc_361 is an ecliptic-longitude proxy for the ARMC family, not full RAMC→MC.",
            "Solar arc true_sun uses true_solar_arc_value(natal_sun, progressed_sun).",
            "Naibod mean uses 0.98564733°/year * age_years.",
            "custom_rate uses request.solar_arc_rate_deg_per_year (default 1).",
        ],
    }


__all__ = ["calculate_method_families"]
