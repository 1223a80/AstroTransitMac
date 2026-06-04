"""Vedic (Jyotish) astrology calculation engine.

Entry point: calculate_vedic(request, warnings)
Mode: "vedic"
"""

from __future__ import annotations

import math
from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    format_local,
    jd_from_datetime,
    moment_to_jd,
    moment_to_local_datetime,
    norm360,
    set_zodiac_mode,
    swe,
    zodiac_sign_index,
)
from astro_backend_ephemeris import (
    build_houses,
    calculate_positions,
    house_for_longitude,
    house_rows,
    point_row,
)
from astro_backend_jyotish_data import (
    AYANAMSHA_MAP,
    AYANAMSHA_NAMES,
    DEFAULT_AYANAMSHA,
    NAKSHATRA_DATA,
    NAKSHATRA_LEN,
    VEDIC_PLANET_IDS,
    nakshatra_index_for_longitude,
    nakshatra_details,
    nakshatra_for_longitude,
)
from astro_backend_jyotish_varga import calc_varga, varga_rasi_for_planet

from astro_backend_jyotish_data import VIMSOTTARI_LORD_ORDER, VIMSOTTARI_DURATIONS, VIMSOTTARI_TOTAL
from astro_backend_jyotish_data import vimsottari_dasa_index_for_nakshatra


def _resolve_vedic_positions(
    jd_ut: float,
    sidereal: bool,
    warnings: list[str],
) -> dict[str, dict[str, Any]]:
    """Calculate positions for all 9 Vedic planets.

    Rahu = True Node
    Ketu = True Node + 180°
    """
    class _VedicSpec:
        def __init__(self, body_id, name, code, offset=0.0):
            self.body_id = body_id
            self.name = name
            self.code = code
            self.longitude_offset = offset

    specs = [
        _VedicSpec("SUN", "太阳", swe.SUN),
        _VedicSpec("MOON", "月亮", swe.MOON),
        _VedicSpec("MARS", "火星", swe.MARS),
        _VedicSpec("MERCURY", "水星", swe.MERCURY),
        _VedicSpec("JUPITER", "木星", swe.JUPITER),
        _VedicSpec("VENUS", "金星", swe.VENUS),
        _VedicSpec("SATURN", "土星", swe.SATURN),
    ]

    flags = swe.FLG_SWIEPH | swe.FLG_SPEED
    if sidereal:
        flags |= swe.FLG_SIDEREAL

    result = {}
    for spec in specs:
        try:
            values, _ = swe.calc_ut(jd_ut, spec.code, flags)
            if values is None:
                continue
            lon = (values[0] + spec.longitude_offset) % 360.0
            sign_idx = zodiac_sign_index(lon)
            from astro_backend_core import SIGNS, format_longitude
            _, degree_text = format_longitude(lon)
            result[spec.body_id] = {
                "body_id": spec.body_id,
                "name": spec.name,
                "longitude": lon,
                "sign": SIGNS[sign_idx],
                "degree_text": degree_text,
                "speed": values[3],
                "_ephemeris": "Swiss Ephemeris",
            }
        except swe.Error as e:
            warnings.append(f"瑞士星历计算 {spec.name} 失败：{e}")

    # Rahu (True Node)
    try:
        values, _ = swe.calc_ut(jd_ut, swe.TRUE_NODE, flags)
        if values:
            rahu_lon = values[0] % 360.0
            from astro_backend_core import SIGNS, format_longitude
            _, degree_text = format_longitude(rahu_lon)
            sign_idx = zodiac_sign_index(rahu_lon)
            result["RAHU"] = {
                "body_id": "RAHU",
                "name": "罗睺",
                "longitude": rahu_lon,
                "sign": SIGNS[sign_idx],
                "degree_text": degree_text,
                "speed": values[3],
                "_ephemeris": "Swiss Ephemeris",
            }
            # Ketu = 180° from Rahu
            ketu_lon = (rahu_lon + 180.0) % 360.0
            _, degree_text_k = format_longitude(ketu_lon)
            sign_idx_k = zodiac_sign_index(ketu_lon)
            result["KETU"] = {
                "body_id": "KETU",
                "name": "计都",
                "longitude": ketu_lon,
                "sign": SIGNS[sign_idx_k],
                "degree_text": degree_text_k,
                "speed": values[3],
                "_ephemeris": "Swiss Ephemeris",
            }
    except swe.Error as e:
        warnings.append(f"计算南北交点失败：{e}")

    return result


