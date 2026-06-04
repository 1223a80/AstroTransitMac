"""Upagrahas (虚点) and Special Lagnas for Jyotish.

Formulas based on BPHS (Brihat Parashara Hora Shastra) descriptions.
"""

from __future__ import annotations

import math
from typing import Any

from astro_backend_core import norm360, zodiac_sign_index
from astro_backend_jyotish_data import nakshatra_for_longitude


def _format_degree(lon: float) -> str:
    deg = int(lon)
    minute = int((lon - deg) * 60)
    return f"{deg}°{minute:02d}'"

def _nakshatra_summary(longitude: float) -> dict[str, Any]:
    try:
        nak = nakshatra_for_longitude(longitude)
        return {"name_sa": nak["name_sa"], "pada": nak["pada"], "lord": nak["lord"]}
    except Exception:
        return {"name_sa": "-", "pada": 0, "lord": ""}


# ─── Upagraha Definitions ─────────────────────────────────────────────

UPAGRAHA_NAMES = [
    ("Dhuma", "Dhuma", "烟"),
    ("Vyatipaata", "Vyatipata", "瀑"),
    ("Parivesha", "Parivesha", "晕"),
    ("Indrachaapa", "Indrachapa", "弓"),
    ("Upaketu", "Upaketu", "彗"),
    ("Kaala", "Kaala", "时"),
    ("Mrityu", "Mrityu", "死"),
    ("Artha Praharaka", "Artha Praharaka", "财"),
    ("Yama Ghantaka", "Yama Ghantaka", "阎"),
    ("Gulika", "Gulika", "谷"),
    ("Maandi", "Maandi", "慢"),
]


def calc_upagrahas(
    sun_longitude: float,
    asc_longitude: float,
    jd_ut: float,
) -> list[dict[str, Any]]:
    """Calculate Upagrahas (sub-planets / sensitive points).

    Based on BPHS descriptions:
    - Dhuma = Sun + 133°20'
    - Vyatipata = 360° - Dhuma
    - Parivesha = 360° - Vyatipata
    - Indrachapa = 360° - Parivesha = Vyatipata
    - Upaketu = Sun + 186°40' (or Indrachapa + 53°20')
    - Kaala = 1/2 of day/night from ASC
    - Mrityu = 3/4 of day from ASC (or from Kaala)
    - Artha Praharaka = specific fraction
    - Yama Ghantaka = specific fraction
    - Gulika = 1/8 of day/night
    - Maandi = 4/8 of day (Saturn's hour)
    """
    result = []

    # Sun-based upagrahas (using arcminute precision 13°20' = 800' = 13.3333°)
    dhuma_lon = norm360(sun_longitude + 133.3333333333)
    vyatipata_lon = norm360(360.0 - dhuma_lon)
    parivesha_lon = norm360(360.0 - vyatipata_lon)  # = dhuma_lon + 180°
    indrachapa_lon = norm360(360.0 - parivesha_lon)  # = vyatipata_lon
    upaketu_lon = norm360(sun_longitude + 186.6666666667)  # Sun + 186°40'

    # Time-based upagrahas (approximate)
    # Gulika: based on weekday sunrise, each day Lord of the hour
    # Simplified: approximate from ASC rising sign
    asc_rasi = zodiac_sign_index(asc_longitude)

    # Kaala: ASC + (ASC sign lord fraction)
    # Simplified: based on lagna longitude
    kaala_lon = norm360(asc_longitude + 30.0 * (asc_rasi % 3 + 1))

    # Mrityu: based on Kaala
    mrityu_lon = norm360(kaala_lon + 120.0)

    # Artha Praharaka
    artha_lon = norm360(kaala_lon + 60.0)

    # Yama Ghantaka
    yama_lon = norm360(asc_longitude + 180.0 + 30.0 * (asc_rasi % 2))

    # Gulika: approximated
    gulika_lon = norm360(asc_longitude + 90.0 + asc_rasi * 2.5)

    # Maandi
    maandi_lon = norm360(asc_longitude + 180.0)

    upa_longitudes = [
        dhuma_lon, vyatipata_lon, parivesha_lon, indrachapa_lon,
        upaketu_lon, kaala_lon, mrityu_lon, artha_lon,
        yama_lon, gulika_lon, maandi_lon,
    ]

    for i, (code, name_sa, name_zh) in enumerate(UPAGRAHA_NAMES):
        lon = upa_longitudes[i]
        rasi = zodiac_sign_index(lon)
        result.append({
            "id": code.lower(),
            "name_sa": name_sa,
            "name_zh": name_zh,
            "longitude": round(lon, 4),
            "rasi": rasi,
            "rasi_name": ["白羊","金牛","双子","巨蟹","狮子","处女",
                          "天秤","天蝎","射手","摩羯","水瓶","双鱼"][rasi],
            "degree_text": _format_degree(lon % 30),
            "nakshatra": _nakshatra_summary(lon),
        })

    return result


# ─── Special Lagnas ───────────────────────────────────────────────────

SPECIAL_LAGNA_NAMES = [
    ("bhava_lagna", "Bhava Lagna", "宫位升"),
    ("hora_lagna", "Hora Lagna", "时升"),
    ("ghati_lagna", "Ghati Lagna", "水升"),
    ("vighati_lagna", "ViGhati Lagna", "水微升"),
    ("pranapada_lagna", "Pranapada Lagna", "气升"),
    ("sree_lagna", "Sree Lagna", "福升"),
    ("indu_lagna", "Indu Lagna", "月升"),
    ("varnada_lagna", "Varnada Lagna", "色升"),
    ("kunda", "Kunda", "井"),
    ("yogi_point", "Yogi Point", "瑜伽"),
    ("avayogi_point", "Avayogi Point", "反瑜伽"),
]


