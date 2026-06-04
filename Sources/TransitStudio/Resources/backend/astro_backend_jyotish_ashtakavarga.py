"""Ashtakavarga (BAV + SAV) calculation for Jyotish.

Computes Bhinnashtakavarga (BAV) for each planet and
Sarvatobhadra Chakra (SAV/Total).

REKHA_MAP from Maitreya Ashtakavarga.cpp approach.
"""

from __future__ import annotations

from typing import Any

from astro_backend_core import zodiac_sign_index


# ─── REKHA_MAP ────────────────────────────────────────────────────────
# From Maitreya Ashtakavarga.cpp
# dims: [aspecting_planet][planet_being_aspected][house_offset]
# 8 x 8 x 12 = 768 entries
# Index order: [i][j][k] where
#   i = planet being evaluated (0=Sun, 1=Moon, 2=Mercury, 3=Venus, 4=Mars, 5=Jupiter, 6=Saturn, 7=Asc)
#   j = planet providing aspect (0=Sun..7=Asc)
#   k = house offset from planet j (0-11)
# Value: 1 = benefic rekha, 0 = no rekha

REKHA_MAP_RAW = [
    # i=0: Sun
    [
        [1,1,0,1,0,0,1,1,1,1,1,0],  # j=0 (Sun→Sun = self)
        [0,0,1,0,0,1,0,0,0,1,1,0],  # j=1 (Moon→Sun)
        [0,0,1,0,1,1,0,0,1,1,1,1],  # j=2 (Mercury→Sun)
        [0,0,0,0,0,1,1,0,0,0,0,1],  # j=3 (Venus→Sun)
        [1,1,0,1,0,0,1,1,1,1,1,0],  # j=4 (Mars→Sun)
        [0,0,0,0,1,1,0,0,1,0,1,0],  # j=5 (Jupiter→Sun)
        [1,1,0,1,0,0,1,1,1,1,1,0],  # j=6 (Saturn→Sun)
        [0,0,1,1,0,1,0,0,0,1,1,1],  # j=7 (Asc→Sun)
    ],
    # i=1: Moon
    [
        [0,0,1,0,0,1,1,1,0,1,1,0],  # Sun→Moon
        [1,0,1,0,0,1,1,0,0,1,1,0],  # Moon→Moon
        [1,0,1,1,1,0,1,1,0,1,1,0],  # Mercury→Moon
        [0,0,1,1,1,0,1,0,1,1,1,0],  # Venus→Moon
        [0,1,1,0,1,1,0,0,1,1,1,0],  # Mars→Moon
        [1,1,0,1,0,0,1,1,0,1,1,0],  # Jupiter→Moon
        [0,0,1,0,1,1,0,0,0,0,1,0],  # Saturn→Moon
        [0,0,1,0,0,1,0,0,0,1,1,0],  # Asc→Moon
    ],
    # i=2: Mercury
    [
        [0,0,0,0,1,1,0,0,1,0,1,1],  # Sun→Mercury
        [0,1,0,1,0,1,0,1,0,1,1,0],  # Moon→Mercury
        [1,0,1,0,1,1,0,0,1,1,1,1],  # Mercury→Mercury
        [1,1,1,1,1,0,0,1,1,0,1,0],  # Venus→Mercury
        [1,1,0,1,0,0,1,1,1,1,1,0],  # Mars→Mercury
        [0,0,0,0,0,1,0,1,0,0,1,1],  # Jupiter→Mercury
        [1,1,0,1,0,0,1,1,1,1,1,0],  # Saturn→Mercury
        [1,1,0,1,0,1,0,1,0,1,1,0],  # Asc→Mercury
    ],
    # i=3: Venus
    [
        [0,0,0,0,0,0,0,1,0,0,1,1],  # Sun→Venus
        [1,1,1,1,1,0,0,1,1,0,1,1],  # Moon→Venus
        [0,0,1,0,1,1,0,0,1,0,1,0],  # Mercury→Venus
        [1,1,1,1,1,0,0,1,1,1,1,0],  # Venus→Venus
        [0,0,1,1,0,1,0,0,1,0,1,1],  # Mars→Venus
        [0,0,0,0,1,0,0,1,1,1,1,0],  # Jupiter→Venus
        [0,0,1,1,1,0,0,1,1,1,1,0],  # Saturn→Venus
        [1,1,1,1,1,0,0,1,1,0,1,0],  # Asc→Venus
    ],
    # i=4: Mars
    [
        [0,0,1,0,1,1,0,0,0,1,1,0],  # Sun→Mars
        [0,0,1,0,0,1,0,0,0,0,1,0],  # Moon→Mars
        [0,0,1,0,1,1,0,0,0,0,1,0],  # Mercury→Mars
        [0,0,0,0,0,1,0,1,0,0,1,1],  # Venus→Mars
        [1,1,0,1,0,0,1,1,0,1,1,0],  # Mars→Mars
        [0,0,0,0,0,1,0,0,0,1,1,1],  # Jupiter→Mars
        [1,0,0,1,0,0,1,1,1,1,1,0],  # Saturn→Mars
        [1,0,1,0,0,1,0,0,0,1,1,0],  # Asc→Mars
    ],
    # i=5: Jupiter
    [
        [1,1,1,1,0,0,1,1,1,1,1,0],  # Sun→Jupiter
        [0,1,0,0,1,0,1,0,1,0,1,0],  # Moon→Jupiter
        [1,1,0,1,1,1,0,0,1,1,1,0],  # Mercury→Jupiter
        [0,1,0,0,1,1,0,0,1,1,1,0],  # Venus→Jupiter
        [1,1,0,1,0,0,1,1,0,1,1,0],  # Mars→Jupiter
        [1,1,1,1,0,0,1,1,0,1,1,0],  # Jupiter→Jupiter
        [0,0,1,0,1,1,0,0,0,0,0,1],  # Saturn→Jupiter
        [1,1,0,1,1,1,1,0,1,1,1,0],  # Asc→Jupiter
    ],
    # i=6: Saturn
    [
        [1,1,0,1,0,0,1,1,0,1,1,0],  # Sun→Saturn
        [0,0,1,0,0,1,0,0,0,0,1,0],  # Moon→Saturn
        [0,0,0,0,0,1,0,1,1,1,1,1],  # Mercury→Saturn
        [0,0,0,0,0,1,0,0,0,0,1,1],  # Venus→Saturn
        [0,0,1,0,1,1,0,0,0,1,1,1],  # Mars→Saturn
        [0,0,0,0,1,1,0,0,0,0,1,1],  # Jupiter→Saturn
        [0,0,1,0,1,1,0,0,0,0,1,0],  # Saturn→Saturn
        [1,0,1,1,0,1,0,0,0,1,1,0],  # Asc→Saturn
    ],
    # i=7: Ascendant
    [
        [0,0,1,1,0,1,0,0,0,1,1,1],  # Sun→Asc
        [0,0,1,0,0,1,0,0,0,1,1,1],  # Moon→Asc
        [1,1,0,1,0,1,0,1,0,1,1,0],  # Mercury→Asc
        [1,1,1,1,1,0,0,1,1,0,0,0],  # Venus→Asc
        [1,0,1,0,0,1,0,0,0,1,1,0],  # Mars→Asc
        [1,1,0,1,1,1,1,0,1,1,1,0],  # Jupiter→Asc
        [1,0,1,1,0,1,0,0,0,1,1,0],  # Saturn→Asc
        [0,0,1,0,0,1,0,0,0,1,1,0],  # Asc→Asc
    ],
]