def _add_nakshatra_details(
    positions: dict[str, dict[str, Any]],
    moon_nak_index: int | None = None,
) -> dict[str, Any]:
    """Add Nakshatra details to each planet position."""
    result = {}
    for pid, pos in positions.items():
        details = nakshatra_details(pos["longitude"], moon_nak_index)
        result[pid] = {**pos, "nakshatra": details}
    return result


def _calc_rasi_chart(
    jd_ut: float,
    latitude: float,
    longitude: float,
    house_system: str,
    sidereal: bool,
    planet_positions: dict[str, dict[str, Any]],
    warnings: list[str],
) -> dict[str, Any]:
    """Build Rasi (D1) chart with houses and angles."""
    cusps, angles, house_label = build_houses(
        jd_ut, latitude, longitude, house_system, sidereal, warnings
    )

    angle_rows = [
        point_row("ASC", "ASC", angles["ASC"], cusps),
        point_row("MC", "MC", angles["MC"], cusps),
        point_row("DSC", "DSC", angles["DSC"], cusps),
        point_row("IC", "IC", angles["IC"], cusps),
    ]

    planets_in_houses = {}
    for pid, pos in planet_positions.items():
        h = house_for_longitude(pos["longitude"], cusps)
        planets_in_houses[pid] = {**pos, "house": h}

    houses = house_rows(cusps)

    return {
        "house_label": house_label,
        "angles": angle_rows,
        "houses": houses,
        "planets": planets_in_houses,
        "cusps": cusps,
    }


