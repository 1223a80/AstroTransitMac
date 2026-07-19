"""Extended profections, ZR L4, revolutions concordance. mode=time_lords_extended"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from astro_backend_classical import classical_snapshot
from astro_backend_classical_timing import (
    decennials_summary,
    firdaria_summary,
    profection_summary,
    zodiacal_releasing_summary,
)
from astro_backend_core import (
    SIGN_RULERS,
    SIGNS,
    completed_age,
    moment_to_jd,
    moment_to_local_datetime,
    set_zodiac_mode,
    zodiac_sign_index,
)

METHOD = "time_lords_extended_v1"


def _daily_profection(birth_dt: datetime, reference_dt: datetime, year_sign_idx: int) -> dict[str, Any]:
    birth_naive = birth_dt.replace(tzinfo=None) if birth_dt.tzinfo else birth_dt
    ref_naive = reference_dt.replace(tzinfo=None) if reference_dt.tzinfo else reference_dt
    age_days = max((ref_naive - birth_naive).days, 0)
    day_in_year = age_days % 365
    sign = (year_sign_idx + day_in_year) % 12
    return {
        "activated_sign_index": sign,
        "activated_sign": SIGNS[sign],
        "lord": SIGN_RULERS[sign],
        "day_in_cycle": day_in_year,
        "method_key": "daily_profection_day_step_proxy_v1",
        "note": "One sign per day from annual profection sign; explicit proxy profile.",
    }


def _zr_current_ruler(zr: dict[str, Any]) -> str | None:
    for key in ("current_L1", "current", "L1", "level1"):
        cur = zr.get(key)
        if isinstance(cur, dict):
            for rk in ("ruler", "lord", "sign_ruler", "planet"):
                if cur.get(rk):
                    return str(cur[rk])
    # periods list
    for level_key in ("L1", "periods", "level_1"):
        periods = zr.get(level_key)
        if isinstance(periods, list) and periods:
            last = periods[-1]
            if isinstance(last, dict):
                for rk in ("ruler", "lord", "sign_ruler"):
                    if last.get(rk):
                        return str(last[rk])
    return None


def calculate_time_lords_extended(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    ref = request["reference"]
    birth_dt = moment_to_local_datetime(birth["moment"])
    ref_dt = moment_to_local_datetime(ref)
    jd, birth_utc = moment_to_jd(birth["moment"])
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    hs = birth.get("houseSystem", birth.get("house_system", "whole_sign"))
    bounds = birth.get("boundsSystem", birth.get("bounds_system", "egyptian"))
    trip = birth.get("triplicitySystem", birth.get("triplicity_system", "dorothean"))
    snap = classical_snapshot(
        jd,
        float(birth["latitude"]),
        float(birth["longitude"]),
        hs,
        sidereal,
        bounds,
        trip,
        3.0,
        warnings,
    )
    asc_lon = float(snap["angles"][0]["longitude"]) if snap["angles"] else 0.0
    planet_rows = snap["planets"]
    prof = profection_summary(birth_dt, ref_dt, asc_lon, planet_rows)
    # extract annual sign index
    age = completed_age(
        birth_dt.replace(tzinfo=None) if birth_dt.tzinfo else birth_dt,
        ref_dt.replace(tzinfo=None) if ref_dt.tzinfo else ref_dt,
    )
    sign_idx = (zodiac_sign_index(asc_lon) + age) % 12
    if isinstance(prof, dict):
        if "sign_index" in prof:
            sign_idx = int(prof["sign_index"])
        elif "annual" in prof and isinstance(prof["annual"], dict) and "sign_index" in prof["annual"]:
            sign_idx = int(prof["annual"]["sign_index"])
    daily = _daily_profection(birth_dt, ref_dt, sign_idx)

    lots_by = {str(l.get("id")): l for l in snap.get("lots") or []}
    fortune = lots_by.get("FORTUNE") or {
        "id": "FORTUNE",
        "name": "Fortune",
        "longitude": asc_lon,
    }
    spirit = lots_by.get("SPIRIT") or {
        "id": "SPIRIT",
        "name": "Spirit",
        "longitude": float(fortune.get("longitude", asc_lon)),
    }
    zr_fortune = zodiacal_releasing_summary(fortune, birth_dt, ref_dt, max_level=4)
    zr_spirit = zodiacal_releasing_summary(spirit, birth_dt, ref_dt, max_level=4)
    fird = firdaria_summary(birth_dt, ref_dt, snap["is_day"])
    dec = decennials_summary(birth_dt, ref_dt, snap["is_day"])

    lords: list[dict[str, str]] = []

    def add(tech: str, body: Any) -> None:
        if body:
            lords.append({"technique": tech, "body_id": str(body)})

    annual_lord = None
    if isinstance(prof, dict):
        annual_lord = prof.get("lord") or prof.get("year_lord") or prof.get("ruler")
        if not annual_lord and isinstance(prof.get("annual"), dict):
            annual_lord = prof["annual"].get("lord") or prof["annual"].get("ruler")
    add("profection_annual", annual_lord or SIGN_RULERS[sign_idx])
    add("daily_profection", daily.get("lord"))
    if isinstance(fird, dict):
        add(
            "firdaria",
            fird.get("current_main")
            or fird.get("main_ruler")
            or fird.get("ruler")
            or fird.get("current_ruler"),
        )
    if isinstance(dec, dict):
        add(
            "decennials",
            dec.get("current_main")
            or dec.get("main_ruler")
            or dec.get("ruler")
            or dec.get("current_ruler"),
        )
    add("zr_fortune", _zr_current_ruler(zr_fortune if isinstance(zr_fortune, dict) else {}))
    add("zr_spirit", _zr_current_ruler(zr_spirit if isinstance(zr_spirit, dict) else {}))

    by_body: dict[str, list[str]] = {}
    for row in lords:
        by_body.setdefault(row["body_id"], []).append(row["technique"])
    concordance = [
        {"body_id": b, "techniques": techs, "count": len(techs)}
        for b, techs in sorted(by_body.items(), key=lambda x: -len(x[1]))
    ]

    return {
        "meta": {
            "mode": "time_lords_extended",
            "method": METHOD,
            "schema_version": 1,
            "birth_utc": birth_utc,
            "reference_local": str(ref_dt),
            "ephemeris": "Swiss Ephemeris",
            "age": age,
        },
        "requested_config": {"zodiac": zodiac},
        "effective_config": {
            "method": METHOD,
            "zr_max_level": 4,
            "daily_profection_profile": "day_step_proxy_v1",
        },
        "profection": prof,
        "daily_profection": daily,
        "zodiacal_releasing": {
            "fortune": zr_fortune,
            "spirit": zr_spirit,
            "max_level": 4,
        },
        "firdaria": fird,
        "decennials": dec,
        "revolutions_concordance": concordance,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": None,
        "calculation_assumptions": [
            "ZR max_level=4 for Fortune and Spirit.",
            "Daily profection uses day-step sign proxy from annual sign (explicit profile).",
            "Concordance lists techniques naming the same planet; no event prediction.",
        ],
    }


__all__ = ["calculate_time_lords_extended"]
