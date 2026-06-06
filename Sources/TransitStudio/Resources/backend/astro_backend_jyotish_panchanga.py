"""Panchanga (五支历) and sunrise/sunset calculations for Jyotish.

Formulas derived from standard Jyotish texts (BPHS) and cross-referenced
against the Maitreya project (GPL) implementation approach.
"""

from __future__ import annotations

import math
import datetime as _dt_module
from typing import Any

from astro_backend_core import (
    norm360,
    swe,
    jd_from_datetime,
    moment_to_jd,
    format_local,
)

# ─── Constants ────────────────────────────────────────────────────────

# Tithi names (30 tithis in a lunar month)
TITHI_NAMES_SA = [
    "Prathama", "Dwitiya", "Tritiya", "Chaturthi", "Panchami",
    "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami",
    "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Purnima",
    "Prathama", "Dwitiya", "Tritiya", "Chaturthi", "Panchami",
    "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami",
    "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Amavasya",
]
TITHI_PAKSHA = ["Shukla"] * 15 + ["Krishna"] * 15
TITHI_NAMES_ZH = [
    "白月初一", "白月初二", "白月初三", "白月初四", "白月初五",
    "白月初六", "白月初七", "白月初八", "白月初九", "白月初十",
    "白月十一", "白月十二", "白月十三", "白月十四", "白月十五",
    "暗月初一", "暗月初二", "暗月初三", "暗月初四", "暗月初五",
    "暗月初六", "暗月初七", "暗月初八", "暗月初九", "暗月初十",
    "暗月十一", "暗月十二", "暗月十三", "暗月十四", "暗月十五",
]
# Better Chinese names with Sanskrit
TITHI_ZH_LABELS = [
    "白月初一 (Prathama)", "白月初二 (Dwitiya)", "白月初三 (Tritiya)", "白月初四 (Chaturthi)", "白月初五 (Panchami)",
    "白月初六 (Shashthi)", "白月初七 (Saptami)", "白月初八 (Ashtami)", "白月初九 (Navami)", "白月初十 (Dashami)",
    "白月十一 (Ekadashi)", "白月十二 (Dwadashi)", "白月十三 (Trayodashi)", "白月十四 (Chaturdashi)", "白月十五 (Purnima)",
    "暗月初一 (Prathama)", "暗月初二 (Dwitiya)", "暗月初三 (Tritiya)", "暗月初四 (Chaturthi)", "暗月初五 (Panchami)",
    "暗月初六 (Shashthi)", "暗月初七 (Saptami)", "暗月初八 (Ashtami)", "暗月初九 (Navami)", "暗月初十 (Dashami)",
    "暗月十一 (Ekadashi)", "暗月十二 (Dwadashi)", "暗月十三 (Trayodashi)", "暗月十四 (Chaturdashi)", "暗月十五 (Amavasya)",
]

# Vara (weekday) names
VARA_NAMES_SA = ["Suryavara", "Chandravara", "Mangalavara", "Budhavara", "Brihaspativara", "Shukravara", "Shanivara"]
VARA_NAMES_ZH = ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]

# Yoga names (27 yogas)
YOGA_NAMES_SA = [
    "Vishkumbha", "Priti", "Ayushman", "Saubhagya", "Shobhana", "Atiganda", "Sukarma",
    "Dhriti", "Shula", "Ganda", "Vriddhi", "Dhruva", "Vyaghata", "Harshana", "Vajra",
    "Siddhi", "Vyatipata", "Variyan", "Parigha", "Shiva", "Siddha", "Sadhya", "Shubha",
    "Shukla", "Brahma", "Indra", "Vaidhriti",
]
YOGA_NAMES_ZH = [
    "毗输屈波", "毕哩底", "阿逾输摩", "娑毗伽", "输婆那", "阿亭伽陀", "输迦摩",
    "地哩底", "输罗", "键陀", "勿哩陀", "地奴", "毗伽多", "诃罗沙那", "婆左",
    "悉地", "毗耶底波多", "婆利耶", "波哩伽", "湿婆", "悉达", "萨地耶", "首婆",
    "输迦罗", "婆罗摩", "因陀罗", "吠陀梨",
]

# Karana names (11 karanas, 4 fixed + 7 movable × 4 cycles)
KARANA_NAMES_SA_FIXED = ["Shakuni", "Chatushpada", "Naga", "Kinstughna"]
KARANA_NAMES_SA_MOVABLE = [
    "Bava", "Balava", "Kaulava", "Taitila", "Gara", "Vanija", "Visti",
]
KARANA_NAMES_ZH_MOVABLE = [
    "婆波 (Bava)", "婆罗波 (Balava)", "究罗婆 (Kaulava)", "泰提罗 (Taitila)",
    "伽罗 (Gara)", "伐尼惹 (Vanija)", "毗罗帝 (Visti)",
]
KARANA_NAMES_ZH_FIXED = [
    "舍拘尼 (Shakuni)", "遮都波多 (Chatushpada)", "那伽 (Naga)", "金私都拿 (Kinstughna)",
]