def _calc_navamsa_chart(
    planet_positions: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    """Build Navamsa (D9) chart for all planets."""
    navamsa_data = {}
    for pid, pos in planet_positions.items():
        d9_rasi = calc_varga(pos["longitude"], 9)
        navamsa_data[pid] = {
            "body_id": pid,
            "name": pos.get("name", pid),
            "navamsa_rasi": d9_rasi,
            "navamsa_rasi_name": ["牡羊","金牛","双子","巨蟹","狮子","处女",
                                  "天秤","天蝎","射手","摩羯","水瓶","双鱼"][d9_rasi],
        }
    return navamsa_data


# ─── Antardasha calculation ──────────────────────────────────────────

def _calc_antardashas(
    maha_lord: str,
    maha_start: datetime,
    maha_end: datetime,
) -> list[dict[str, Any]]:
    """Calculate Antardasha (sub-periods) within a Mahadasha.

    Antardasha sequence starts with the same lord as the Mahadasha,
    then follows the Vimsottari cycle.
    Each Antardasha duration = (MD_years * AD_years) / 120 years.
    """
    # Find the starting index in the lord order
    if maha_lord in VIMSOTTARI_LORD_ORDER:
        start_idx = VIMSOTTARI_LORD_ORDER.index(maha_lord)
    else:
        return []

    # Generate antardasha sequence (same order, starting from maha lord)
    seq = VIMSOTTARI_LORD_ORDER[start_idx:] + VIMSOTTARI_LORD_ORDER[:start_idx]

    maha_dur_years = VIMSOTTARI_DURATIONS.get(maha_lord, 0)
    total_days = (maha_end - maha_start).days

    antardashas = []
    current = maha_start
    for lord in seq:
        ad_duration_years = (maha_dur_years * VIMSOTTARI_DURATIONS.get(lord, 0)) / VIMSOTTARI_TOTAL
        ad_duration_days = ad_duration_years * 365.2425
        end = current + timedelta(days=ad_duration_days)

        # Don't exceed the Mahadasha end
        if end > maha_end:
            end = maha_end

        antardashas.append({
            "lord": lord,
            "start": format_local(current),
            "end": format_local(end),
            "duration_years": round(ad_duration_years, 4),
        })
        current = end

    return antardashas


def _calc_vimsottari_dasa(
    moon_longitude: float,
    birth_dt: datetime,
    reference_dt: datetime,
) -> dict[str, Any]:
    """Calculate Vimsottari Dasa timeline with Antardasha support."""

    birth_nak_idx = nakshatra_index_for_longitude(moon_longitude)
    birth_nak = nakshatra_for_longitude(moon_longitude)

    # Starting dasa index based on Moon's nakshatra
    start_idx = vimsottari_dasa_index_for_nakshatra(birth_nak_idx)

    # Calculate how much time has elapsed in the first dasa
    nak_offset = (moon_longitude % 360.0 - birth_nak["start_longitude"])
    if nak_offset < 0:
        nak_offset += 360.0
    nak_progress = nak_offset / NAKSHATRA_LEN  # 0.0 - 1.0

    first_lord = VIMSOTTARI_LORD_ORDER[start_idx]
    first_duration_years = VIMSOTTARI_DURATIONS[first_lord]
    elapsed_years = first_duration_years * nak_progress
    remaining_years = first_duration_years - elapsed_years

    # Build sequence starting from birth
    dasa_seq = VIMSOTTARI_LORD_ORDER[start_idx:] + VIMSOTTARI_LORD_ORDER[:start_idx]

    # Calculate dates for each dasa
    first_start = birth_dt - timedelta(days=elapsed_years * 365.2425)

    current_date = first_start
    maha_dasas = []

    for lord in dasa_seq:
        duration_years = VIMSOTTARI_DURATIONS[lord]
        duration_days = duration_years * 365.2425
        end_date = current_date + timedelta(days=duration_days)
        maha_dasas.append({
            "lord": lord,
            "duration_years": duration_years,
            "start": format_local(current_date),
            "end": format_local(end_date),
        })
        current_date = end_date

    # Find current dasa
    current_maha = None
    current_maha_idx = -1
    for idx, md in enumerate(maha_dasas):
        md_start = datetime.strptime(md["start"], "%Y-%m-%d %H:%M").replace(tzinfo=birth_dt.tzinfo)
        md_end = datetime.strptime(md["end"], "%Y-%m-%d %H:%M").replace(tzinfo=birth_dt.tzinfo)
        if md_start <= reference_dt <= md_end:
            current_maha = md
            current_maha_idx = idx
            break

    # Add Antardasha to each Mahadasha
    for md in maha_dasas:
        md_start = datetime.strptime(md["start"], "%Y-%m-%d %H:%M").replace(tzinfo=birth_dt.tzinfo)
        md_end = datetime.strptime(md["end"], "%Y-%m-%d %H:%M").replace(tzinfo=birth_dt.tzinfo)
        md["antardashas"] = _calc_antardashas(md["lord"], md_start, md_end)

    return {
        "birth_nakshatra": birth_nak["name_sa"],
        "birth_nakshatra_index": birth_nak_idx,
        "maha_dasas": maha_dasas,
        "current_mahadasa": current_maha,
    }


def _calc_yogini_dasa(
    moon_longitude: float,
    birth_dt: datetime,
    reference_dt: datetime,
) -> dict[str, Any]:
    """Calculate Yogini Dasa (8 yoginis × varying durations, total 36 years)."""

    nak = nakshatra_for_longitude(moon_longitude)
    pada = nak["pada"]  # 1-4

    # Yogini sequence: 8 yoginis, each with a fixed duration in years
    yoginis = [
        ("Mangala", 1), ("Pingala", 2), ("Dhanya", 3), ("Bhramari", 4),
        ("Bhadrika", 5), ("Ulka", 6), ("Siddha", 7), ("Sankata", 8),
    ]

    # Starting yogini based on pada (1-indexed → 0-indexed)
    start_idx = (pada - 1) % 8
    yogini_seq = yoginis[start_idx:] + yoginis[:start_idx]

    # Elapsed portion based on position within pada
    offset_in_pada = (moon_longitude % 360.0 - nak["start_longitude"]) % NAKSHATRA_LEN - (pada - 1) * (NAKSHATRA_LEN / 4)
    pada_progress = offset_in_pada / (NAKSHATRA_LEN / 4)
    pada_progress = max(0.0, min(1.0, pada_progress))

    first_yogini_name, first_dur = yogini_seq[0]
    elapsed = first_dur * pada_progress

    current_date = birth_dt - timedelta(days=elapsed * 365.2425)
    dasas = []
    # Keep generating cycles until we pass the reference date
    max_cycles = 10  # safety limit (36yr × 10 = 360 years)
    for _ in range(max_cycles):
        for name, dur_years in yogini_seq:
            end_date = current_date + timedelta(days=dur_years * 365.2425)
            dasas.append({
                "yogini": name,
                "duration_years": dur_years,
                "start": format_local(current_date),
                "end": format_local(end_date),
            })
            current_date = end_date
        # Stop generating if we've passed the reference date
        if current_date > reference_dt + timedelta(days=365):
            break

    current = None
    for d in dasas:
        ds = datetime.strptime(d["start"], "%Y-%m-%d %H:%M").replace(tzinfo=birth_dt.tzinfo)
        de = datetime.strptime(d["end"], "%Y-%m-%d %H:%M").replace(tzinfo=birth_dt.tzinfo)
        if ds <= reference_dt <= de:
            current = d
            break

    return {"yogini_dasas": dasas, "current_yogini": current}


def _calc_ashtottari_dasa(
    moon_longitude: float,
    birth_dt: datetime,
    reference_dt: datetime,
) -> dict[str, Any]:
    """Calculate Ashtottari Dasa (108-year cycle, different lord order from Vimsottari)."""

    nak_idx = nakshatra_index_for_longitude(moon_longitude)

    # Ashtottari Dasa: 8 lords with total 108 years
    # Order: Sun, Moon, Mars, Mercury, Saturn, Jupiter, Rahu, Venus
    ashtottari_lords = ["SUN", "MOON", "MARS", "MERCURY", "SATURN", "JUPITER", "RAHU", "VENUS"]
    ashtottari_dur = [6, 15, 8, 17, 10, 19, 12, 21]  # total 108

    # Starting index based on nakshatra index
    start_idx = nak_idx % 8
    lord_seq = ashtottari_lords[start_idx:] + ashtottari_lords[:start_idx]
    dur_seq = ashtottari_dur[start_idx:] + ashtottari_dur[:start_idx]

    nak = nakshatra_for_longitude(moon_longitude)
    nak_progress = ((moon_longitude - nak["start_longitude"]) % 360.0) / NAKSHATRA_LEN
    elapsed = dur_seq[0] * nak_progress

    current_date = birth_dt - timedelta(days=elapsed * 365.2425)
    dasas = []
    for lord, dur in zip(lord_seq, dur_seq):
        end_date = current_date + timedelta(days=dur * 365.2425)
        dasas.append({
            "lord": lord,
            "duration_years": dur,
            "start": format_local(current_date),
            "end": format_local(end_date),
        })
        current_date = end_date

    current = None
    for d in dasas:
        ds = datetime.strptime(d["start"], "%Y-%m-%d %H:%M").replace(tzinfo=birth_dt.tzinfo)
        de = datetime.strptime(d["end"], "%Y-%m-%d %H:%M").replace(tzinfo=birth_dt.tzinfo)
        if ds <= reference_dt <= de:
            current = d
            break

    return {"ashtottari_dasas": dasas, "current_ashtottari": current}


def _calc_kalachakra_dasa(
    planet_positions: dict[str, dict[str, Any]],
    birth_dt: datetime,
    reference_dt: datetime,
) -> dict[str, Any]:
    """Calculate Kalachakra Dasa (based on sign wheel and birth ascendant)."""
    return {
        "note": "Kalachakra Dasa 完整实现需要 Paka Lagna 计算，请在 V2 扩展",
        "current_kalachakra": None,
    }


# ─── Sign Index Table ─────────────────────────────────────────────────

def _build_sign_index_table() -> list[dict[str, Any]]:
    """Build the sign index reference table."""
    signs_cn = ["白羊", "金牛", "双子", "巨蟹", "狮子", "处女",
                "天秤", "天蝎", "射手", "摩羯", "水瓶", "双鱼"]
    signs_en = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
                "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"]
    return [{"index": i + 1, "name_en": signs_en[i], "name_zh": signs_cn[i]} for i in range(12)]


