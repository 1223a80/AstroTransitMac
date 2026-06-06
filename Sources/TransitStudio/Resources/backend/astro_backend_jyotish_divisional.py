"""Divisional chart builder for Jyotish (D1 through D60).

Builds full chart objects for each requested varga, reusing the same
chart schema as the Rasi (D1) chart. Formulas sourced from Maitreya
Varga.cpp:calcVarga() approach.
"""

from __future__ import annotations

from typing import Any

from astro_backend_core import SIGNS, format_longitude, zodiac_sign_index
from astro_backend_jyotish_data import (
    VARGA_DEFINITIONS,
    NAKSHATRA_LEN,
    nakshatra_for_longitude,
)
from astro_backend_jyotish_varga import calc_varga, calc_varga_longitude, varga_rasi_for_planet


# ─── Chart Schema ─────────────────────────────────────────────────────

def _format_degree(lon: float) -> str:
    """Format longitude as degrees°minutes'."""
    lon = lon % 30.0
    deg = int(lon)
    minute = int((lon - deg) * 60)
    return f"{deg}°{minute:02d}'"


def _nakshatra_summary(longitude: float) -> dict[str, Any]:
    """Brief nakshatra for a varga chart entry."""
    try:
        nak = nakshatra_for_longitude(longitude)
        return {
            "name_sa": nak["name_sa"],
            "pada": nak["pada"],
            "lord": nak["lord"],
        }
    except Exception:
        return {"name_sa": "-", "pada": 0, "lord": ""}


# ─── Varga Name Tables ────────────────────────────────────────────────

VARGA_NAMES: dict[str, tuple[str, str]] = {
    "D1": ("Rasi", "本命盘"),
    "D2": ("Hora", "时盘"),
    "D3": ("Drekkana", "三分盘"),
    "D4": ("Chaturthamsa", "四分盘"),
    "D5": ("Panchamsa", "五分盘"),
    "D6": ("Shashthamsa", "六分盘"),
    "D7": ("Saptamamsa", "七分盘"),
    "D8": ("Ashtamamsa", "八分盘"),
    "D9": ("Navamamsa", "九分盘"),
    "D10": ("Dasamsa", "十分盘"),
    "D11": ("Rudramsa", "十一分盘"),
    "D12": ("Dvadasamsa", "十二分盘"),
    "D16": ("Shodasamsa", "十六分盘"),
    "D20": ("Vimsamsa", "二十分盘"),
    "D24": ("Siddhamsa", "二十四分盘"),
    "D27": ("Bhamsa", "二十七分盘"),
    "D30": ("Trimsamsa", "三十分盘"),
    "D40": ("Chatvarimsamsa", "四十分盘"),
    "D45": ("Akshavedamsa", "四十五分盘"),
    "D60": ("Shashtiamsa", "六十分盘"),
}

# The 16 varga ids we need
REQUIRED_VARGA_IDS = ["D1", "D2", "D3", "D4", "D7", "D9", "D10", "D12",
                      "D16", "D20", "D24", "D27", "D30", "D40", "D45", "D60"]


# ─── Build a single varga chart ──────────────────────────────────────

