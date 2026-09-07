"""Jaimini Karaka calculations for Jyotish.

Calculates Chara (Jaimini) Karakas based on planetary longitudes.
From Maitreya Jaimini.cpp:calcCharaKarakas() approach.
"""

from __future__ import annotations

from typing import Any

from astro_backend_core import zodiac_sign_index


# ─── Chara Karaka Order ───────────────────────────────────────────────

# ─── Chara Karaka Order ───────────────────────────────────────────────

KARAKA_NAMES_7_SA = [
    "Atma Karaka",       # 0: Soul significator
    "Amatya Karaka",     # 1: Career/minister significator
    "Bhratri Karaka",    # 2: Sibling significator
    "Matri Karaka",      # 3: Mother significator
    "Putra Karaka",      # 4: Child significator
    "Gnati Karaka",      # 5: Relations/obstacles significator
    "Dara Karaka",       # 6: Spouse significator
]

KARAKA_NAMES_7_ZH = [
    "灵魂星 (Atma Karaka)",
    "大臣星 (Amatya Karaka)",
    "兄弟星 (Bhratri Karaka)",
    "母亲星 (Matri Karaka)",
    "子女星 (Putra Karaka)",
    "知识星 (Gnati Karaka)",
    "配偶星 (Dara Karaka)",
]

KARAKA_NAMES_8_SA = [
    "Atma Karaka",       # 0: Soul significator
    "Amatya Karaka",     # 1: Career/minister significator
    "Bhratri Karaka",    # 2: Sibling significator
    "Matri Karaka",      # 3: Mother significator
    "Pitri Karaka",      # 4: Father significator
    "Putra Karaka",      # 5: Child significator
    "Gnati Karaka",      # 6: Relations/obstacles significator
    "Dara Karaka",       # 7: Spouse significator
]

KARAKA_NAMES_8_ZH = [
    "灵魂星 (Atma Karaka)",
    "大臣星 (Amatya Karaka)",
    "兄弟星 (Bhratri Karaka)",
    "母亲星 (Matri Karaka)",
    "父亲星 (Pitri Karaka)",
    "子女星 (Putra Karaka)",
    "知识星 (Gnati Karaka)",
    "配偶星 (Dara Karaka)",
]

KARAKA_NAMES_SA = KARAKA_NAMES_7_SA
KARAKA_NAMES_ZH = KARAKA_NAMES_7_ZH


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

    In the 8-planet system (with Rahu), the order is:
    Atma, Amatya, Bhratri, Matri, Pitri, Putra, Gnati, Dara.

    In the 7-planet system, the order is:
    Atma, Amatya, Bhratri, Matri, Putra, Gnati, Dara.

    Args:
        planet_positions: Dict of planet positions
        include_rahu: If True, include Rahu as a karaka (8-planet system).
                      Standard is 7-planet (Sun..Saturn).

    Returns:
        Dict with chara_karakas ordered by importance.
    """
    if include_rahu:
        candidate_ids = ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN", "RAHU"]
        names_sa = KARAKA_NAMES_8_SA
        names_zh = KARAKA_NAMES_8_ZH
        system_name = "8-planet"
    else:
        candidate_ids = ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"]
        names_sa = KARAKA_NAMES_7_SA
        names_zh = KARAKA_NAMES_7_ZH
        system_name = "7-planet"

    # Only include planets actually present in planet_positions
    candidates = [p for p in candidate_ids if p in planet_positions]
    missing_planets = [p for p in candidate_ids if p not in planet_positions]
    is_complete = len(missing_planets) == 0

    # Get longitude within own sign for each
    rl = {pid: _get_rasi_longitude(planet_positions, pid) for pid in candidates}

    # Sort by longitude descending with stable key
    sorted_planets = sorted(candidates, key=lambda p: rl.get(p, 0.0), reverse=True)

    # Assign karaka in order
    karakas = []
    for i, pid in enumerate(sorted_planets):
        if i >= len(names_sa):
            break
        karakas.append({
            "karaka_type": i,
            "planet": pid,
            "planet_name": planet_positions.get(pid, {}).get("name", pid),
            "longitude_in_rasi": round(rl.get(pid, 0.0), 4),
            "effective_longitude": round(rl.get(pid, 0.0), 4),
            "name_sa": names_sa[i],
            "name_zh": names_zh[i],
        })

    return {
        "chara_karakas": karakas,
        "system": system_name if is_complete else f"{system_name} (incomplete)",
        "requested_system": system_name,
        "complete": is_complete,
        "missing_planets": missing_planets,
        "note": "Chara Karakas ranked by planetary longitude within own sign",
    }
