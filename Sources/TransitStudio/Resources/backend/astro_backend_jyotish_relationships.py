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

    Rule: If planet_b is in planet_a's own/exaltation sign OR
    planet_a is in planet_b's own/exaltation sign → temporary friend
    If either is in the other's debilitation sign → temporary enemy
    Otherwise → neutral.

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

    lord_a = _get_rasi_lord(rasi_a)
    lord_b = _get_rasi_lord(rasi_b)

    # Exaltation signs
    exc_a = EXALTATION_RASI.get(planet_a)
    exc_b = EXALTATION_RASI.get(planet_b)

    # Debilitation = opposite of exaltation
    deb_a = (exc_a + 6) % 12 if exc_a is not None else None
    deb_b = (exc_b + 6) % 12 if exc_b is not None else None

    # Check friendship conditions
    planet_b_in_planet_a_own = (lord_a == planet_b)
    planet_b_in_planet_a_exc = (exc_a is not None and rasi_b == exc_a)
    planet_a_in_planet_b_own = (lord_b == planet_a)
    planet_a_in_planet_b_exc = (exc_b is not None and rasi_a == exc_b)

    # Enmity conditions
    planet_b_in_planet_a_deb = (deb_a is not None and rasi_b == deb_a)
    planet_a_in_planet_b_deb = (deb_b is not None and rasi_a == deb_b)

    is_friend = (planet_b_in_planet_a_own or planet_b_in_planet_a_exc or
                 planet_a_in_planet_b_own or planet_a_in_planet_b_exc)
    is_enemy = (planet_b_in_planet_a_deb or planet_a_in_planet_b_deb)

    # Some planets may not have exaltation set
    if planet_a in ("RAHU", "KETU"):
        is_friend = False
        is_enemy = False

    if is_friend and not is_enemy:
        return 0  # temporary friend
    elif is_enemy and not is_friend:
        return 2  # temporary enemy
    else:
        return 1  # neutral


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

_ALL_PLANETS = ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN",
                "RAHU", "KETU"]
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

    for a in all_bodies:
        naisargika_rows[a] = {}
        temporary_rows[a] = {}
        compound_rows[a] = {}

        for b in all_bodies:
            if a == b:
                continue

            # Naisargika (natural)
            if a in NAISARGIKA_FRIENDSHIP and b in NAISARGIKA_FRIENDSHIP[a]:
                nat = NAISARGIKA_FRIENDSHIP[a][b]
            else:
                nat = 1  # neutral for unknown combos

            # Temporary
            tmp = calc_temporary_friendship(a, b, planet_positions)

            # Compound
            comp = calc_compound_friendship(nat, tmp)

            naisargika_rows[a][b] = nat
            temporary_rows[a][b] = tmp
            compound_rows[a][b] = comp

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