# ─── Expanded Meta ────────────────────────────────────────────────────

def _build_expanded_meta(
    birth_dt: datetime,
    birth_utc: str,
    reference_dt: datetime,
    reference_utc: str,
    latitude: float,
    longitude: float,
    house_system: str,
    zodiac: str,
    ayanamsha: str,
    sidereal: bool,
) -> dict[str, Any]:
    """Build expanded meta section."""
    # Use standard (non-DST) UTC offset for display.
    # birth_dt.utcoffset() includes DST (e.g. +9 for China Apr 1990),
    # but most astrology sources expect the zone's standard offset (e.g. +8 for China).
    from zoneinfo import ZoneInfo
    tz_label = str(birth_dt.tzinfo) if birth_dt.tzinfo else "UTC"
    std_offset_hours = 0.0
    try:
        # Get the standard (non-DST) offset by checking a date in standard time
        tz_obj = ZoneInfo(tz_label) if birth_dt.tzinfo else None
        if tz_obj:
            # Use January (Northern Hemisphere winter) to avoid DST
            std_dt = datetime(2024, 1, 1, tzinfo=tz_obj)
            std_off = std_dt.utcoffset()
            if std_off is not None:
                std_offset_hours = std_off.total_seconds() / 3600.0
    except Exception:
        std_offset_hours = 0.0

    if std_offset_hours >= 0:
        utc_offset_text = f"东{int(std_offset_hours)}区 / UTC+{std_offset_hours:.2f}"
        timezone_label = f"东{int(std_offset_hours)}区"
    else:
        utc_offset_text = f"西{int(abs(std_offset_hours))}区 / UTC{std_offset_hours:.2f}"
        timezone_label = f"西{int(abs(std_offset_hours))}区"

    # Ayanamsha value using Swiss Ephemeris
    ayanamsha_value = 0.0
    try:
        # Use swe.get_ayanamsa for current ayanamsha
        ayanamsha_value = round(swe.get_ayanamsa(jd_from_datetime(birth_dt)), 6)
    except Exception:
        pass

    sidereal_mode_label = "恒星黄道 (Sidereal)" if sidereal else "回归黄道 (Tropical)"
    ayanamsha_name = AYANAMSHA_NAMES.get(ayanamsha, ayanamsha)
    node_mode = "True Node"
    planet_position_mode = "Apparent"

    meta = {
        "birth_utc": birth_utc,
        "birth_local": format_local(birth_dt),
        "reference_utc": reference_utc,
        "reference_local": format_local(reference_dt),
        "latitude": latitude,
        "longitude": longitude,
        "house_system": house_system,
        "ayanamsha": ayanamsha,
        "ayanamsha_value": ayanamsha_value,
        "zodiac": "sidereal" if sidereal else "tropical",
        "ephemeris": "Swiss Ephemeris",
        "timezone_label": timezone_label,
        "utc_offset_text": utc_offset_text,
        "sidereal_mode_label": sidereal_mode_label,
        "ayanamsha_name": ayanamsha_name,
        "node_mode": node_mode,
        "planet_position_mode": planet_position_mode,
        "sign_index_table": _build_sign_index_table(),
    }
    return meta


