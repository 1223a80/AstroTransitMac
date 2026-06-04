"""Varga (divisional chart) calculations for Jyotish.

All formulas sourced from Maitreya Varga.cpp:calcVarga()
by Martin Pettau, GPL-licensed.
"""

from __future__ import annotations

import math
from typing import Any

from astro_backend_core import norm360, zodiac_sign_index


def _get_rasi_len(longitude: float) -> float:
    """Return the longitude within its rasi (0-30)."""
    return longitude % 30.0


def _get_rasi(longitude: float) -> int:
    """Return the rasi index (0-11)."""
    return zodiac_sign_index(longitude)


def _is_odd_rasi(longitude: float) -> bool:
    """Return True if longitude is in an odd (fiery/movable) rasi.
    Odd rasis: Aries(0), Gemini(2), Leo(4), Libra(6), Sagittarius(8), Aquarius(10)
    """
    return _get_rasi(longitude) % 2 == 0


def _is_movable_rasi(longitude: float) -> bool:
    """Movable (Chara) rasis: Aries(0), Cancer(3), Libra(6), Capricorn(9)"""
    return _get_rasi(longitude) % 3 == 0


def _is_fixed_rasi(longitude: float) -> bool:
    """Fixed (Sthira) rasis: Taurus(1), Leo(4), Scorpio(7), Aquarius(10)"""
    return _get_rasi(longitude) % 3 == 1


def _is_dual_rasi(longitude: float) -> bool:
    """Dual (Dvisvabhava) rasis: Gemini(2), Virgo(5), Sagittarius(8), Pisces(11)"""
    return _get_rasi(longitude) % 3 == 2


def _red_deg(value: float) -> float:
    """Reduce to 0-360 range."""
    return norm360(value)


def _a_red(value: float, limit: float) -> float:
    """Reduce value to 0..limit range (cyclic). Used for trimsamsa etc."""
    return value % limit


def calc_varga(longitude: float, division: int, params: dict[str, Any] | None = None) -> int:
    """Calculate the Varga (divisional) chart rasi index for a given longitude.

    Args:
        longitude: Tropical/sidereal longitude in degrees.
        division: Varga division number (1, 2, 3, 4, 6, 7, 8, 9, 10, 12, 16, 20, 24, 27, 30, 40, 45, 60).
            Special: 108 (D108), 144 (D144), 0 (Bhava)
        params: Optional dict with mode overrides:
            - horaLagnaMode: 0=Parasara (default), 1=Continuous
            - drekkanaMode: 0=Parasara (default), 1=Continuous
            - chaturthamsaMode: 0=Parasara (default), 1=Continuous
            - houseUseCusps: bool

    Returns:
        Rasi index (0-11) in the varga chart.
    """
    if params is None:
        params = {}

    rasi_len = _get_rasi_len(longitude)
    rasi = _get_rasi(longitude)
    is_odd = _is_odd_rasi(longitude)

    if division == 1:
        # D1: Rasi — unchanged
        ret = longitude

    elif division == 2:
        # D2: Hora
        hora_mode = params.get("horaLagnaMode", 0)
        if hora_mode == 0:
            # Parasara: odd rasis get first hora (0-15), even rasis get second
            ret = _a_red(longitude - 15, 60) + 90
        else:
            # Continuous
            ret = 2 * longitude

    elif division == 3:
        # D3: Drekkana
        drek_mode = params.get("drekkanaMode", 0)
        if drek_mode == 0:
            # Parasara: each 10° of a rasi maps to a different set
            ret = (math.floor(rasi_len / 10) * 120 + rasi * 30 + _get_rasi_len(3 * longitude))
        else:
            ret = 3 * longitude

    elif division == 4:
        # D4: Chaturthamsa
        chat_mode = params.get("chaturthamsaMode", 0)
        if chat_mode == 0:
            # Parasara: each 7.5° maps to 90°
            ret = (math.floor(rasi_len / 7.5) * 90 + rasi * 30 + _get_rasi_len(4 * longitude))
        else:
            ret = 4 * longitude

    elif division == 6:
        # D6: Shashthamsa
        ret = 6 * longitude

    elif division == 7:
        # D7: Saptamamsa
        basepos = rasi * 30 + rasi_len * 7
        if is_odd:
            ret = basepos
        else:
            ret = basepos + 180

    elif division == 8:
        # D8: Ashtamamsa
        ret = 8 * longitude

    elif division == 9:
        # D9: Navamsa — simply 9x longitude
        ret = 9 * longitude

    elif division == 10:
        # D10: Dasamsa
        basepos = rasi * 30 + rasi_len * 10
        if is_odd:
            ret = basepos
        else:
            ret = basepos + 240

    elif division == 12:
        # D12: Dvadasamsa
        ret = _get_dvadasamsa_longitude(longitude)

    elif division == 16:
        # D16: Shodasamsa
        ret = 16 * longitude

    elif division == 20:
        # D20: Vimsamsa
        ret = 20 * longitude

    elif division == 24:
        # D24: Siddhamsa
        basepos = rasi_len * 24
        if is_odd:
            ret = basepos + 120
        else:
            ret = basepos + 90

    elif division == 27:
        # D27: Bhamsa
        ret = 27 * longitude

    elif division == 30:
        # D30: Trimsamsa
        ret = _calc_trimsamsa(longitude, rasi, rasi_len)

    elif division == 40:
        # D40: Chatvarimsamsa
        basepos = rasi_len * 40
        if is_odd:
            ret = basepos
        else:
            ret = basepos + 180

    elif division == 45:
        # D45: Akshavedamsa
        basepos = rasi_len * 45
        if _is_movable_rasi(longitude):
            ret = basepos
        elif _is_fixed_rasi(longitude):
            ret = basepos + 120
        else:
            ret = basepos + 240

    elif division == 60:
        # D60: Shashtiamsa
        ret = 60 * rasi_len + rasi * 30

    elif division == 108:
        # D108: Ashtottaramsa
        ret = _get_dvadasamsa_longitude(9 * longitude)

    elif division == 144:
        # D144: Dvadas-dvadasamsa
        ret = _get_dvadasamsa_longitude(_get_dvadasamsa_longitude(longitude))

    elif division == 0:
        # Bhava (house position in rasi chart)
        # Simplified: returns rasi index directly
        ret = longitude

    else:
        raise ValueError(f"Unsupported varga division: {division}")

    return _get_rasi(_red_deg(ret))