def _build_varga_chart(
    varga_id: str,
    varga_num: int,
    planet_positions: dict[str, dict[str, Any]],
    asc_longitude: float,
) -> dict[str, Any]:
    """Build a varga chart with planets placed by varga rasi.

    Returns a standardized chart dict.
    """
    name_sa, name_zh = VARGA_NAMES.get(varga_id, (varga_id, varga_id))
    asc_v_lon = calc_varga_longitude(asc_longitude, varga_num)
    asc_v_rasi = zodiac_sign_index(asc_v_lon)
    asc_v_deg = asc_v_lon % 30.0

    # Calculate varga rasi for each planet
    varga_planets = {}
    for pid, pos in planet_positions.items():
        v_lon = calc_varga_longitude(pos["longitude"], varga_num)  # full varga longitude
        v_rasi = zodiac_sign_index(v_lon)
        v_deg = v_lon % 30.0
        house = ((v_rasi - asc_v_rasi) % 12) + 1
        varga_planets[pid] = {
            "body_id": pid,
            "name": pos.get("name", pid),
            "longitude": pos["longitude"],  # original natal longitude
            "varga_longitude": round(v_lon, 4),
            "varga_rasi": v_rasi,
            "varga_rasi_sign": [
                "白羊", "金牛", "双子", "巨蟹", "狮子", "处女",
                "天秤", "天蝎", "射手", "摩羯", "水瓶", "双鱼"
            ][v_rasi],
            "varga_degree": round(v_deg, 2),
            "house": house,
            "degree_text": _format_degree(v_deg),
            "nakshatra": _nakshatra_summary(v_lon),  # nakshatra from varga longitude
        }

    # ASC in varga
    varga_planets["ASC"] = {
        "body_id": "ASC",
        "name": "Asc",
        "longitude": asc_longitude,
        "varga_longitude": round(asc_v_lon, 4),
        "varga_rasi": asc_v_rasi,
        "varga_rasi_sign": [
            "白羊", "金牛", "双子", "巨蟹", "狮子", "处女",
            "天秤", "天蝎", "射手", "摩羯", "水瓶", "双鱼"
        ][asc_v_rasi],
        "varga_degree": round(asc_v_deg, 2),
        "house": 1,
        "degree_text": _format_degree(asc_v_deg),
        "nakshatra": _nakshatra_summary(asc_v_lon),
    }

    chart = {
        "chart_id": varga_id,
        "chart_name": f"D{varga_num} ({name_sa}/{name_zh})",
        "varga_num": varga_num,
        "planets": varga_planets,
    }

    # For D1 and D9: add upagrahas and special lagnas placeholders
    if varga_id in ("D1", "D9"):
        chart["upagrahas"] = []
        chart["special_lagnas"] = []

    return chart


# ─── Build all divisional charts ─────────────────────────────────────

def build_divisional_charts(
    planet_positions: dict[str, dict[str, Any]],
    asc_longitude: float,
    varga_ids: list[str] | None = None,
) -> dict[str, dict[str, Any]]:
    """Build requested divisional charts.

    Args:
        planet_positions: Dict of planet positions from _resolve_vedic_positions
        asc_longitude: Ascendant longitude
        varga_ids: List of varga IDs to build (default: REQUIRED_VARGA_IDS)

    Returns:
        Dict mapping varga_id to chart dict.
    """
    if varga_ids is None:
        varga_ids = REQUIRED_VARGA_IDS

    charts = {}
    for vg_id in varga_ids:
        # Find the varga definition
        vg_num = None
        for vd in VARGA_DEFINITIONS:
            if vd["id"] == vg_id:
                vg_num = vd["num"]
                break
        if vg_num is None:
            continue

        chart = _build_varga_chart(vg_id, vg_num, planet_positions, asc_longitude)
        charts[vg_id] = chart

    return charts


# ─── Moon Chart ───────────────────────────────────────────────────────