# ─── Main Entry Point ────────────────────────────────────────────────

def calculate_vedic(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    """Main entry point for Vedic calculation."""
    birth = request["birth"]
    birth_dt = moment_to_local_datetime(birth["moment"])
    # Compute JD using standard UTC offset (ignoring historical DST).
    # Most astrology software uses the zone's standard offset regardless
    # of ephemeral DST rules. ZoneInfo applies DST (e.g. UTC+9 for
    # China 1990), but standard practice is fixed offset (e.g. UTC+8).
    std_utc_offset = 0.0
    try:
        from zoneinfo import ZoneInfo
        tz_obj = ZoneInfo(birth["moment"]["timezone"])
        std_dt = datetime(2024, 1, 1, tzinfo=tz_obj)
        std_off = std_dt.utcoffset()
        if std_off is not None:
            std_utc_offset = std_off.total_seconds() / 3600.0
    except Exception:
        pass
    # Compute JD using fixed standard offset
    _tz, _td = timezone, timedelta
    std_tz = _tz(_td(hours=std_utc_offset))
    std_birth_dt = datetime(
        int(birth["moment"]["year"]), int(birth["moment"]["month"]),
        int(birth["moment"]["day"]), int(birth["moment"]["hour"]),
        int(birth["moment"]["minute"]), tzinfo=std_tz,
    )
    standard_jd = jd_from_datetime(std_birth_dt)
    birth_utc_std = std_birth_dt.astimezone(_tz.utc).isoformat()

    # Use standard JD for ephemeris calculations
    birth_jd = standard_jd
    birth_utc = birth_utc_std

    # Reference time for dasa calculations (default: birth time if not provided)
    if "reference" in request:
        reference_dt = moment_to_local_datetime(request["reference"])
        _, reference_utc = moment_to_jd(request["reference"])
    else:
        reference_dt = birth_dt
        reference_utc = birth_utc

    latitude = float(birth["latitude"])
    longitude = float(birth["longitude"])
    zodiac = birth.get("zodiac", "sidereal_lahiri")
    house_system = birth.get("houseSystem", "whole_sign")
    # Extract ayanamsha from zodiac string to match what Swift sends
    if zodiac.startswith("sidereal_"):
        ayanamsha = zodiac[len("sidereal_"):]
    else:
        ayanamsha = "lahiri"

    # Set sidereal mode
    sidereal = set_zodiac_mode(zodiac)

    # Supported vargas (default: D1 and D9)
    requested_vargas = request.get("vargas", ["D1", "D9"])
    requested_dasas = request.get("dasas", ["vimshottari"])
    requested_yogas = request.get("yogas", True)
    requested_shadbala = request.get("shadbala", False)
    requested_full = request.get("full", False)

    if requested_full:
        requested_vargas = ["D1", "D9"]
        requested_dasas = ["vimshottari", "yogini", "ashtottari"]
        requested_yogas = True
        requested_shadbala = True

    # Calculate planet positions
    raw_positions = _resolve_vedic_positions(birth_jd, sidereal, warnings)

    # Get Moon nakshatra for tara calculations
    moon_nak_idx = None
    if "MOON" in raw_positions:
        moon_nak_idx = nakshatra_index_for_longitude(raw_positions["MOON"]["longitude"])

    # Add nakshatra details
    positions_with_nak = _add_nakshatra_details(raw_positions, moon_nak_idx)

    # Build Rasi chart
    rasi_chart = _calc_rasi_chart(
        birth_jd, latitude, longitude, house_system, sidereal, positions_with_nak, warnings
    )

    # Extract ASC longitude
    asc_lon = 0.0
    if rasi_chart and rasi_chart.get("angles"):
        for a in rasi_chart["angles"]:
            if a.get("id") == "ASC":
                asc_lon = a["longitude"]
                break

    # Build expanded meta
    meta = _build_expanded_meta(
        birth_dt, birth_utc, reference_dt, reference_utc,
        latitude, longitude, house_system, zodiac, ayanamsha, sidereal,
    )

    # Build response
    response: dict[str, Any] = {
        "meta": meta,
        "rasi_chart": rasi_chart,
        "planets": positions_with_nak,
        "warnings": warnings,
    }

    # ── Panchanga & Solar Day ──
    try:
        from astro_backend_jyotish_panchanga import calc_panchanga, calc_sunrise_sunset
        sun_lon = raw_positions.get("SUN", {}).get("longitude", 0.0)
        moon_lon = raw_positions.get("MOON", {}).get("longitude", 0.0)
        response["panchanga"] = calc_panchanga(sun_lon, moon_lon, birth_jd, utc_offset_hours=std_utc_offset)
        response["solar_day"] = calc_sunrise_sunset(birth_jd, latitude, longitude,
            utc_offset_hours=std_utc_offset,
            jd_0h=swe.julday(birth["moment"]["year"], birth["moment"]["month"], birth["moment"]["day"], 0.0) - 0.5)
    except Exception as e:
        warnings.append(f"Panchanga 计算失败：{e}")

    # ── Navamsa if requested ──
    if "D9" in requested_vargas or requested_full:
        response["navamsa"] = _calc_navamsa_chart(raw_positions)

    # ── Divisional Charts (16 vargas) ──
    try:
        from astro_backend_jyotish_divisional import (
            build_divisional_charts,
            build_moon_chart,
            build_bhava_chart,
        )
        # Build all 16 charts
        div_charts = build_divisional_charts(raw_positions, asc_lon)
        response["divisional_charts"] = div_charts

        # Moon Chart
        response["moon_chart"] = build_moon_chart(raw_positions, asc_lon)

        # Bhava Chart
        cusps = rasi_chart.get("cusps", []) if rasi_chart else []
        response["bhava_chart"] = build_bhava_chart(raw_positions, asc_lon, cusps)
    except Exception as e:
        warnings.append(f"Divisional chart 构建失败：{e}")

    # ── Upagrahas & Special Lagnas (for D1 and D9) ──
    try:
        from astro_backend_jyotish_aux_points import (
            calc_upagrahas,
            calc_special_lagnas,
            add_aux_points_to_chart,
        )
        sun_lon = raw_positions.get("SUN", {}).get("longitude", 0.0)
        moon_lon = raw_positions.get("MOON", {}).get("longitude", 0.0)
        upagrahas = calc_upagrahas(sun_lon, asc_lon, birth_jd)
        special_lagnas = calc_special_lagnas(sun_lon, moon_lon, asc_lon, birth_jd)
        response["upagrahas"] = upagrahas
        response["special_lagnas"] = special_lagnas

        if "divisional_charts" in response:
            if "D1" in response["divisional_charts"]:
                response["divisional_charts"]["D1"]["upagrahas"] = upagrahas
                response["divisional_charts"]["D1"]["special_lagnas"] = special_lagnas
            if "D9" in response["divisional_charts"]:
                # Map upagrahas through D9 varga
                from astro_backend_jyotish_varga import calc_varga_longitude
                from astro_backend_jyotish_divisional import _nakshatra_summary, _format_degree
                d9_upagrahas = []
                for upa in upagrahas:
                    v_lon = calc_varga_longitude(upa["longitude"], 9)
                    v_rasi = zodiac_sign_index(v_lon)
                    d9_upagrahas.append({
                        **upa,
                        "longitude": round(v_lon, 4),
                        "rasi": v_rasi,
                        "rasi_name": ["白羊","金牛","双子","巨蟹","狮子","处女",
                                      "天秤","天蝎","射手","摩羯","水瓶","双鱼"][v_rasi],
                        "degree_text": _format_degree(v_lon % 30),
                        "nakshatra": _nakshatra_summary(v_lon),
                    })
                response["divisional_charts"]["D9"]["upagrahas"] = d9_upagrahas

                # Map special lagnas through D9 varga
                d9_lagnas = []
                for lagna in special_lagnas:
                    v_lon = calc_varga_longitude(lagna["longitude"], 9)
                    v_rasi = zodiac_sign_index(v_lon)
                    d9_lagnas.append({
                        **lagna,
                        "longitude": round(v_lon, 4),
                        "rasi": v_rasi,
                        "degree_text": _format_degree(v_lon % 30),
                        "nakshatra": _nakshatra_summary(v_lon),
                    })
                response["divisional_charts"]["D9"]["special_lagnas"] = d9_lagnas
    except Exception as e:
        warnings.append(f"Aux points 计算失败：{e}")

    # ── Planet Relationships ──
    try:
        from astro_backend_jyotish_relationships import compute_planet_relationships
        response["planet_relationships"] = compute_planet_relationships(raw_positions)
    except Exception as e:
        warnings.append(f"Planet relationships 计算失败：{e}")

    # ── Arudha ──
    try:
        from astro_backend_jyotish_arudha import compute_arudha
        response["arudha"] = compute_arudha(asc_lon, raw_positions)
    except Exception as e:
        warnings.append(f"Arudha 计算失败：{e}")

    # ── Jaimini Karakas ──
    try:
        from astro_backend_jyotish_jaimini import compute_chara_karakas
        response["jaimini_karakas"] = compute_chara_karakas(raw_positions)
    except Exception as e:
        warnings.append(f"Jaimini 计算失败：{e}")

    # ── Ashtakavarga ──
    try:
        from astro_backend_jyotish_ashtakavarga import compute_ashtakavarga
        response["ashtakavarga"] = compute_ashtakavarga(raw_positions, asc_lon)
    except Exception as e:
        warnings.append(f"Ashtakavarga 计算失败：{e}")

    # ── Vimsottari Dasa (with Antardasha) ──
    if "MOON" in raw_positions:
        response["vimshottari"] = _calc_vimsottari_dasa(
            raw_positions["MOON"]["longitude"],
            birth_dt,
            reference_dt,
        )

    # Additional dasas
    if "yogini" in requested_dasas and "MOON" in raw_positions:
        response["yogini_dasa"] = _calc_yogini_dasa(
            raw_positions["MOON"]["longitude"],
            birth_dt,
            reference_dt,
        )

    if "ashtottari" in requested_dasas and "MOON" in raw_positions:
        response["ashtottari_dasa"] = _calc_ashtottari_dasa(
            raw_positions["MOON"]["longitude"],
            birth_dt,
            reference_dt,
        )

    if "kalachakra" in requested_dasas:
        response["kalachakra_dasa"] = _calc_kalachakra_dasa(
            raw_positions, birth_dt, reference_dt,
        )

    # ── Shadbala ──
    if requested_shadbala:
        try:
            from astro_backend_jyotish_shadbala import calc_shadbala
            shadbala = calc_shadbala(raw_positions, birth_jd, latitude, longitude, asc_longitude=asc_lon)
            if shadbala:
                response["shadbala"] = shadbala
        except Exception as e:
            warnings.append(f"Shadbala 计算失败：{e}")

    # ── Yogas ──
    if requested_yogas:
        try:
            from astro_backend_jyotish_yoga import detect_all_yogas
            asc_rasi = 0
            if rasi_chart and rasi_chart.get("angles"):
                for a in rasi_chart["angles"]:
                    if a.get("id") == "ASC":
                        asc_rasi = zodiac_sign_index(a["longitude"])
            yogas = detect_all_yogas(raw_positions, asc_rasi)
            if yogas:
                response["yogas"] = yogas
        except Exception as e:
            warnings.append(f"Yoga 检测失败：{e}")

    return response
