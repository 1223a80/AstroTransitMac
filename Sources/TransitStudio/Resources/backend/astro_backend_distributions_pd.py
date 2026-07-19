"""Distributions extension + multi-method PD labels (B17). mode=distributions_pd"""

from __future__ import annotations

from datetime import timedelta
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
    "converse_naibod_proxy": "same_arc_engine_with_negated_arc_converse",
}


def _rekey_direction(
    base: dict[str, Any],
    *,
    profile_id: str,
    algorithm_name: str,
    birth_dt,
    key: str,
    key_rate: float,
    arc_signed: float,
    direction_type: str,
) -> dict[str, Any]:
    """Rebuild age/date fields from a signed ecliptic-arc proxy using the given key rate."""
    age_signed = arc_signed / key_rate if key_rate else 0.0
    age_abs = abs(age_signed)
    event_dt = birth_dt + timedelta(days=age_abs * 365.2425)
    symbolic = birth_dt + timedelta(days=age_signed * 365.2425)
    row = dict(base)
    row.update(
        {
            "method_profile": profile_id,
            "algorithm_name": algorithm_name,
            "method_key": profile_id,
            "key": key,
            "key_rate_deg_per_year": float(key_rate),
            "arc_signed": round(arc_signed, 6),
            "arc_abs": round(abs(arc_signed), 6),
            "age_from_abs_arc": round(age_abs, 4),
            "age_from_signed_arc": round(age_signed, 4),
            "direction_type": direction_type,
            "direction": direction_type,
            "event_date_after_birth": event_dt.strftime("%Y-%m-%d"),
            "symbolic_date_from_signed_arc": symbolic.strftime("%Y-%m-%d") if age_signed < 0 else None,
        }
    )
    return row


def calculate_distributions_pd(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    ref = request.get("reference") or birth["moment"]
    jd, birth_utc = moment_to_jd(birth["moment"])
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    hs = birth.get("houseSystem", birth.get("house_system", "whole_sign"))
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
        for d in base_dirs or []:
            if not isinstance(d, dict):
                continue
            # Real PD arc fields from calculate_primary_directions.
            arc_signed = float(d.get("arc_signed") if d.get("arc_signed") is not None else d.get("arc_abs") or 0.0)
            if profile_id == "naibod_longitude_proxy":
                multi.append(
                    _rekey_direction(
                        d,
                        profile_id=profile_id,
                        algorithm_name=algo,
                        birth_dt=birth_dt,
                        key="naibod",
                        key_rate=float(NAIBOD_RATE),
                        arc_signed=arc_signed,
                        direction_type=str(d.get("direction_type") or ("direct" if arc_signed >= 0 else "converse")),
                    )
                )
            elif profile_id == "ptolemy_key_proxy":
                multi.append(
                    _rekey_direction(
                        d,
                        profile_id=profile_id,
                        algorithm_name=algo,
                        birth_dt=birth_dt,
                        key="ptolemy",
                        key_rate=1.0,
                        arc_signed=arc_signed,
                        direction_type=str(d.get("direction_type") or ("direct" if arc_signed >= 0 else "converse")),
                    )
                )
            elif profile_id == "converse_naibod_proxy":
                # True converse relative to baseline: negate the signed arc and re-key with Naibod.
                flipped = -arc_signed
                multi.append(
                    _rekey_direction(
                        d,
                        profile_id=profile_id,
                        algorithm_name=algo,
                        birth_dt=birth_dt,
                        key="naibod_converse",
                        key_rate=float(NAIBOD_RATE),
                        arc_signed=flipped,
                        direction_type="converse" if flipped < 0 else "direct",
                    )
                )
            else:
                warnings.append(f"unknown PD profile {profile_id}; skipped")

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
            "arc_fields_used": ["arc_signed", "arc_abs", "age_from_abs_arc", "direction_type"],
        },
        "distributions": distributions,
        "primary_directions_by_profile": multi,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": None,
        "calculation_assumptions": [
            "Distributions/circumambulations for ASC/MC/planets with Egyptian and Ptolemaic bounds.",
            "PD multi-profile recomputes ages from arc_signed: Naibod rate, Ptolemy 1°/year, converse = negated arc + Naibod.",
            "Still a simplified longitude/Naibod-family proxy engine (see B16 audit); not full Placidus/Regio PD.",
            "Depends on B16 audit naming of baseline simplified PD algorithm.",
        ],
    }


__all__ = ["calculate_distributions_pd"]
