"""Progression and solar-arc method families. mode=method_families

Secondary progression angles and solar arc are separate families.

Secondary progression profiles (angles via ARMC / MC reconstruction):
- secondary_armc_naibod: ARMC += Naibod°/year * age; rebuild ASC/MC/cusps
- secondary_mc_from_true_solar_arc: MC += true solar arc; invert ARMC; rebuild houses
- armc_361_ecliptic_proxy_experimental: legacy ecliptic + (361/365.2422)°/y (NOT full ARMC)

Solar arc profiles (uniform ecliptic translation of points):
- solar_arc_true_sun
- solar_arc_naibod_mean
- solar_arc_custom_key
"""

from __future__ import annotations

from datetime import timezone
from typing import Any

from astro_backend_core import moment_to_jd, moment_to_local_datetime, norm360, set_zodiac_mode
from astro_backend_ephemeris import (
    armc_from_mc,
    build_houses,
    build_houses_from_armc,
    calculate_positions,
    obliquity_deg,
    resolve_bodies,
)
from astro_backend_progressions import _calc_progressed_dt
from astro_backend_solar_arc import true_solar_arc_value

METHOD = "method_families_v2"
NAIBOD_DEG_PER_YEAR = 0.98564733

# Formal secondary progression angle profiles (ARMC/house rebuild).
PROGRESSION_PROFILES = {
    "secondary_armc_naibod": (
        "Secondary planets (day-for-year); angles from ARMC += Naibod rate * age, "
        "then houses_armc rebuild of ASC/MC/cusps."
    ),
    "secondary_mc_from_true_solar_arc": (
        "Secondary planets; MC += true solar arc, ARMC inverted from MC, houses rebuilt. "
        "ASC is NOT MC+same arc."
    ),
}

# Experimental / proxy only — excluded from formal pairing with complete methods.
PROGRESSION_EXPERIMENTAL = {
    "armc_361_ecliptic_proxy_experimental": (
        "EXPERIMENTAL ecliptic proxy: ASC/MC += (361/365.2422)°/year. "
        "Not full RAMC progression; do not treat as complete ARMC 361 method."
    ),
}

# Legacy ids → current
PROGRESSION_ALIASES = {
    "secondary_naibod": "secondary_armc_naibod",
    "secondary_solar_arc_mc": "secondary_mc_from_true_solar_arc",
    "secondary_armc_361": "armc_361_ecliptic_proxy_experimental",
}