# Planet index mapping
PLANET_INDEX = {"SUN": 0, "MOON": 1, "MERCURY": 2, "VENUS": 3, "MARS": 4,
                "JUPITER": 5, "SATURN": 6, "ASC": 7}
INDEX_PLANET = {0: "SUN", 1: "MOON", 2: "MERCURY", 3: "VENUS", 4: "MARS",
                5: "JUPITER", 6: "SATURN", 7: "ASC"}


# ─── Rekha Calculation ───────────────────────────────────────────────

def _get_rekha_pattern(i: int, j: int, k: int) -> int:
    """Get the REKHA_MAP value for planet i, from aspecter j, at offset k."""
    if 0 <= i < 8 and 0 <= j < 8 and 0 <= k < 12:
        return REKHA_MAP_RAW[i][j][k]
    return 0


def _red12(val: int) -> int:
    """Reduce to 0-11 range."""
    return val % 12


# ─── Compute Ashtakavarga ─────────────────────────────────────────────

def compute_ashtakavarga(
    planet_positions: dict[str, dict[str, Any]],
    asc_longitude: float | None = None,
) -> dict[str, Any]:
    """Compute Bhinnashtakavarga (BAV) and Sarvatobhadra Chakra (SAV).

    Args:
        planet_positions: Dict of planet positions with 'longitude' key.
        asc_longitude: ASC longitude (optional, for better accuracy).

    Returns:
        Dict with bav and sav sections.
    """
    # Get planet rasis
    planet_rasi = {}
    for pid, idx in PLANET_INDEX.items():
        if pid == "ASC":
            if asc_longitude is not None:
                planet_rasi[pid] = zodiac_sign_index(asc_longitude)
            else:
                planet_rasi[pid] = 0
        elif pid in planet_positions:
            planet_rasi[pid] = zodiac_sign_index(planet_positions[pid]["longitude"])
        else:
            planet_rasi[pid] = 0

    # Use Moon's rasi as a proxy for ASC position if not available in planet_positions
    # ASC is needed as a reference point for patterns
    # For simplicity, assume ASC = 0 (Aries) as a placeholder

    # Initialize rekha, trikona, ekadhi matrices [planet][rasi]
    # 8 planets × 12 rasis
    rekha = [[0] * 12 for _ in range(8)]

    # Calculate REKHA
    for i in range(8):  # planet being evaluated
        for j in range(8):  # planet providing aspect
            p2_idx = j  # planet index
            p2_rasi = planet_rasi.get(INDEX_PLANET[p2_idx], 0)
            for k in range(12):  # house offset from p2
                house = _red12(p2_rasi + k)
                if _get_rekha_pattern(i, j, k):
                    rekha[i][house] += 1

    # Calculate Trikona Shodana
    trikona = [[0] * 12 for _ in range(8)]
    for i in range(8):
        for j in range(4):  # trikona groups
            # Find minimum among trikona group
            min_rec = min(rekha[i][j], rekha[i][j+4], rekha[i][j+8])
            for k in range(3):
                trikona[i][j+4*k] = rekha[i][j+4*k] - min_rec

    # Calculate Ekadhipatya Shodana
    ekadhi = [[0] * 12 for _ in range(8)]
    # Copy rekha first
    for i in range(8):
        for j in range(12):
            ekadhi[i][j] = rekha[i][j]

    # Ekadhipatya pairs (signs ruled by same lord)
    # Mars: Aries(0), Scorpio(7)
    # Venus: Taurus(1), Libra(6)
    # Mercury: Gemini(2), Virgo(5)
    # Moon: Cancer(3)
    # Sun: Leo(4)
    # Jupiter: Sagittarius(8), Pisces(11)
    # Saturn: Capricorn(9), Aquarius(10)
    pairs = [(0, 7), (1, 6), (2, 5), (8, 11), (9, 10)]
    for i in range(8):
        for b1, b2 in pairs:
            if t := ekadhi[i][b1]:
                if ekadhi[i][b2] > t:
                    ekadhi[i][b2] -= t
                    ekadhi[i][b1] = 0
                else:
                    ekadhi[i][b1] -= t
                    ekadhi[i][b2] = 0

    # Sarva (total) calculation
    sarva_rekha = [0] * 12
    sarva_trikona = [0] * 12
    sarva_ekadhi = [0] * 12
    planet_sarva_rekha = [0] * 8

    for i in range(12):
        for j in range(8):
            sarva_rekha[i] += rekha[j][i]
            sarva_trikona[i] += trikona[j][i]
            sarva_ekadhi[i] += ekadhi[j][i]

    for j in range(8):
        for i in range(12):
            planet_sarva_rekha[j] += rekha[j][i]

    # Build output
    # BAV: Bhinnashtakavarga (per planet)
    bav_planets = {}
    for pid in ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"]:
        idx = PLANET_INDEX[pid]
        bav_planets[pid] = {
            "rekha": rekha[idx],
            "trikona": trikona[idx],
            "ekadhi": ekadhi[idx],
            "sarva": planet_sarva_rekha[idx],
        }

    bav_planets["ASC"] = {
        "rekha": rekha[7],
        "trikona": trikona[7],
        "ekadhi": ekadhi[7],
        "sarva": planet_sarva_rekha[7],
    }

    # BAV matrix (transposed for expected output format)
    bav_matrix = {}
    for pid in ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN", "ASC"]:
        bav_matrix[pid] = bav_planets[pid]["rekha"]

    return {
        "bav": {
            "planets": bav_matrix,
            "rekha_by_planet": bav_planets,
        },
        "sav": {
            "rekha": sarva_rekha,      # SAV = sum of BAV
            "trikona": sarva_trikona,
            "ekadhi": sarva_ekadhi,
        },
    }