def _get_dvadasamsa_longitude(longitude: float) -> float:
    """Calculate the longitude for D-12 (and used by D-108, D-144).
    From Maitreya: red_deg(getRasi(len) * 30 + getRasiLen(len) * 12)
    """
    return _red_deg(_get_rasi(longitude) * 30 + _get_rasi_len(longitude) * 12)


def _calc_trimsamsa(longitude: float, rasi: int, rasi_len: float) -> float:
    """D30: Trimsamsa calculation.
    From Maitreya Varga.cpp: handles odd vs even rasis differently.
    """
    if _is_odd_rasi(longitude):
        # Odd rasis: Ar(0), Ge(2), Le(4), Li(6), Sg(8), Aq(10)
        if rasi_len < 5:
            ret = 30 * 0 + rasi_len * 6  # Aries
        elif rasi_len <= 10:
            ret = 30 * 10 + (rasi_len - 5) * 6  # Aquarius
        elif rasi_len <= 18:
            ret = 30 * 8 + (rasi_len - 10) / 4 * 15  # Sagittarius
        elif rasi_len <= 25:
            ret = 30 * 2 + (rasi_len - 18) / 7 * 30  # Gemini
        else:
            ret = 30 * 6 + (rasi_len - 25) * 6  # Libra
    else:
        # Even rasis: Ta(1), Cn(3), Vi(5), Sc(7), Cp(9), Pi(11)
        if rasi_len < 5:
            ret = 30 * 1 + (5 - rasi_len) * 6  # Taurus (reversed)
        elif rasi_len <= 10:
            ret = 30 * 5 + (10 - rasi_len) * 6  # Virgo (reversed)
        elif rasi_len <= 18:
            ret = 30 * 11 + (18 - rasi_len) / 4 * 15  # Pisces (reversed)
        elif rasi_len <= 25:
            ret = 30 * 9 + (25 - rasi_len) / 7 * 30  # Capricorn (reversed)
        else:
            ret = 30 * 7 + (30 - rasi_len) * 6  # Scorpio (reversed)

    return ret


def varga_rasi_for_planet(planet_longitude: float, varga_defs: list[dict[str, Any]] | None = None) -> dict[str, int]:
    """Return varga rasi for a planet across all supported vargas.

    Args:
        planet_longitude: The planet's longitude.
        varga_defs: List of varga definitions with 'num' key. Defaults to all.

    Returns:
        Dict mapping varga_id (e.g. 'D1', 'D9') to rasi_index (0-11).
    """
    if varga_defs is None:
        from astro_backend_jyotish_data import VARGA_DEFINITIONS
        varga_defs = VARGA_DEFINITIONS

    result = {}
    for vd in varga_defs:
        varga_num = vd["num"]
        varga_id = vd["id"]
        result[varga_id] = calc_varga(planet_longitude, varga_num)
    return result