SOLAR_ARC_PROFILES = {
    "solar_arc_true_sun": "True solar arc: progressed Sun - natal Sun (uniform ecliptic shift).",
    "solar_arc_naibod_mean": "Naibod mean: 0.98564733° per year * age_years.",
    "solar_arc_custom_key": "Custom rate from request.solar_arc_rate_deg_per_year.",
}
# Legacy solar arc profile ids still accepted in output keys for compatibility.
SOLAR_ARC_LEGACY = {
    "true_sun": "solar_arc_true_sun",
    "naibod_mean": "solar_arc_naibod_mean",
    "custom_rate": "solar_arc_custom_key",
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
    from astro_backend_core import jd_from_datetime

    prog_specs = resolve_bodies(list(body_ids) + ["SUN"], [], warnings)
    prog_positions = calculate_positions(
        jd_from_datetime(progressed_utc),
        prog_specs,
        warnings,
        sidereal=sidereal,
    )
    prog_by = {r["body_id"]: r for r in prog_positions}
    prog_sun = prog_by.get("SUN")
    true_arc = (
        true_solar_arc_value(float(natal_sun["longitude"]), float(prog_sun["longitude"]))
        if prog_sun
        else 0.0
    )
    age_years = max((ref_dt - birth_dt).total_seconds() / (365.2422 * 86400), 0.0)
    naibod_arc = NAIBOD_DEG_PER_YEAR * age_years
    custom_rate = float(request.get("solar_arc_rate_deg_per_year", 1.0))
    custom_arc = custom_rate * age_years
    armc_rate = 361.0 / 365.2422

    lat = float(birth["latitude"])
    lon_geo = float(birth["longitude"])
    hs = birth.get("houseSystem", birth.get("house_system", "placidus"))
    # Prefer Placidus for ARMC rebuild demos; whole_sign ASC still works.
    natal_cusps, natal_angles, natal_hs_label = build_houses(
        birth_jd, lat, lon_geo, hs, sidereal, warnings
    )
    natal_armc = natal_angles.get("ARMC")
    if natal_armc is None:
        # Derive from MC if Swiss ascmc[2] missing
        obl0 = obliquity_deg(birth_jd)
        natal_armc = armc_from_mc(float(natal_angles.get("MC", 0.0)), obl0)
        warnings.append("ARMC missing from natal houses; inverted from MC (approx)")
    natal_armc = float(natal_armc)
    obl = obliquity_deg(birth_jd)
    natal_asc = float(natal_angles.get("ASC", 0.0))
    natal_mc = float(natal_angles.get("MC", 0.0))
    natal_asc_mc_separation = abs(((natal_asc - natal_mc + 180) % 360) - 180)

    include_experimental = request.get("include_experimental_profiles", True)
    progression_ids = dict(PROGRESSION_PROFILES)
    if include_experimental:
        progression_ids.update(PROGRESSION_EXPERIMENTAL)

    progression_profiles_out = []
    for profile_id, desc in progression_ids.items():
        rows = []
        for body_id in body_ids:
            if body_id in {"ASC", "MC", "DSC", "IC", "ARMC"}:
                continue
            natal_row = natal_by.get(body_id)
            prog_row = prog_by.get(body_id)
            if not natal_row or not prog_row:
                continue
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

        # --- Angles ---
        proxy = False
        experimental = False
        if profile_id == "secondary_armc_naibod":
            prog_armc = norm360(natal_armc + naibod_arc)
            cusps, angles, _ = build_houses_from_armc(prog_armc, lat, obl, hs, warnings)
            method_detail = "armc_plus_naibod_then_houses_armc"
        elif profile_id == "secondary_mc_from_true_solar_arc":
            prog_mc = norm360(natal_mc + true_arc)
            prog_armc = armc_from_mc(prog_mc, obl)
            cusps, angles, _ = build_houses_from_armc(prog_armc, lat, obl, hs, warnings)
            # Prefer MC that matches true-arc intent; houses_armc MC should be near prog_mc
            method_detail = "mc_plus_true_solar_arc_invert_armc_rebuild"
        elif profile_id == "armc_361_ecliptic_proxy_experimental":
            proxy = True
            experimental = True
            delta = age_years * armc_rate
            angles = {
                "ASC": norm360(natal_asc + delta),
                "MC": norm360(natal_mc + delta),
                "DSC": norm360(natal_asc + delta + 180.0),
                "IC": norm360(natal_mc + delta + 180.0),
                "ARMC": None,
            }
            cusps = [norm360(c + delta) for c in natal_cusps]
            method_detail = "ecliptic_plus_armc_rate_proxy_not_full_ramc"
            warnings.append(
                "armc_361_ecliptic_proxy_experimental: ecliptic proxy only; not complete ARMC 361 method"
            )
        else:
            warnings.append(f"unknown progression profile {profile_id}")
            continue

        for aid in ("ASC", "MC", "DSC", "IC"):
            if aid not in angles or angles[aid] is None:
                continue
            natal_lon = float(natal_angles.get(aid, 0.0))
            lon = float(angles[aid])
            rows.append(
                {
                    "body_id": aid,
                    "name": aid,
                    "natal_longitude": round(natal_lon, 9),
                    "progressed_longitude": round(lon, 9),
                    "delta_deg": round(((lon - natal_lon + 180) % 360) - 180, 6),
                    "method_key": profile_id,
                    "component": "angle",
                    "proxy": proxy,
                    "experimental": experimental,
                }
            )
        if angles.get("ARMC") is not None:
            rows.append(
                {
                    "body_id": "ARMC",
                    "name": "ARMC",
                    "natal_longitude": round(natal_armc, 9),
                    "progressed_longitude": round(float(angles["ARMC"]), 9),
                    "method_key": profile_id,
                    "component": "armc",
                    "proxy": proxy,
                    "experimental": experimental,
                }
            )

        prog_asc = float(angles.get("ASC", 0.0))
        prog_mc = float(angles.get("MC", 0.0))
        prog_sep = abs(((prog_asc - prog_mc + 180) % 360) - 180)
        progression_profiles_out.append(
            {
                "profile_id": profile_id,
                "description": desc,
                "progressed_utc": progressed_utc.isoformat().replace("+00:00", "Z"),
                "method_detail": method_detail,
                "proxy": proxy,
                "experimental": experimental,
                "exclude_from_formal": experimental or proxy,
                "natal_asc_mc_separation_deg": round(natal_asc_mc_separation, 6),
                "progressed_asc_mc_separation_deg": round(prog_sep, 6),
                "asc_mc_separation_changed": abs(prog_sep - natal_asc_mc_separation) > 1e-4,
                "house_cusps": [round(c, 6) for c in cusps],
                "rows": rows,
            }
        )

    solar_arc_profiles_out = []
    for profile_id, desc in SOLAR_ARC_PROFILES.items():
        if profile_id == "solar_arc_true_sun":
            arc = true_arc
            legacy_id = "true_sun"
        elif profile_id == "solar_arc_naibod_mean":
            arc = naibod_arc
            legacy_id = "naibod_mean"
        else:
            arc = custom_arc
            legacy_id = "custom_rate"
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
                    "legacy_method_key": legacy_id,
                    "natal_speed_metadata": natal_row.get("speed"),
                    "note": "SA points share one arc; natal speed is metadata only, not SA motion",
                }
            )
        # SA angles: uniform arc on natal angles (stated method)
        for aid in ("ASC", "MC", "DSC", "IC"):
            if aid not in natal_angles:
                continue
            nlon = float(natal_angles[aid])
            rows.append(
                {
                    "body_id": f"SA_{aid}",
                    "name": f"SA {aid}",
                    "natal_longitude": round(nlon, 9),
                    "solar_arc_longitude": round(norm360(nlon + arc), 9),
                    "arc_deg": round(arc, 9),
                    "method_key": profile_id,
                    "component": "solar_arc_angle",
                }
            )
        solar_arc_profiles_out.append(
            {
                "profile_id": profile_id,
                "legacy_profile_id": legacy_id,
                "description": desc,
                "arc_deg": round(arc, 9),
                "rows": rows,
            }
        )

    # Also emit legacy profile_id keys for older clients (same data).
    for sa in list(solar_arc_profiles_out):
        if not any(p["profile_id"] == sa["legacy_profile_id"] for p in solar_arc_profiles_out):
            solar_arc_profiles_out.append(
                {
                    **sa,
                    "profile_id": sa["legacy_profile_id"],
                    "description": sa["description"] + " (legacy id alias)",
                    "alias_of": sa["profile_id"],
                }
            )

    arcs = {p["profile_id"]: p["arc_deg"] for p in solar_arc_profiles_out if "alias_of" not in p}

    # Method difference summary for formal progression profiles
    formal_prog = [p for p in progression_profiles_out if not p.get("exclude_from_formal")]
    method_diff = {}
    if len(formal_prog) >= 2:
        a = {r["body_id"]: r for r in formal_prog[0]["rows"] if r.get("component") == "angle"}
        b = {r["body_id"]: r for r in formal_prog[1]["rows"] if r.get("component") == "angle"}
        for aid in ("ASC", "MC"):
            if aid in a and aid in b:
                method_diff[f"{aid}_delta_between_{formal_prog[0]['profile_id']}_and_{formal_prog[1]['profile_id']}"] = round(
                    ((float(a[aid]["progressed_longitude"]) - float(b[aid]["progressed_longitude"]) + 180) % 360) - 180,
                    6,
                )

    return {
        "meta": {
            "mode": "method_families",
            "method": METHOD,
            "schema_version": 2,
            "birth_utc": birth_utc,
            "reference_utc": ref_dt.isoformat().replace("+00:00", "Z"),
            "age_years": round(age_years, 6),
            "true_solar_arc_deg": round(true_arc, 9),
            "naibod_arc_deg": round(naibod_arc, 9),
            "natal_armc": round(natal_armc, 9),
            "obliquity_deg": round(obl, 9),
            "house_system_effective": natal_hs_label,
            "ephemeris": "Swiss Ephemeris",
            "progression_aliases": PROGRESSION_ALIASES,
            "solar_arc_aliases": SOLAR_ARC_LEGACY,
        },
        "requested_config": {
            "body_ids": body_ids,
            "solar_arc_rate_deg_per_year": request.get("solar_arc_rate_deg_per_year"),
            "include_experimental_profiles": include_experimental,
        },
        "effective_config": {
            "progression_profiles": list(PROGRESSION_PROFILES),
            "progression_experimental": list(PROGRESSION_EXPERIMENTAL) if include_experimental else [],
            "solar_arc_profiles": list(SOLAR_ARC_PROFILES),
            "method": METHOD,
        },
        "progression_profiles": progression_profiles_out,
        "solar_arc_profiles": solar_arc_profiles_out,
        "profile_arc_comparison": arcs,
        "method_difference": method_diff,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": None,
        "calculation_assumptions": [
            "Secondary planets use day-for-year via _calc_progressed_dt for all progression profiles.",
            "secondary_armc_naibod: natal ARMC + Naibod°/year * age, then swe.houses_armc rebuild.",
            "secondary_mc_from_true_solar_arc: MC + true solar arc, ARMC from MC, houses rebuilt; ASC not +same arc.",
            "armc_361_ecliptic_proxy_experimental is ecliptic proxy only — not full 361° RAMC method.",
            "Solar arc family is uniform ecliptic shift; SA internal patterns are natal patterns rotated.",
            "Solar arc and secondary progression angle methods are separate families.",
        ],
        "limitations": [
            "MC→ARMC inversion uses ecliptic point RA (zero latitude); residual arcseconds possible vs full spherical solution.",
            "armc_361 full RAMC method not implemented; experimental proxy only.",
        ],
    }


__all__ = ["calculate_method_families"]