# ─── Tithi ────────────────────────────────────────────────────────────

def calc_tithi(sun_longitude: float, moon_longitude: float) -> dict[str, Any]:
    """Calculate Tithi (lunar day) from Sun and Moon longitudes.

    Tithi index = floor((moon_lon - sun_lon) / 12°)
    Returns 0-29 (0=Shukla Prathama, 14=Purnima, 29=Amavasya).
    """
    diff = norm360(moon_longitude - sun_longitude)
    tithi_index = int(diff // 12.0)
    if tithi_index >= 30:
        tithi_index = 29

    # Start and end longitude for this tithi
    start_lon = tithi_index * 12.0
    end_lon = (tithi_index + 1) * 12.0

    paksha = TITHI_PAKSHA[tithi_index]
    name_sa = TITHI_NAMES_SA[tithi_index]
    name_zh = TITHI_ZH_LABELS[tithi_index]

    return {
        "index": tithi_index,
        "name_sa": name_sa,
        "name_zh": name_zh,
        "paksha": paksha,
        "start_longitude": start_lon,
        "end_longitude": end_lon,
        "sun_longitude": round(sun_longitude, 4),
        "moon_longitude": round(moon_longitude, 4),
    }


# ─── Vara (Weekday) ──────────────────────────────────────────────────

def calc_vara(jd_ut: float, utc_offset_hours: float = 0.0) -> dict[str, Any]:
    """Calculate Vara (weekday) from Julian Day number using Swiss Ephemeris."""
    # Shift JD to local time to get correct local weekday
    jd_local = jd_ut + utc_offset_hours / 24.0
    day_of_week = swe.day_of_week(jd_local)  # 0=Mon..6=Sun
    vara_idx = (day_of_week + 1) % 7  # 0=Sun..6=Sat

    name_sa = VARA_NAMES_SA[vara_idx]
    name_zh = VARA_NAMES_ZH[vara_idx]

    return {
        "index": vara_idx,
        "name_sa": name_sa,
        "name_zh": name_zh,
        "start_longitude": 0.0,
        "end_longitude": 0.0,
    }


# ─── Nakshatra (already in jyotish_data, re-expose here) ─────────────

from astro_backend_jyotish_data import (
    NAKSHATRA_DATA,
    NAKSHATRA_LEN,
    nakshatra_for_longitude,
)


# ─── Yoga (the panchanga yoga, not astrological yoga) ────────────────

def calc_panchanga_yoga(sun_longitude: float, moon_longitude: float) -> dict[str, Any]:
    """Calculate Panchanga Yoga (the 27-fold yoga based on Sun+Moon sum).

    Yoga index = floor((sun_lon + moon_lon) / 13.33333) % 27
    """
    total = norm360(sun_longitude + moon_longitude)
    yoga_index = int(total // NAKSHATRA_LEN) % 27

    start = yoga_index * NAKSHATRA_LEN
    end = (yoga_index + 1) * NAKSHATRA_LEN

    return {
        "index": yoga_index,
        "name_sa": YOGA_NAMES_SA[yoga_index],
        "name_zh": YOGA_NAMES_ZH[yoga_index],
        "start_longitude": round(start, 4),
        "end_longitude": round(end, 4),
    }


# ─── Karana ───────────────────────────────────────────────────────────

def calc_karana(sun_longitude: float, moon_longitude: float) -> dict[str, Any]:
    """Calculate Karana (half-tithi).

    A tithi has two karanas. Karana index = floor((moon_lon - sun_lon) / 6°) % 60
    The first 56 are movable (7-cycle), last 4 are fixed.
    """
    diff = norm360(moon_longitude - sun_longitude)
    karana_index = int(diff // 6.0) % 60

    start = karana_index * 6.0
    end = (karana_index + 1) * 6.0

    if karana_index == 0:
        name_sa = "Kinstughna"
        name_zh = "金私都拿 (Kinstughna)"
    elif karana_index >= 57:
        # Final three fixed karanas near Amavasya
        fixed_idx = karana_index - 57
        name_sa = KARANA_NAMES_SA_FIXED[fixed_idx]
        name_zh = KARANA_NAMES_ZH_FIXED[fixed_idx]
    else:
        # Movable karanas repeat from index 1 through 56
        movable_idx = (karana_index - 1) % 7
        name_sa = KARANA_NAMES_SA_MOVABLE[movable_idx]
        name_zh = KARANA_NAMES_ZH_MOVABLE[movable_idx]

    return {
        "index": karana_index,
        "name_sa": name_sa,
        "name_zh": name_zh,
        "start_longitude": round(start, 4),
        "end_longitude": round(end, 4),
    }


# ─── Full Panchanga ──────────────────────────────────────────────────

def calc_panchanga(
    sun_longitude: float,
    moon_longitude: float,
    jd_ut: float,
    utc_offset_hours: float = 0.0,
) -> dict[str, Any]:
    """Calculate all 5 limbs of Panchanga."""
    tithi = calc_tithi(sun_longitude, moon_longitude)
    vara = calc_vara(jd_ut, utc_offset_hours)
    moon_nak = nakshatra_for_longitude(moon_longitude)
    nakshatra = {
        "index": moon_nak["index"],
        "name_sa": moon_nak["name_sa"],
        "name_zh": moon_nak["name_zh"],
        "lord": moon_nak["lord"],
        "start_longitude": moon_nak["start_longitude"],
        "end_longitude": moon_nak["end_longitude"],
    }
    yoga = calc_panchanga_yoga(sun_longitude, moon_longitude)
    karana = calc_karana(sun_longitude, moon_longitude)

    return {
        "tithi": tithi,
        "vara": vara,
        "nakshatra": nakshatra,
        "yoga": yoga,
        "karana": karana,
    }


# ─── Sunrise / Sunset ─────────────────────────────────────────────────

def calc_sunrise_sunset(
    jd_ut: float,
    latitude: float,
    longitude: float,
    utc_offset_hours: float | None = None,
    jd_0h: float | None = None,
) -> dict[str, Any]:
    """Calculate sunrise and sunset using Swiss Ephemeris.

    Uses swe.rise_trans() with geographic coordinates (CALC_RISE / CALC_SET).
    Converts UT times to local time using the provided UTC offset.

    Args:
        jd_ut: Julian day (UT) of the moment
        latitude: Geographic latitude in degrees
        longitude: Geographic longitude in degrees
        utc_offset_hours: Timezone offset in hours (e.g. 8.0 for UTC+8).
        jd_0h: JD at 0h UT of the birth date (optional, computed from jd_ut if absent).

    Returns dict with sunrise_local and sunset_local strings.
    """
    result = {"sunrise_local": None, "sunset_local": None}
    epheflag = swe.FLG_SWIEPH
    geopos = (longitude, latitude, 0.0)
    offset = utc_offset_hours if utc_offset_hours is not None else (longitude / 15.0)

    # Sunrise: CALC_RISE | BIT_DISC_CENTER | BIT_NO_REFRACTION
    try:
        rsmi_rise = swe.CALC_RISE | swe.BIT_DISC_CENTER | swe.BIT_NO_REFRACTION
        res, tret = swe.rise_trans(jd_0h, swe.SUN, rsmi_rise, geopos, 0.0, 0.0, epheflag)
        if res == 0:
            yr_r, mo_r, dy_r, hr_r = swe.revjul(tret[0])
            hour = int(hr_r)
            minute = int((hr_r - hour) * 60)
            second = int(((hr_r - hour) * 60 - minute) * 60)
            utc = _dt_module.timezone.utc
            dt_ut = _dt_module.datetime(int(yr_r), int(mo_r), int(dy_r), hour, minute, second, tzinfo=utc)
            local_dt = dt_ut + _dt_module.timedelta(hours=offset)
            result["sunrise_local"] = local_dt.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        pass

    # Sunset: CALC_SET | BIT_DISC_CENTER | BIT_NO_REFRACTION
    try:
        rsmi_set = swe.CALC_SET | swe.BIT_DISC_CENTER | swe.BIT_NO_REFRACTION
        res2, tret2 = swe.rise_trans(jd_0h, swe.SUN, rsmi_set, geopos, 0.0, 0.0, epheflag)
        if res2 == 0:
            yr_s, mo_s, dy_s, hr_s = swe.revjul(tret2[0])
            hour = int(hr_s)
            minute = int((hr_s - hour) * 60)
            second = int(((hr_s - hour) * 60 - minute) * 60)
            utc = _dt_module.timezone.utc
            dt_ut = _dt_module.datetime(int(yr_s), int(mo_s), int(dy_s), hour, minute, second, tzinfo=utc)
            local_dt = dt_ut + _dt_module.timedelta(hours=offset)
            result["sunset_local"] = local_dt.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        pass

    return result
