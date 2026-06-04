"""pytest reference-data verification for Vedic (Jyotish) backend.

Compares planet positions, D9 varga, Vimsottari Dasa against reference data
from external Vedic software (True Citra, 1990-04-20 Beijing).
"""

import sys
import os
import pytest
from datetime import datetime, timezone, timedelta

_backend_dir = os.path.join(
    os.path.dirname(__file__), "..", "Sources", "TransitStudio", "Resources", "backend"
)
sys.path.insert(0, os.path.abspath(_backend_dir))


# ─── Shared fixtures ────────────────────────────────────────────────

@pytest.fixture(scope="module")
def birth_dt():
    tz = timezone(timedelta(hours=8))
    return datetime(1990, 4, 20, 8, 30, tzinfo=tz)


@pytest.fixture(scope="module")
def birth_jd(birth_dt):
    from astro_backend_core import jd_from_datetime
    return jd_from_datetime(birth_dt)


@pytest.fixture(scope="module")
def positions(birth_jd):
    from astro_backend_core import set_zodiac_mode
    from astro_backend_jyotish import _resolve_vedic_positions
    set_zodiac_mode("sidereal_citra")
    return _resolve_vedic_positions(birth_jd, True, [])


@pytest.fixture(scope="module")
def asc_lon(birth_jd):
    from astro_backend_ephemeris import build_houses
    _, angles, _ = build_houses(birth_jd, 39.93, 116.41, "whole_sign", True, [])
    return angles["ASC"]


# ─── Reference data ─────────────────────────────────────────────────

REF_PLANETS = {
    "SUN":     {"rasi": 1,  "deg_int": 5,  "nak_idx": 0,  "pada": 2},
    "MOON":    {"rasi": 10, "deg_int": 26, "nak_idx": 22, "pada": 1},
    "MARS":    {"rasi": 11, "deg_int": 5,  "nak_idx": 22, "pada": 4},
    "MERCURY": {"rasi": 1,  "deg_int": 23, "nak_idx": 1,  "pada": 3},
    "JUPITER": {"rasi": 3,  "deg_int": 11, "nak_idx": 5,  "pada": 2},
    "VENUS":   {"rasi": 11, "deg_int": 20, "nak_idx": 24, "pada": 1},
    "SATURN":  {"rasi": 10, "deg_int": 1,  "nak_idx": 20, "pada": 2},
}

REF_D9 = {
    "SUN": 1, "MOON": 4, "MARS": 7, "MERCURY": 6,
    "JUPITER": 9, "VENUS": 0, "SATURN": 9,
}

VIMSOTTARI_SEQ = ["MARS", "RAHU", "JUPITER", "SATURN", "MERCURY", "KETU", "VENUS", "SUN", "MOON"]
VIMSOTTARI_DUR = [7, 18, 16, 19, 17, 7, 20, 6, 10]


# ─── 1. Planet longitudes ───────────────────────────────────────────

