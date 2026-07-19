"""Distributions extension + multi-method PD labels (B17). mode=distributions_pd"""

from __future__ import annotations

from typing import Any

from astro_backend_circumambulations import calculate_circumambulations
from astro_backend_core import moment_to_jd, moment_to_local_datetime, set_zodiac_mode
from astro_backend_ephemeris import build_houses
from astro_backend_primary_directions import NAIBOD_RATE, calculate_primary_directions
from astro_backend_pd_audit import NAMED_ALGORITHM

METHOD = "distributions_pd_v1"
PD_PROFILES = {
    "naibod_longitude_proxy": NAMED_ALGORITHM,
    "ptolemy_key_proxy": "same_arc_engine_with_ptolemy_key_1deg_per_year",
    "converse_naibod_proxy": "same_arc_engine_with_negated_arc_label",
}


def calculate_distributions_pd(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    ref = request.get("reference") or birth["moment"]
    jd, birth_utc = moment_to_jd(birth["moment"])
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    hs = birth.get("houseSystem", birth.get("house_system", "whole_sign"))
    bounds = birth.get("boundsSystem", birth.get("bounds_system", "egyptian"))
    birth_dt = moment_to_local_datetime(birth["moment"])
    ref_dt = moment_to_local_datetime(ref if isinstance(ref, dict) else birth["moment"])
    lat = float(birth["latitude"])
    lon = float(birth["longitude"])
    cusps, angles, _ = build_houses(jd, lat, lon, hs, sidereal, warnings)
    asc = float(angles.get("ASC", 0.0))

    significators = request.get("significators") or ["ASC", "SUN", "MOON"]
    distributions = []
    for sig in significators:
        if sig == "ASC":
            sig_lon = asc
        elif sig == "MC":
            sig_lon = float(angles.get("MC", 0.0))
        else:
            # use natal planet from PD path via positions
            from astro_backend_ephemeris import calculate_positions, resolve_bodies
            from astro_backend_core import BODY_REGISTRY

            if sig not in BODY_REGISTRY:
                warnings.append(f"significator {sig} skipped")
                continue
            rows = calculate_positions(jd, resolve_bodies([sig], [], warnings), warnings, sidereal=sidereal)
            if not rows:
                continue
            sig_lon = float(rows[0]["longitude"])
        for bsys in ("egyptian", "ptolemaic"):
            try:
                pack = calculate_circumambulations(
                    sig_lon, birth_dt, bsys, max_age=int(request.get("max_age", 90)), reference_dt=ref_dt
                )
            except Exception as exc:
                warnings.append(f"circumamb {sig}/{bsys}: {exc}")
                continue
            distributions.append(
                {
                    "significator": sig,
                    "significator_longitude": round(sig_lon, 9),
                    "bounds_system": bsys,
                    "method_key": f"circumambulations_{bsys}",
                    "packet": pack,
                }
            )

    base_dirs = calculate_primary_directions(
        jd, birth_dt, lat, lon, hs, sidereal, warnings, max_age=int(request.get("max_age", 90)), reference_dt=ref_dt
    )
    multi = []
    for profile_id, algo in PD_PROFILES.items():
        for d in (base_dirs or [])[:50]:
            row = dict(d)
            if profile_id == "ptolemy_key_proxy":
                # re-scale age by key ratio if arc present
                arc = float(d.get("arc_value") or d.get("arc") or 0.0)
                row = {
                    **row,
                    "key": "ptolemy",
                    "key_rate_deg_per_year": 1.0,
                    "age_from_abs_arc": abs(arc) / 1.0 if arc else d.get("age_from_abs_arc"),
                }
            elif profile_id == "converse_naibod_proxy":
                row = {**row, "direction": "converse", "key": "naibod_converse"}
            else:
                row = {**row, "key": "naibod", "key_rate_deg_per_year": float(NAIBOD_RATE)}
            row["method_profile"] = profile_id
            row["algorithm_name"] = algo
            row["method_key"] = profile_id
            multi.append(row)

    return {
        "meta": {
            "mode": "distributions_pd",
            "method": METHOD,
            "schema_version": 1,
            "birth_utc": birth_utc,
            "requires_b16_audit": True,
            "baseline_algorithm": NAMED_ALGORITHM,
            "ephemeris": "Swiss Ephemeris",
        },
        "requested_config": {
            "significators": significators,
            "max_age": request.get("max_age", 90),
        },
        "effective_config": {
            "significators": significators,
            "pd_profiles": list(PD_PROFILES),
            "bounds_systems": ["egyptian", "ptolemaic"],
            "method": METHOD,
        },
        "distributions": distributions,
        "primary_directions_by_profile": multi,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": None,
        "calculation_assumptions": [
            "Distributions/circumambulations for ASC/MC/planets with Egyptian and Ptolemaic bounds.",
            "PD multi-profile: Naibod baseline, Ptolemy key re-age, converse label — explicit proxies on shared arc engine.",
            "Depends on B16 audit naming of baseline simplified PD algorithm.",
        ],
    }


__all__ = ["calculate_distributions_pd"]
