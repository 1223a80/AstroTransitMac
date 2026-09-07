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
    """Calculate the Varga (divisional) chart rasi index for a given longitude."""
    varga_lon = calc_varga_longitude(longitude, division, params)
    return _get_rasi(_red_deg(varga_lon))


def calc_varga_longitude(longitude: float, division: int, params: dict[str, Any] | None = None) -> float:
    """Calculate the full Varga longitude (not reduced to rasi).

    Returns the varga chart longitude in degrees (0-360), preserving
    intra-sign position for degree/nakshatra computation.
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
        # D2: Hora — continuous doubling with Parasara sign selection.
        # Each 15° half-sign (hora) maps to a full 30° varga sign.
        # Odd signs (fiery): first half (0-15°) → Leo(120), second half (15-30°) → Cancer(90)
        # Even signs (earthy): first half (0-15°) → Cancer(90), second half (15-30°) → Leo(120)
        # Degree within varga sign = (rasi_len % 15) * 2  (0-30°)
        inner_deg = (rasi_len % 15.0) * 2.0
        hora_offset = 120.0 if (is_odd == (rasi_len < 15.0)) else 90.0
        ret = inner_deg + hora_offset

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

    return _red_deg(ret)


def _get_dvadasamsa_longitude(longitude: float) -> float:
    """Calculate the longitude for D-12 (and used by D-108, D-144).
    From Maitreya: red_deg(getRasi(len) * 30 + getRasiLen(len) * 12)
    """
    return _red_deg(_get_rasi(longitude) * 30 + _get_rasi_len(longitude) * 12)


def _calc_trimsamsa(longitude: float, rasi: int, rasi_len: float) -> float:
    """D30: Trimsamsa calculation.
    Odd rasis: Aries(5°), Aquarius(5°), Sagittarius(8°), Gemini(7°), Libra(5°).
    Even rasis: Taurus(5°), Virgo(7°), Pisces(8°), Capricorn(5°), Scorpio(5°).
    """
    if _is_odd_rasi(longitude):
        # Odd rasis: Ar(0), Ge(2), Le(4), Li(6), Sg(8), Aq(10)
        if rasi_len < 5.0:
            ret = 30 * 0 + rasi_len * 6.0  # Aries [0, 5)
        elif rasi_len < 10.0:
            ret = 30 * 10 + (rasi_len - 5.0) * 6.0  # Aquarius [5, 10)
        elif rasi_len < 18.0:
            ret = 30 * 8 + (rasi_len - 10.0) / 8.0 * 30.0  # Sagittarius [10, 18)
        elif rasi_len < 25.0:
            ret = 30 * 2 + (rasi_len - 18.0) / 7.0 * 30.0  # Gemini [18, 25)
        else:
            ret = 30 * 6 + (rasi_len - 25.0) * 6.0  # Libra [25, 30)
    else:
        # Even rasis: Ta(1), Cn(3), Vi(5), Sc(7), Cp(9), Pi(11)
        if rasi_len < 5.0:
            deg = min((5.0 - rasi_len) * 6.0, 29.9999999999)  # Taurus [0, 5) 5°
            ret = 30 * 1 + deg
        elif rasi_len < 12.0:
            deg = min((12.0 - rasi_len) / 7.0 * 30.0, 29.9999999999)  # Virgo [5, 12) 7°
            ret = 30 * 5 + deg
        elif rasi_len < 20.0:
            deg = min((20.0 - rasi_len) / 8.0 * 30.0, 29.9999999999)  # Pisces [12, 20) 8°
            ret = 30 * 11 + deg
        elif rasi_len < 25.0:
            deg = min((25.0 - rasi_len) * 6.0, 29.9999999999)  # Capricorn [20, 25) 5°
            ret = 30 * 9 + deg
        else:
            deg = min((30.0 - rasi_len) * 6.0, 29.9999999999)  # Scorpio [25, 30) 5°
            ret = 30 * 7 + deg

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
