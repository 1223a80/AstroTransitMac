"""Arudha (reflected) houses calculation for Jyotish.

Computes AL (Arudha Lagna), A2-A11 (Arudha Padas for each house),
and UL (Upapada Lagna - Arudha of the 12th house).
Based on BPHS rules.
"""

from __future__ import annotations

from typing import Any

from astro_backend_core import zodiac_sign_index


# ─── Rasi Lords ───────────────────────────────────────────────────────

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

# Karakas (significators) for each house
HOUSE_KARAKAS = [
    None,          # 0 unused
    "SUN",         # 1st house - Sun
    "JUPITER",     # 2nd house - Jupiter
    "MARS",        # 3rd house - Mars
    "MOON",        # 4th house - Moon
    "JUPITER",     # 5th house - Jupiter
    "MERCURY",     # 6th house - Mercury
    "VENUS",       # 7th house - Venus
    "SATURN",      # 8th house - Saturn
    "SUN",         # 9th house - Sun
    "JUPITER",     # 10th house - Jupiter
    "SATURN",      # 11th house - Saturn
    "SATURN",      # 12th house - Saturn
]


def _get_rasi_lord(rasi: int) -> str | None:
    """Return the lord of a given rasi index (0-11)."""
    if 0 <= rasi < 12:
        return RASI_LORDS[rasi]
    return None


# ─── Arudha Pada Calculation ─────────────────────────────────────────

def calc_arudha_pada(
    house_rasi: int,
    asc_rasi: int,
    planet_positions: dict[str, dict[str, Any]],
) -> int:
    """Calculate Arudha Pada for a given house.

    Formula (BPHS): Pada = (Lord_rasi - House_rasi) + House_rasi
    Simplified: Pada = 2 * Lord_rasi - House_rasi
    Then if Pada == House_rasi, Pada += 10 (or 9 if using some systems)
    If Lord_rasi == House_rasi (e.g., sign lord), then
    use the next house lord instead.

    For Arudha Lagna (AL) = Pada of the 1st house (ASC sign).
    For Upapada (UL) = Pada of the 12th house.

    Args:
        house_rasi: The rasi (0-11) of the house to compute pada for
        asc_rasi: Ascendant rasi (0-11)
        planet_positions: Dict of planet positions

    Returns:
        Rasi index (0-11) where the Arudha falls.
    """
    # Determine the house lord
    lord = _get_rasi_lord(house_rasi)
    if lord is None:
        return (house_rasi + 5) % 12  # fallback

    # If lord is a planet, get its rasi
    if lord in planet_positions:
        lord_rasi = zodiac_sign_index(planet_positions[lord]["longitude"])
    else:
        lord_rasi = house_rasi  # fallback

    # Arudha pada formula: lord_rasi + (lord_rasi - house_rasi)
    pada = lord_rasi + (lord_rasi - house_rasi)

    # Normalize
    pada = pada % 12

    # Exception: If pada falls in the same rasi as the house, add 10 (mod 12)
    # Some texts say add 9 (no 10th house pada), but standard is add 10
    if pada == house_rasi:
        pada = (pada + 10) % 12
        # If still same, add another sign // shouldn't happen
        if pada == house_rasi:
            pada = (pada + 1) % 12

    return pada


# ─── Compute All Arudhas ──────────────────────────────────────────────

def compute_arudha(
    asc_longitude: float,
    planet_positions: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    """Compute all Arudha Padas.

    Returns dict with:
      - AL: Arudha Lagna (Pada of house 1)
      - A2..A11: Arudha Padas for houses 2..11
      - UL: Upapada Lagna (Pada of house 12)
    """
    asc_rasi = zodiac_sign_index(asc_longitude)

    arudha = {}

    # AL = Arudha of 1st house
    al_rasi = calc_arudha_pada(asc_rasi, asc_rasi, planet_positions)
    arudha["AL"] = {
        "pada_name": "Arudha Lagna",
        "rasi": al_rasi,
        "rasi_name": ["白羊","金牛","双子","巨蟹","狮子","处女",
                      "天秤","天蝎","射手","摩羯","水瓶","双鱼"][al_rasi],
        "house": (al_rasi - asc_rasi) % 12 + 1,
    }

    # A2 through A11
    for house_num in range(2, 12):
        house_rasi = (asc_rasi + house_num - 1) % 12
        pada_rasi = calc_arudha_pada(house_rasi, asc_rasi, planet_positions)
        pada_name = f"A{house_num}"
        kendra_name = {
            2: "Dhana", 3: "Vikrama", 4: "Matri", 5: "Putra",
            6: "Ripu", 7: "Kama", 8: "Moksha", 9: "Bhagya",
            10: "Karma", 11: "Aya",
        }.get(house_num, "")
        arudha[pada_name] = {
            "pada_name": f"{pada_name} ({kendra_name})",
            "rasi": pada_rasi,
            "rasi_name": ["白羊","金牛","双子","巨蟹","狮子","处女",
                          "天秤","天蝎","射手","摩羯","水瓶","双鱼"][pada_rasi],
            "house": (pada_rasi - asc_rasi) % 12 + 1,
        }

    # UL = Upapada Lagna = Arudha of 12th house
    ul_rasi = calc_arudha_pada((asc_rasi + 11) % 12, asc_rasi, planet_positions)
    arudha["UL"] = {
        "pada_name": "Upapada Lagna",
        "rasi": ul_rasi,
        "rasi_name": ["白羊","金牛","双子","巨蟹","狮子","处女",
                      "天秤","天蝎","射手","摩羯","水瓶","双鱼"][ul_rasi],
        "house": (ul_rasi - asc_rasi) % 12 + 1,
    }

    return arudha
