"""Jaimini Karaka calculations for Jyotish.

Calculates Chara (Jaimini) Karakas based on planetary longitudes.
From Maitreya Jaimini.cpp:calcCharaKarakas() approach.
"""

from __future__ import annotations

from typing import Any

from astro_backend_core import zodiac_sign_index


# ─── Chara Karaka Order ───────────────────────────────────────────────

KARAKA_NAMES_SA = [
    "Atma Karaka",       # Soul significator
    "Amatya Karaka",     # Career/minister significator
    "Bhratri Karaka",    # Sibling significator
    "Matri Karaka",      # Mother significator
    "Putra Karaka",      # Child significator
    "Gnati Karaka",      # Knowledge significator
    "Dara Karaka",       # Spouse significator
]

KARAKA_NAMES_ZH = [
    "灵魂星 (Atma Karaka)",
    "大臣星 (Amatya Karaka)",
    "兄弟星 (Bhratri Karaka)",
    "母亲星 (Matri Karaka)",
    "子女星 (Putra Karaka)",
    "知识星 (Gnati Karaka)",
    "配偶星 (Dara Karaka)",
]


# ─── Planet Longitude in Own Sign ─────────────────────────────────────

def _get_rasi_longitude(planet_positions: dict[str, dict[str, Any]], pid: str) -> float:
    """Get the longitude within the planet's own sign (0-30)."""
    if pid not in planet_positions:
        return 0.0
    rasi_longitude = planet_positions[pid]["longitude"] % 30.0
    if pid in {"RAHU", "KETU"}:
        return 30.0 - rasi_longitude
    return rasi_longitude


# ─── Compute Chara Karakas ────────────────────────────────────────────

def compute_chara_karakas(
    planet_positions: dict[str, dict[str, Any]],
    include_rahu: bool = True,
) -> dict[str, Any]:
    """Compute Chara (Jaimini) Karakas.

    Chara Karaka system: The 7 (or 8) planets are ranked by their
    longitude within their own sign. The planet with the highest
    longitude = Atma Karaka, then decreasing → Amatya, Bhratri, etc.

    The 8th karaka (if Rahu is included) is Gnati Karaka, otherwise
    Gnati is 6th and Dara is 7th.

    Args:
        planet_positions: Dict of planet positions
        include_rahu: If True, include Rahu as a karaka (8-planet system).
                      Standard is 7-planet (Sun..Saturn).

    Returns:
        Dict with chara_karakas ordered by importance.
    """
    # Planets to consider
    # Standard 7: Sun..Saturn
    # If include_rahu: include Rahu as well (8)
    if include_rahu:
        candidates = ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN", "RAHU"]
    else:
        candidates = ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"]

    # Get longitude within own sign for each
    rl = {}
    for pid in candidates:
        if pid in planet_positions:
            rl[pid] = _get_rasi_longitude(planet_positions, pid)
        else:
            rl[pid] = 0.0

    # Sort by longitude descending
    sorted_planets = sorted(candidates, key=lambda p: rl.get(p, 0.0), reverse=True)
    sorted_planets = [p for p in sorted_planets if p in planet_positions]

    # Assign karaka in order
    karakas = []
    for i, pid in enumerate(sorted_planets):
        if i >= len(KARAKA_NAMES_SA):
            break
        karakas.append({
            "karaka_type": i,
            "planet": pid,
            "planet_name": planet_positions.get(pid, {}).get("name", pid),
            "longitude_in_rasi": round(rl.get(pid, 0.0), 4),
            "effective_longitude": round(rl.get(pid, 0.0), 4),
            "name_sa": KARAKA_NAMES_SA[i],
            "name_zh": KARAKA_NAMES_ZH[i],
        })

    return {
        "chara_karakas": karakas,
        "system": "8-planet" if include_rahu else "7-planet",
        "note": "Chara Karakas ranked by planetary longitude within own sign",
    }
