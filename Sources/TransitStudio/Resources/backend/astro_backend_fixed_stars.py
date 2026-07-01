"""Fixed star catalog and conjunction detection for TransitStudio.

Uses Swiss Ephemeris ``swe.fixstar_ut()`` for accurate positions.
See ``docs/expansion-002/star-catalog.md`` for the full catalog documentation.
"""
from __future__ import annotations

from typing import Any

from astro_backend_core import swe

# ---------------------------------------------------------------------------
# Star catalog
# ---------------------------------------------------------------------------
# Each entry: (name, swe_name, mag, nature, base_orb)
# nature is a human-readable planetary nature string.
# swe_name is the name passed to swe.fixstar_ut().
# orb is the half-orb for conjunction detection.

STAR_CATALOG: list[dict[str, Any]] = [
    # ---- Royal stars (orb 2.0 deg) ----
    {"name": "Aldebaran", "swe_name": "Aldebaran", "mag": 0.87, "nature": "火星", "orb": 2.0, "keyword": "东方守护者"},
    {"name": "Regulus", "swe_name": "Regulus", "mag": 1.36, "nature": "火/木星", "orb": 2.0, "keyword": "北方守护者, 王权"},
    {"name": "Antares", "swe_name": "Antares", "mag": 1.06, "nature": "火/木星", "orb": 2.0, "keyword": "西方守护者"},
    {"name": "Fomalhaut", "swe_name": "Fomalhaut", "mag": 1.17, "nature": "金/水星", "orb": 2.0, "keyword": "南方守护者, 灵性"},

    # ---- 1st magnitude (orb 1.0 deg) ----
    {"name": "Sirius", "swe_name": "Sirius", "mag": -1.44, "nature": "木/火星", "orb": 1.5, "keyword": "天狼星, 名声"},
    {"name": "Vega", "swe_name": "Vega", "mag": 0.03, "nature": "金/水星", "orb": 1.0, "keyword": "艺术, 魅力"},
    {"name": "Capella", "swe_name": "Capella", "mag": 0.08, "nature": "火/水星", "orb": 1.0, "keyword": "财富, 荣誉"},
    {"name": "Rigel", "swe_name": "Rigel", "mag": 0.18, "nature": "木/土星", "orb": 1.0, "keyword": "财富, 名望"},
    {"name": "Procyon", "swe_name": "Procyon", "mag": 0.40, "nature": "水/火星", "orb": 1.0, "keyword": "短爆成功"},
    {"name": "Betelgeuse", "swe_name": "Betelgeuse", "mag": 0.45, "nature": "火/水星", "orb": 1.0, "keyword": "军事荣誉"},
    {"name": "Altair", "swe_name": "Altair", "mag": 0.76, "nature": "火/木星", "orb": 1.0, "keyword": "大胆, 野心"},
    {"name": "Achernar", "swe_name": "Achernar", "mag": 0.45, "nature": "木星", "orb": 1.0, "keyword": "宗教, 哲学"},
    {"name": "Canopus", "swe_name": "Canopus", "mag": -0.62, "nature": "土/木星", "orb": 1.5, "keyword": "航行, 学术"},

    # ---- Important 2nd magnitude (orb 0.5 deg) ----
    {"name": "Algol", "swe_name": "Algol", "mag": 2.09, "nature": "土星/木星", "orb": 1.0, "keyword": "最凶星, 暴力"},
    {"name": "Spica", "swe_name": "Spica", "mag": 0.98, "nature": "金/火星", "orb": 1.0, "keyword": "最吉星, 丰收"},
    {"name": "Denebola", "swe_name": "Denebola", "mag": 2.14, "nature": "土/金星", "orb": 0.5, "keyword": "被诽谤"},
    {"name": "Castor", "swe_name": "Castor", "mag": 1.58, "nature": "水星", "orb": 0.75, "keyword": "才智"},
    {"name": "Pollux", "swe_name": "Pollux", "mag": 1.16, "nature": "火星", "orb": 0.75, "keyword": "运动, 药物"},
    {"name": "Deneb", "swe_name": "Deneb", "mag": 1.25, "nature": "金/水星", "orb": 0.75, "keyword": "学问"},
    {"name": "Hamal", "swe_name": "Hamal", "mag": 2.01, "nature": "火/土星", "orb": 0.75, "keyword": "独立"},
    {"name": "Ras Alhague", "swe_name": "Rasalhague", "mag": 2.08, "nature": "土/金星", "orb": 0.5, "keyword": "医药"},
    {"name": "Zubenelgenubi", "swe_name": "Zubenelgenubi", "mag": 2.75, "nature": "土/火星", "orb": 0.5, "keyword": "法律, 骗局"},
    {"name": "Zubenelschemali", "swe_name": "Zubenelschemali", "mag": 2.61, "nature": "木/水星", "orb": 0.5, "keyword": "荣耀"},
    {"name": "Unukalhai", "swe_name": "Unukalhai", "mag": 2.63, "nature": "土/火星", "orb": 0.5, "keyword": "蛇首"},
    {"name": "Markab", "swe_name": "Markab", "mag": 2.49, "nature": "火/水星", "orb": 0.5, "keyword": "暴力, 荣誉"},
    {"name": "Scheat", "swe_name": "Scheat", "mag": 2.44, "nature": "火/水星", "orb": 0.5, "keyword": "溺水, 凶险"},
    {"name": "Alphecca", "swe_name": "Alphecca", "mag": 2.22, "nature": "金/火星", "orb": 0.5, "keyword": "花冠, 艺术"},
    {"name": "Mirach", "swe_name": "Mirach", "mag": 2.07, "nature": "金星", "orb": 0.75, "keyword": "婚姻, 幸福"},
    {"name": "Almach", "swe_name": "Almach", "mag": 2.10, "nature": "金星", "orb": 0.75, "keyword": "艺术, 荣誉"},
    {"name": "Menkar", "swe_name": "Menkar", "mag": 2.54, "nature": "土星", "orb": 0.5, "keyword": "鲸鱼首, 疾病"},
]

