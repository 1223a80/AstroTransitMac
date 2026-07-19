"""Primary directions method audit (B16). mode=primary_directions_audit"""

from __future__ import annotations

from typing import Any

from astro_backend_core import moment_to_jd, moment_to_local_datetime, set_zodiac_mode
from astro_backend_primary_directions import NAIBOD_RATE, calculate_primary_directions

METHOD = "primary_directions_audit_v1"
NAMED_ALGORITHM = "simplified_longitude_semi_arc_proxy_naibod"
KNOWN_LIMITS = [
    "Uses ecliptic longitude derived RA/Dec without full planetary latitude in mundane sense.",
    "Single key: Naibod mean motion; no Placidus semi-arc vs Regiomontanus method switch in this audit baseline.",
    "Not a complete traditional primary directions suite; multi-method expansion is B17 after this audit.",
    "Directions outside age window are filtered rather than marked as algorithmic failure.",
]


def calculate_primary_directions_audit(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    ref = request.get("reference") or birth["moment"]
    jd, birth_utc = moment_to_jd(birth["moment"])
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    hs = birth.get("houseSystem", birth.get("house_system", "whole_sign"))
    birth_dt = moment_to_local_datetime(birth["moment"])
    ref_dt = moment_to_local_datetime(ref if isinstance(ref, dict) else birth["moment"])
    max_age = int(request.get("max_age", 90))

    directions = calculate_primary_directions(
        jd,
        birth_dt,
        float(birth["latitude"]),
        float(birth["longitude"]),
        hs,
        sidereal,
        warnings,
        max_age=max_age,
        reference_dt=ref_dt,
        window_years=float(request.get("window_years", 3.0)),
    )

    audited = []
    for d in directions or []:
        if not isinstance(d, dict):
            continue
        audited.append(
            {
                **d,
                "algorithm_name": NAMED_ALGORITHM,
                "key": "naibod",
                "key_rate_deg_per_year": float(NAIBOD_RATE),
                "latitude_mode": "ignored_or_longitude_proxy",
                "direction_class": d.get("type") or d.get("kind") or "zodiacal_proxy",
                "method_key": NAMED_ALGORITHM,
                "audit_note": "Baseline simplified PD; not multi-tradition complete.",
            }
        )

    return {
        "meta": {
            "mode": "primary_directions_audit",
            "method": METHOD,
            "schema_version": 1,
            "algorithm_name": NAMED_ALGORITHM,
            "birth_utc": birth_utc,
            "direction_count": len(audited),
            "ephemeris": "Swiss Ephemeris",
            "naibod_rate": float(NAIBOD_RATE),
        },
        "requested_config": {
            "max_age": max_age,
            "window_years": request.get("window_years", 3.0),
        },
        "effective_config": {
            "algorithm_name": NAMED_ALGORITHM,
            "key": "naibod",
            "key_rate_deg_per_year": float(NAIBOD_RATE),
            "method": METHOD,
        },
        "algorithm_description": {
            "name": NAMED_ALGORITHM,
            "key": "naibod",
            "known_limits": KNOWN_LIMITS,
            "external_crosscheck_status": "local_se_consistent_only",
            "external_crosscheck_note": (
                "No third-party PD reference tables are bundled. This audit names the "
                "algorithm and its limits; numeric checks use in-repo SE positions."
            ),
        },
        "directions": audited,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": None,
        "calculation_assumptions": KNOWN_LIMITS
        + [
            "This mode is an AUDIT of the current simplified PD implementation.",
            "B17 expands methods only with explicit method_profile per direction.",
        ],
    }


__all__ = ["calculate_primary_directions_audit", "NAMED_ALGORITHM", "KNOWN_LIMITS"]
