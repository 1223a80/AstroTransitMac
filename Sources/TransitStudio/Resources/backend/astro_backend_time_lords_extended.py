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
    BODY_REGISTRY,
    CLASSICAL_BODY_IDS,
    SIGN_RULERS,
    SIGNS,
    completed_age,
    moment_to_jd,
    moment_to_local_datetime,
    planet_name,
    set_zodiac_mode,
    zodiac_sign_index,
)

METHOD = "time_lords_extended_v1"

# Reverse Chinese display names → stable body_id for concordance.
_NAME_TO_BODY_ID: dict[str, str] = {
    planet_name(bid): bid for bid in CLASSICAL_BODY_IDS if bid in BODY_REGISTRY
}
for bid in CLASSICAL_BODY_IDS:
    _NAME_TO_BODY_ID[bid] = bid
    _NAME_TO_BODY_ID[bid.lower()] = bid
    _NAME_TO_BODY_ID[bid.upper()] = bid


def _normalize_body_id(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    if text in _NAME_TO_BODY_ID:
        return _NAME_TO_BODY_ID[text]
    if text.upper() in BODY_REGISTRY:
        return text.upper()
    return text


def _daily_profection(birth_dt: datetime, reference_dt: datetime, year_sign_idx: int) -> dict[str, Any]:
    birth_naive = birth_dt.replace(tzinfo=None) if birth_dt.tzinfo else birth_dt
    ref_naive = reference_dt.replace(tzinfo=None) if reference_dt.tzinfo else reference_dt
    age_days = max((ref_naive - birth_naive).days, 0)
    day_in_year = age_days % 365
    sign = (year_sign_idx + day_in_year) % 12
    lord_id = SIGN_RULERS[sign]
    return {
        "activated_sign_index": sign,
        "activated_sign": SIGNS[sign],
        "lord": lord_id,
        "lord_id": lord_id,
        "lord_name": planet_name(lord_id),
        "day_in_cycle": day_in_year,
        "method_key": "daily_profection_day_step_proxy_v1",
        "note": "One sign per day from annual profection sign; explicit proxy profile.",
    }


def _lot_lookup(lots_by: dict[str, dict[str, Any]], *aliases: str) -> dict[str, Any] | None:
    """Case-insensitive lot id lookup (backend lots use lowercase e.g. fortune/spirit)."""
    for alias in aliases:
        if alias in lots_by:
            return lots_by[alias]
        low = alias.lower()
        for key, row in lots_by.items():
            if str(key).lower() == low:
                return row
        for key, row in lots_by.items():
            if str(row.get("id", "")).lower() == low:
                return row
            if str(row.get("name", "")).lower() == low:
                return row
    return None


def _zr_current_ruler_id(zr: dict[str, Any]) -> str | None:
    """Prefer finest active level ruler as stable body_id."""
    for level_key in ("l4_periods", "l3_periods", "l2_periods", "l1_periods"):
        periods = zr.get(level_key)
        if not isinstance(periods, list):
            continue
        active = next((p for p in periods if p.get("is_active")), None)
        if not active:
            continue
        for rk in ("ruler_id", "lord_id", "ruler", "lord", "sign_ruler", "planet"):
            if active.get(rk):
                return _normalize_body_id(active.get(rk))
    # fallback top-level
    for rk in ("ruler_id", "ruler", "lord"):
        if zr.get(rk):
            return _normalize_body_id(zr.get(rk))
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

    lots_by = {str(l.get("id")): l for l in snap.get("lots") or [] if l.get("id") is not None}
    section_errors: dict[str, str] = {}

    fortune_row = _lot_lookup(lots_by, "fortune", "FORTUNE", "Lot of Fortune")
    spirit_row = _lot_lookup(lots_by, "spirit", "SPIRIT", "Lot of Spirit")

    if fortune_row is None or fortune_row.get("longitude") is None:
        section_errors["zodiacal_releasing_fortune"] = "lot fortune missing; ZR Fortune not computed from ASC substitute"
        warnings.append("Lot of Fortune 未找到（id=fortune）；未用 ASC 静默替代，ZR Fortune 不可用。")
        zr_fortune = {
            "id": "zr-fortune-missing",
            "technique": "Zodiacal Releasing from Fortune",
            "error": "lot_fortune_missing",
            "loosing_of_bond": False,
            "l1_periods": [],
            "l2_periods": [],
            "l3_periods": [],
            "l4_periods": [],
            "current_active_level": None,
        }
        fortune_lon = None
    else:
        fortune = {
            "id": str(fortune_row.get("id") or "fortune"),
            "name": str(fortune_row.get("name") or "Fortune"),
            "longitude": float(fortune_row["longitude"]),
            "house": fortune_row.get("house", 0),
        }
        fortune_lon = float(fortune["longitude"])
        zr_fortune = zodiacal_releasing_summary(fortune, birth_dt, ref_dt, max_level=4)
        zr_fortune["lot_id"] = fortune["id"]
        zr_fortune["lot_longitude"] = fortune_lon

    if spirit_row is None or spirit_row.get("longitude") is None:
        section_errors["zodiacal_releasing_spirit"] = "lot spirit missing; ZR Spirit not computed from ASC/Fortune substitute"
        warnings.append("Lot of Spirit 未找到（id=spirit）；未用 ASC/Fortune 静默替代，ZR Spirit 不可用。")
        zr_spirit = {
            "id": "zr-spirit-missing",
            "technique": "Zodiacal Releasing from Spirit",
            "error": "lot_spirit_missing",
            "loosing_of_bond": False,
            "l1_periods": [],
            "l2_periods": [],
            "l3_periods": [],
            "l4_periods": [],
            "current_active_level": None,
        }
        spirit_lon = None
    else:
        spirit = {
            "id": str(spirit_row.get("id") or "spirit"),
            "name": str(spirit_row.get("name") or "Spirit"),
            "longitude": float(spirit_row["longitude"]),
            "house": spirit_row.get("house", 0),
        }
        spirit_lon = float(spirit["longitude"])
        zr_spirit = zodiacal_releasing_summary(spirit, birth_dt, ref_dt, max_level=4)
        zr_spirit["lot_id"] = spirit["id"]
        zr_spirit["lot_longitude"] = spirit_lon

    fird = firdaria_summary(birth_dt, ref_dt, snap["is_day"])
    dec = decennials_summary(birth_dt, ref_dt, snap["is_day"])

    lords: list[dict[str, str]] = []

    def add(tech: str, body: Any) -> None:
        bid = _normalize_body_id(body)
        if bid:
            lords.append({"technique": tech, "body_id": bid})

    annual_lord = None
    if isinstance(prof, dict):
        annual_lord = (
            prof.get("lordId")
            or prof.get("lord_id")
            or prof.get("lord")
            or prof.get("year_lord")
            or prof.get("ruler")
        )
        if not annual_lord and isinstance(prof.get("annual"), dict):
            annual_lord = (
                prof["annual"].get("lordId")
                or prof["annual"].get("lord_id")
                or prof["annual"].get("lord")
                or prof["annual"].get("ruler")
            )
    add("profection_annual", annual_lord or SIGN_RULERS[sign_idx])
    add("daily_profection", daily.get("lord_id") or daily.get("lord"))
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
    if fortune_lon is not None:
        add("zr_fortune", _zr_current_ruler_id(zr_fortune if isinstance(zr_fortune, dict) else {}))
    if spirit_lon is not None:
        add("zr_spirit", _zr_current_ruler_id(zr_spirit if isinstance(zr_spirit, dict) else {}))

    by_body: dict[str, list[str]] = {}
    for row in lords:
        by_body.setdefault(row["body_id"], []).append(row["technique"])
    concordance = [
        {
            "body_id": b,
            "body_name": planet_name(b) if b in BODY_REGISTRY else b,
            "techniques": techs,
            "count": len(techs),
        }
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
            "fortune_longitude": fortune_lon,
            "spirit_longitude": spirit_lon,
        },
        "requested_config": {"zodiac": zodiac},
        "effective_config": {
            "method": METHOD,
            "zr_max_level": 4,
            "daily_profection_profile": "day_step_proxy_v1",
            "lot_ids": {
                "fortune": (fortune_row or {}).get("id") if fortune_row else None,
                "spirit": (spirit_row or {}).get("id") if spirit_row else None,
            },
        },
        "profection": prof,
        "daily_profection": daily,
        "zodiacal_releasing": {
            "fortune": zr_fortune,
            "spirit": zr_spirit,
            "max_level": 4,
            "fortune_longitude": fortune_lon,
            "spirit_longitude": spirit_lon,
        },
        "firdaria": fird,
        "decennials": dec,
        "revolutions_concordance": concordance,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": section_errors or None,
        "calculation_assumptions": [
            "ZR max_level=4 for Fortune and Spirit with top-level l4_periods and current_active_level up to L4.",
            "Fortune/Spirit longitudes come from classical lots (id fortune/spirit); missing lots error without ASC substitute.",
            "Daily profection uses day-step sign proxy from annual sign (explicit profile).",
            "Concordance uses stable English body_id; no event prediction or ranking.",
        ],
    }


__all__ = ["calculate_time_lords_extended"]