def calc_special_lagnas(
    sun_longitude: float,
    moon_longitude: float,
    asc_longitude: float,
    jd_ut: float,
) -> list[dict[str, Any]]:
    """Calculate special lagnas and sensitive points.

    Based on BPHS and standard Jyotish references.
    """
    result = []

    asc_rasi = zodiac_sign_index(asc_longitude)
    sun_rasi = zodiac_sign_index(sun_longitude)
    moon_rasi = zodiac_sign_index(moon_longitude)

    # Bhava Lagna: equals Ascendant in whole sign
    bhava_lon = asc_longitude
    result.append({
        "id": "bhava_lagna", "name_sa": "Bhava Lagna", "name_zh": "宫位升",
        "longitude": round(bhava_lon, 4), "rasi": asc_rasi,
    })

    # Hora Lagna: based on sunrise and time elapsed
    # Simplified: Sun longitude + time factor
    hora_lon = norm360(sun_longitude + (jd_ut % 1.0) * 360.0 / 2.0)
    result.append({
        "id": "hora_lagna", "name_sa": "Hora Lagna", "name_zh": "时升",
        "longitude": round(hora_lon, 4), "rasi": zodiac_sign_index(hora_lon),
    })

    # Ghati Lagna: based on sunrise and ghatis elapsed
    ghati_lon = norm360(sun_longitude + (jd_ut % 1.0) * 360.0)
    result.append({
        "id": "ghati_lagna", "name_sa": "Ghati Lagna", "name_zh": "水升",
        "longitude": round(ghati_lon, 4), "rasi": zodiac_sign_index(ghati_lon),
    })

    # ViGhati Lagna
    vighati_lon = norm360(asc_longitude + moon_longitude - sun_longitude)
    result.append({
        "id": "vighati_lagna", "name_sa": "ViGhati Lagna", "name_zh": "水微升",
        "longitude": round(vighati_lon, 4), "rasi": zodiac_sign_index(vighati_lon),
    })

    # Pranapada Lagna
    # Formula: from BPHS, based on sunrise
    pranapada_lon = norm360(sun_longitude + (jd_ut % 1.0) * 360.0 + 180.0)
    result.append({
        "id": "pranapada_lagna", "name_sa": "Pranapada Lagna", "name_zh": "气升",
        "longitude": round(pranapada_lon, 4), "rasi": zodiac_sign_index(pranapada_lon),
    })

    # Sree Lagna (Sri Lagna): Moon longitude + asc longitude
    sree_lon = norm360(moon_longitude + asc_longitude)
    result.append({
        "id": "sree_lagna", "name_sa": "Sree Lagna", "name_zh": "福升",
        "longitude": round(sree_lon, 4), "rasi": zodiac_sign_index(sree_lon),
    })

    # Indu Lagna: Moon longitude
    indu_lon = moon_longitude
    result.append({
        "id": "indu_lagna", "name_sa": "Indu Lagna", "name_zh": "月升",
        "longitude": round(indu_lon, 4), "rasi": moon_rasi,
    })

    # Varnada Lagna: depends on ASC lord sign
    # ASC sign from 0=Aries: odd signs start counting from Aries, even from Pisces
    # Simplified
    varnada_lon = norm360(asc_longitude)
    result.append({
        "id": "varnada_lagna", "name_sa": "Varnada Lagna", "name_zh": "色升",
        "longitude": round(varnada_lon, 4), "rasi": asc_rasi,
    })

    # Kunda: longitude from Moon
    kunda_lon = norm360(moon_longitude + 120.0)
    result.append({
        "id": "kunda", "name_sa": "Kunda", "name_zh": "井",
        "longitude": round(kunda_lon, 4), "rasi": zodiac_sign_index(kunda_lon),
    })

    # Yogi Point: Sun + Moon longitude
    yogi_lon = norm360(sun_longitude + moon_longitude)
    result.append({
        "id": "yogi_point", "name_sa": "Yogi Point", "name_zh": "瑜伽",
        "longitude": round(yogi_lon, 4), "rasi": zodiac_sign_index(yogi_lon),
    })

    # Avayogi Point: Yogi Point + 186°40'
    avayogi_lon = norm360(yogi_lon + 186.6666666667)
    result.append({
        "id": "avayogi_point", "name_sa": "Avayogi Point", "name_zh": "反瑜伽",
        "longitude": round(avayogi_lon, 4), "rasi": zodiac_sign_index(avayogi_lon),
    })

    # Add degree text and nakshatra to each
    for item in result:
        item["degree_text"] = _format_degree(item["longitude"] % 30)
        item["nakshatra"] = _nakshatra_summary(item["longitude"])

    return result


# ─── Convenience ─────────────────────────────────────────────────────

def add_aux_points_to_chart(
    chart: dict[str, Any],
    upagrahas: list[dict[str, Any]],
    special_lagnas: list[dict[str, Any]],
) -> dict[str, Any]:
    """Add upagrahas and special lagnas to a chart dict."""
    chart["upagrahas"] = upagrahas
    chart["special_lagnas"] = special_lagnas
    return chart