class TestPlanetLongitudes:
    def test_all_planets_present(self, positions):
        for pid in REF_PLANETS:
            assert pid in positions, f"{pid} missing"

    @pytest.mark.parametrize("pid", list(REF_PLANETS.keys()))
    def test_rasi(self, positions, pid):
        ref = REF_PLANETS[pid]
        lon = positions[pid]["longitude"]
        rasi = int(lon // 30) + 1
        assert rasi == ref["rasi"], f"{pid} rasi={rasi}, ref={ref['rasi']}"

    @pytest.mark.parametrize("pid", list(REF_PLANETS.keys()))
    def test_degree(self, positions, pid):
        ref = REF_PLANETS[pid]
        lon = positions[pid]["longitude"]
        deg_int = int(lon % 30)
        assert abs(deg_int - ref["deg_int"]) <= 1, \
            f"{pid} deg≈{deg_int}, ref≈{ref['deg_int']}"

    @pytest.mark.parametrize("pid", list(REF_PLANETS.keys()))
    def test_nakshatra_index(self, positions, pid):
        from astro_backend_jyotish_data import nakshatra_for_longitude
        ref = REF_PLANETS[pid]
        nak = nakshatra_for_longitude(positions[pid]["longitude"])
        assert nak["index"] == ref["nak_idx"], \
            f"{pid} nak idx={nak['index']}, ref={ref['nak_idx']}"

    @pytest.mark.parametrize("pid", list(REF_PLANETS.keys()))
    def test_pada(self, positions, pid):
        from astro_backend_jyotish_data import nakshatra_for_longitude
        ref = REF_PLANETS[pid]
        nak = nakshatra_for_longitude(positions[pid]["longitude"])
        assert nak["pada"] == ref["pada"], \
            f"{pid} pada={nak['pada']}, ref={ref['pada']}"


# ─── 2. ASC ─────────────────────────────────────────────────────────

class TestAsc:
    def test_asc_rasi(self, asc_lon):
        rasi = int(asc_lon // 30) + 1
        assert rasi == 2, f"ASC rasi={rasi}, expected 2 (Taurus)"

    def test_asc_degree(self, asc_lon):
        deg_int = int(asc_lon % 30)
        assert abs(deg_int - 29) <= 1, f"ASC deg≈{deg_int}, expected≈29"


# ─── 3. D9 Navamsa ─────────────────────────────────────────────────

class TestD9:
    @pytest.mark.parametrize("pid", list(REF_D9.keys()))
    def test_d9_rasi(self, positions, pid):
        from astro_backend_jyotish_varga import calc_varga
        d9 = calc_varga(positions[pid]["longitude"], 9)
        ref = REF_D9[pid]
        assert d9 == ref, f"{pid} D9={d9}, ref={ref}"

    def test_d9_asc(self, asc_lon):
        from astro_backend_jyotish_varga import calc_varga
        d9 = calc_varga(asc_lon, 9)
        assert d9 == 5, f"ASC D9={d9}, expected 5 (Virgo)"


# ─── 4. Vimsottari Dasa ────────────────────────────────────────────

class TestVimsottari:
    def test_first_lord_is_mars(self, positions, birth_dt):
        from datetime import datetime, timezone, timedelta
        from astro_backend_jyotish import _calc_vimsottari_dasa
        ref_dt = datetime(2026, 6, 4, 12, 0, tzinfo=timezone(timedelta(hours=8)))
        dasa = _calc_vimsottari_dasa(positions["MOON"]["longitude"], birth_dt, ref_dt)
        assert dasa["maha_dasas"][0]["lord"] == "MARS", \
            f"first lord={dasa['maha_dasas'][0]['lord']}, expected MARS"

    def test_sequence(self, positions, birth_dt):
        from datetime import datetime, timezone, timedelta
        from astro_backend_jyotish import _calc_vimsottari_dasa
        ref_dt = datetime(2026, 6, 4, 12, 0, tzinfo=timezone(timedelta(hours=8)))
        dasa = _calc_vimsottari_dasa(positions["MOON"]["longitude"], birth_dt, ref_dt)
        got = [d["lord"] for d in dasa["maha_dasas"]]
        assert got == VIMSOTTARI_SEQ, f"sequence={got}, expected={VIMSOTTARI_SEQ}"

    def test_durations(self, positions, birth_dt):
        from datetime import datetime, timezone, timedelta
        from astro_backend_jyotish import _calc_vimsottari_dasa
        ref_dt = datetime(2026, 6, 4, 12, 0, tzinfo=timezone(timedelta(hours=8)))
        dasa = _calc_vimsottari_dasa(positions["MOON"]["longitude"], birth_dt, ref_dt)
        got = [d["duration_years"] for d in dasa["maha_dasas"]]
        assert got == VIMSOTTARI_DUR, f"durations={got}, expected={VIMSOTTARI_DUR}"

    def test_9_periods(self, positions, birth_dt):
        from datetime import datetime, timezone, timedelta
        from astro_backend_jyotish import _calc_vimsottari_dasa
        ref_dt = datetime(2026, 6, 4, 12, 0, tzinfo=timezone(timedelta(hours=8)))
        dasa = _calc_vimsottari_dasa(positions["MOON"]["longitude"], birth_dt, ref_dt)
        assert len(dasa["maha_dasas"]) == 9

    def test_nakshatra_lord_match(self, positions):
        from astro_backend_jyotish_data import nakshatra_for_longitude, NAKSHATRA_LORD_IDS
        nak = nakshatra_for_longitude(positions["MOON"]["longitude"])
        # Dhanishtha (index 22) → lord is MARS
        assert NAKSHATRA_LORD_IDS[nak["index"]] == "MARS"


# ─── 5. Nakshatra details ──────────────────────────────────────────

class TestNakshatraDetails:
    def test_sun_tara(self, positions):
        from astro_backend_jyotish_data import nakshatra_index_for_longitude, nakshatra_details
        moon_idx = nakshatra_index_for_longitude(positions["MOON"]["longitude"])
        det = nakshatra_details(positions["SUN"]["longitude"], moon_idx)
        assert "tara" in det

    def test_sun_yoni(self, positions):
        from astro_backend_jyotish_data import nakshatra_details
        det = nakshatra_details(positions["SUN"]["longitude"])
        assert "yoni" in det

    def test_sun_gana(self, positions):
        from astro_backend_jyotish_data import nakshatra_details
        det = nakshatra_details(positions["SUN"]["longitude"])
        assert "gana" in det

    def test_sun_nadi(self, positions):
        from astro_backend_jyotish_data import nakshatra_details
        det = nakshatra_details(positions["SUN"]["longitude"])
        assert "nadi" in det
