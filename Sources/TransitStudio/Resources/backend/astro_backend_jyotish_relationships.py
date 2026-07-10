"""Planet relationship calculations for Jyotish.

Computes Naisargika (natural), Temporary (tatkalika), and Compound
(sambandha) friendships between all planets.
Based on BPHS rules.
"""

from __future__ import annotations

from typing import Any

from astro_backend_core import zodiac_sign_index
from astro_backend_jyotish_data import (
    NAISARGIKA_FRIENDSHIP,
    FRIENDSHIP_LABELS,
    VEDIC_PLANET_IDS,
)

# ─── Friendship Level Helpers ─────────────────────────────────────────

# Friendship level mapping
# Natural: -1=self, 0=friend, 1=neutral, 2=enemy
# Temporary: 0=friend, 1=neutral, 2=enemy
# Compound: 0=great friend, 1=friend, 2=neutral, 3=enemy, 4=great enemy

TEMPORARY_FRIENDSHIP_LABELS = {0: "临时友", 1: "临时中", 2: "临时敌"}
COMPOUND_LABELS = {0: "大友", 1: "友", 2: "中", 3: "敌", 4: "大敌"}
COMPOUND_LABELS_SA = {0: "Adhi Mitra", 1: "Mitra", 2: "Sama", 3: "Shatru", 4: "Adhi Shatru"}


# ─── Rasi Lords ───────────────────────────────────────────────────────

# Standard rasi lords
RASI_LORDS = [
    "MARS",      # Aries (0)
    "VENUS",     # Taurus (1)
    "MERCURY",   # Gemini (2)
    "MOON",      # Cancer (3)
    "SUN",       # Leo (4)
    "MERCURY",   # Virgo (5)
    "VENUS",     # Libra (6)
    "MARS",      # Scorpio (7)
    "JUPITER",   # Sagittarius (8)
    "SATURN",    # Capricorn (9)
    "SATURN",    # Aquarius (10)
    "JUPITER",   # Pisces (11)
]

# Exaltation lords (lords of exaltation signs)
EXALTATION_RASI = {
    "SUN": 0,      # Aries
    "MOON": 1,     # Taurus
    "MERCURY": 5,  # Virgo
    "VENUS": 11,   # Pisces
    "MARS": 9,     # Capricorn
    "JUPITER": 3,  # Cancer
    "SATURN": 6,   # Libra
}


# ─── Temporary Friendship ─────────────────────────────────────────────

def _get_rasi_lord(rasi: int) -> str | None:
    """Return the lord of a given rasi index (0-11)."""
    if 0 <= rasi < 12:
        return RASI_LORDS[rasi]
    return None


def calc_temporary_friendship(
    planet_a: str,
    planet_b: str,
    planet_positions: dict[str, dict[str, Any]],
) -> int:
    """Calculate temporary (tatkalika) friendship.

    Rule: planet B is a temporary friend when it occupies the 2nd, 3rd,
    4th, 10th, 11th or 12th sign counted from planet A.  The remaining
    relative places (1st, 5th-9th) are temporary enemies.

    Returns: 0=friend, 1=neutral, 2=enemy
    """
    if planet_a not in planet_positions or planet_b not in planet_positions:
        return 1

    pos_a = planet_positions[planet_a]
    pos_b = planet_positions[planet_b]

    lon_a = pos_a["longitude"]
    lon_b = pos_b["longitude"]

    rasi_a = zodiac_sign_index(lon_a)
    rasi_b = zodiac_sign_index(lon_b)

    relative_place = (rasi_b - rasi_a) % 12 + 1
    return 0 if relative_place in {2, 3, 4, 10, 11, 12} else 2


# ─── Compound Friendship ──────────────────────────────────────────────

def calc_compound_friendship(
    naisargika: int,
    temporary: int,
) -> int:
    """Calculate compound (sambandha) friendship from natural + temporary.

    Compound levels:
    - Both friend → Great Friend (Adhi Mitra) = 0
    - One friend, one neutral → Friend (Mitra) = 1
    - Both neutral → Neutral (Sama) = 2
    - One enemy, one neutral → Enemy (Shatru) = 3
    - Both enemy → Great Enemy (Adhi Shatru) = 4
    - Friend + Enemy → Neutral (Sama) = 2

    Natural: 0=friend, 1=neutral, 2=enemy
    Temp: 0=friend, 1=neutral, 2=enemy
    """
    # Map to -1, 0, +1 scale
    def to_sign(val):
        if val == 0: return 1     # friend → +1
        if val == 2: return -1    # enemy → -1
        return 0                  # neutral → 0

    n = to_sign(naisargika)
    t = to_sign(temporary)

    total = n + t

    if total == 2:
        return 0  # Great Friend
    elif total == 1:
        return 1  # Friend
    elif total == 0:
        return 2  # Neutral
    elif total == -1:
        return 3  # Enemy
    elif total == -2:
        return 4  # Great Enemy
    return 2  # fallback


# ─── Compute All Relationships ───────────────────────────────────────

_CLASSICAL_PLANETS = ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"]
_ALL_PLANETS = _CLASSICAL_PLANETS + ["RAHU", "KETU"]
_EXTRA_BODIES = ["URANUS", "NEPTUNE", "PLUTO", "ASC"]


def compute_planet_relationships(
    planet_positions: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    """Compute all planet relationships for D1 chart.

    Returns dict with naisargika, temporary, and compound sections.
    """
    naisargika_rows = {}
    temporary_rows = {}
    compound_rows = {}

    all_bodies = _ALL_PLANETS + [b for b in _EXTRA_BODIES if b in planet_positions]

    naisargika_bodies = [b for b in _CLASSICAL_PLANETS if b in all_bodies]

    for a in all_bodies:
        naisargika_rows[a] = {}
        temporary_rows[a] = {}
        compound_rows[a] = {}

        for b in all_bodies:
            if a == b:
                continue

            # Naisargika (natural)
            if a in naisargika_bodies and b in naisargika_bodies and a in NAISARGIKA_FRIENDSHIP and b in NAISARGIKA_FRIENDSHIP[a]:
                nat = NAISARGIKA_FRIENDSHIP[a][b]
            else:
                nat = 1  # neutral for unknown combos

            # Temporary
            tmp = calc_temporary_friendship(a, b, planet_positions)

            # Compound
            comp = calc_compound_friendship(nat, tmp)

            temporary_rows[a][b] = tmp
            compound_rows[a][b] = comp
            if a in naisargika_bodies and b in naisargika_bodies:
                naisargika_rows[a][b] = nat

    for a in list(naisargika_rows.keys()):
        if a not in naisargika_bodies:
            naisargika_rows.pop(a, None)

    return {
        "naisargika": {
            "data": naisargika_rows,
            "labels": {k: FRIENDSHIP_LABELS.get(v, "unknown") for k, v in FRIENDSHIP_LABELS.items()},
        },
        "temporary": {
            "data": temporary_rows,
            "labels": TEMPORARY_FRIENDSHIP_LABELS,
        },
        "compound": {
            "data": compound_rows,
            "labels": COMPOUND_LABELS,
            "labels_sa": COMPOUND_LABELS_SA,
        },
    }