def build_moon_chart(
    planet_positions: dict[str, dict[str, Any]],
    asc_longitude: float,
) -> dict[str, Any]:
    """Build Moon Chart (Chandra Rasi) — planets placed relative to Moon sign.

    In Moon chart, the Moon's sign becomes the 1st house (Ascendant).
    All planets are repositioned relative to Moon's rasi.
    """
    moon_lon = planet_positions.get("MOON", {}).get("longitude", 0.0)
    moon_rasi = zodiac_sign_index(moon_lon)

    # Moon chart: shift all planets so Moon's rasi = 0 (ASC)
    planets = {}
    for pid, pos in planet_positions.items():
        orig_rasi = zodiac_sign_index(pos["longitude"])
        shifted_rasi = (orig_rasi - moon_rasi) % 12
        shifted_deg = pos["longitude"] % 30.0
        planets[pid] = {
            "body_id": pid,
            "name": pos.get("name", pid),
            "longitude": pos["longitude"],
            "rasi": shifted_rasi,
            "rasi_name": [
                "白羊", "金牛", "双子", "巨蟹", "狮子", "处女",
                "天秤", "天蝎", "射手", "摩羯", "水瓶", "双鱼"
            ][shifted_rasi],
            "degree_text": _format_degree(shifted_deg),
            "house": shifted_rasi + 1,
            "nakshatra": _nakshatra_summary(pos["longitude"]),
        }

    # ASC in moon chart
    asc_rasi = zodiac_sign_index(asc_longitude)
    shifted_asc_rasi = (asc_rasi - moon_rasi) % 12
    planets["ASC"] = {
        "body_id": "ASC",
        "name": "Asc",
        "longitude": asc_longitude,
        "rasi": shifted_asc_rasi,
        "rasi_name": [
            "白羊", "金牛", "双子", "巨蟹", "狮子", "处女",
            "天秤", "天蝎", "射手", "摩羯", "水瓶", "双鱼"
        ][shifted_asc_rasi],
        "degree_text": _format_degree(asc_longitude % 30.0),
        "house": shifted_asc_rasi + 1,
        "nakshatra": _nakshatra_summary(asc_longitude),
    }

    return {
        "chart_id": "MOON",
        "chart_name": "Moon Chart (Chandra Rasi)",
        "moon_rasi": moon_rasi,
        "planets": planets,
    }


# ─── Bhava Chart ──────────────────────────────────────────────────────

def build_bhava_chart(
    planet_positions: dict[str, dict[str, Any]],
    asc_longitude: float,
    cusps: list[float] | None = None,
) -> dict[str, Any]:
    """Build Bhava Chart (house chart).

    In Bhava chart, each planet is placed in its bhava (house) based on
    the actual cusp positions, not whole-sign. This is equivalent to the
    D1 chart but with house numbering based on cusps.
    """
    # For whole sign, Bhava is essentially same as Rasi chart but house
    # numbering follows actual cusp positions
    asc_rasi = zodiac_sign_index(asc_longitude)

    planets = {}
    for pid, pos in planet_positions.items():
        rasi = zodiac_sign_index(pos["longitude"])
        house_num = (rasi - asc_rasi) % 12 + 1
        planets[pid] = {
            "body_id": pid,
            "name": pos.get("name", pid),
            "longitude": pos["longitude"],
            "house": house_num,
            "rasi": rasi,
            "rasi_name": ["白羊","金牛","双子","巨蟹","狮子","处女",
                          "天秤","天蝎","射手","摩羯","水瓶","双鱼"][rasi],
            "degree_text": pos.get("degree_text", ""),
            "nakshatra": _nakshatra_summary(pos["longitude"]),
        }

    planets["ASC"] = {
        "body_id": "ASC",
        "name": "Asc",
        "longitude": asc_longitude,
        "house": 1,
        "rasi": asc_rasi,
        "rasi_name": ["白羊","金牛","双子","巨蟹","狮子","处女",
                      "天秤","天蝎","射手","摩羯","水瓶","双鱼"][asc_rasi],
        "degree_text": _format_degree(asc_longitude),
        "nakshatra": _nakshatra_summary(asc_longitude),
    }

    # Angle points for Bhava
    angles = []
    for angle_id, angle_name, offset in [
        ("ASC", "Asc", 0),
        ("MC", "MC", 90),
        ("DSC", "Dsc", 180),
        ("IC", "IC", 270),
    ]:
        angle_lon = (asc_longitude + offset * 30.0) % 360.0
        sign_idx = zodiac_sign_index(angle_lon)
        _, deg_text = format_longitude(angle_lon)
        angles.append({
            "id": angle_id,
            "name": angle_name,
            "longitude": angle_lon,
            "sign": SIGNS[sign_idx],
            "degree_text": deg_text,
            "house": 1 if offset == 0 else (offset // 30 + 1),
        })

    return {
        "chart_id": "BHAVA",
        "chart_name": "Bhava Chart",
        "angles": angles,
        "planets": planets,
    }