# Build a lookup: swe_name -> entry
_STAR_LOOKUP: dict[str, dict[str, Any]] = {s["swe_name"]: s for s in STAR_CATALOG}


def compute_star_positions(
    jd_ut: float,
    stars: list[dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    """Compute ecliptic longitudes for all (or given) fixed stars.

    Uses ``swe.fixstar_ut()`` with Swiss Ephemeris.
    Returns list of dicts with ``name``, ``longitude``, ``latitude``,
    ``declination``, ``mag``, ``nature`` (from catalog) and ``orb``.
    """
    if stars is None:
        stars = STAR_CATALOG
    results: list[dict[str, Any]] = []
    for star in stars:
        try:
            values, name_str, _ = swe.fixstar_ut(star["swe_name"], jd_ut, swe.FLG_SWIEPH | swe.FLG_SPEED)
            lon = values[0] % 360.0
            lat = values[1]
            # Declination from equatorial coordinates
            eq_vals, _, _ = swe.fixstar_ut(star["swe_name"], jd_ut, swe.FLG_SWIEPH | swe.FLG_EQUATORIAL)
            dec = eq_vals[1]
        except Exception:
            # Skip stars that fail (shouldn't happen with FK5 catalog)
            continue
        results.append({
            "name": star["name"],
            "swe_name": star["swe_name"],
            "longitude": round(lon, 4),
            "latitude": round(lat, 4),
            "declination": round(dec, 4),
            "mag": star["mag"],
            "nature": star["nature"],
            "keyword": star["keyword"],
            "orb": star["orb"],
        })
    return results


def find_star_conjunctions(
    planet_positions: list[dict[str, Any]],
    star_positions: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Detect conjunctions between planets and fixed stars.

    *planet_positions* each need ``body_id`` and ``longitude``.
    *star_positions* from ``compute_star_positions()``.
    Returns list of conjunction dicts sorted by orb (tightest first).
    """
    events: list[dict[str, Any]] = []
    for planet in planet_positions:
        p_lon = planet["longitude"]
        p_id = planet.get("body_id", planet.get("id", "?"))
        for star in star_positions:
            sep = abs((p_lon - star["longitude"]) % 360.0)
            sep = min(sep, 360.0 - sep)
            if sep <= star["orb"]:
                events.append({
                    "planet": p_id,
                    "star": star["name"],
                    "star_mag": star["mag"],
                    "star_nature": star["nature"],
                    "star_keyword": star.get("keyword", ""),
                    "orb": round(sep, 4),
                })
    events.sort(key=lambda e: e["orb"])
    return events


def format_star_conjunction(conj: dict[str, Any], planet_name: str | None = None) -> str:
    """Format a star conjunction as a human-readable Chinese string."""
    pname = planet_name or conj["planet"]
    return f"{pname} 合 {conj['star']} ({conj['orb']}°) — {conj['star_keyword']}"
