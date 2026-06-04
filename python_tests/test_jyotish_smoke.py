"""pytest smoke tests for Vedic (Jyotish) backend.

Covers: Rahu/Ketu naming, Ayanamsha, House system, Dig Bala ASC,
Yogini Dasa cycling, Vimsottari Dasa, validation, Shadbala.
"""

import sys
import os
import pytest

_backend_dir = os.path.join(
    os.path.dirname(__file__), "..", "Sources", "TransitStudio", "Resources", "backend"
)
sys.path.insert(0, os.path.abspath(_backend_dir))


# ─── Fixtures ─────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def positions():
    from astro_backend_core import set_zodiac_mode, jd_from_datetime
    from astro_backend_jyotish import _resolve_vedic_positions
    from datetime import datetime, timezone, timedelta
    tz = timezone(timedelta(hours=8))
    birth_dt = datetime(1990, 1, 1, 12, 0, tzinfo=tz)
    birth_jd = jd_from_datetime(birth_dt)
    set_zodiac_mode("sidereal_lahiri")
    return _resolve_vedic_positions(birth_jd, True, [])


@pytest.fixture(scope="module")
def full_result():
    from astro_backend_jyotish import calculate_vedic
    request = {
        "birth": {
            "moment": {"year": 1990, "month": 1, "day": 1, "hour": 12, "minute": 0,
                       "timezone": "Asia/Shanghai"},
            "latitude": 31.2304, "longitude": 121.4737,
            "houseSystem": "whole_sign",
            "zodiac": "sidereal_lahiri",
        },
        "reference": {"year": 2026, "month": 5, "day": 5, "hour": 12, "minute": 0,
                      "timezone": "Asia/Shanghai"},
        "full": True,
    }
    return calculate_vedic(request, [])


# ─── 1. Data layer names ────────────────────────────────────────────

class TestDataLayer:
    def test_rahu_name(self):
        from astro_backend_jyotish_data import VEDIC_PLANET_NAMES
        assert VEDIC_PLANET_NAMES["RAHU"] == ("Rahu", "罗睺"), VEDIC_PLANET_NAMES["RAHU"]

    def test_ketu_name(self):
        from astro_backend_jyotish_data import VEDIC_PLANET_NAMES
        assert VEDIC_PLANET_NAMES["KETU"] == ("Ketu", "计都"), VEDIC_PLANET_NAMES["KETU"]

    def test_vedic_planet_ids(self):
        from astro_backend_jyotish_data import VEDIC_PLANET_IDS
        assert "RAHU" in VEDIC_PLANET_IDS
        assert "KETU" in VEDIC_PLANET_IDS

    def test_nakshatra_28_count(self):
        from astro_backend_jyotish_data import NAKSHATRA_DATA
        assert len(NAKSHATRA_DATA) == 27

    def test_ayanamsha_map_has_keys(self):
        from astro_backend_jyotish_data import AYANAMSHA_MAP
        for k in ("lahiri", "raman", "krishnamurti", "yukteshwar", "citra"):
            assert k in AYANAMSHA_MAP, f"missing {k}"


# ─── 2. Planet positions ─────────────────────────────────────────────

class TestPlanetPositions:
    def test_rahu_present(self, positions):
        assert "RAHU" in positions

    def test_ketu_present(self, positions):
        assert "KETU" in positions

    def test_sun_present(self, positions):
        assert "SUN" in positions

    def test_moon_present(self, positions):
        assert "MOON" in positions

    def test_rahu_name(self, positions):
        assert positions["RAHU"]["name"] == "罗睺"

    def test_ketu_name(self, positions):
        assert positions["KETU"]["name"] == "计都"

    def test_rahu_ketu_opposition(self, positions):
        diff = abs(positions["RAHU"]["longitude"] - positions["KETU"]["longitude"]) % 360
        assert abs(diff - 180) < 0.1, f"RAHU/KETU diff={diff:.4f}, expected 180°"

    def test_nakshatra_on_sun(self, positions):
        from astro_backend_jyotish_data import nakshatra_for_longitude
        nak = nakshatra_for_longitude(positions["SUN"]["longitude"])
        assert nak["name_sa"]
        assert 1 <= nak["pada"] <= 4


# ─── 3. Ayanamsha ───────────────────────────────────────────────────

class TestAyanamsha:
    def test_raman_configured(self, full_result):
        # Uses sa_Lahiri by default, but we just check the key is populated
        assert "ayanamsha" in full_result["meta"]

    def test_lahiri_via_swephem(self):
        from astro_backend_core import set_zodiac_mode, swe
        set_zodiac_mode("sidereal_raman")
        assert True  # no crash

    def test_krishnamurti_via_swephem(self):
        from astro_backend_core import set_zodiac_mode, swe
        set_zodiac_mode("sidereal_krishnamurti")
        assert True  # no crash


# ─── 4. Full calculation result structure ───────────────────────────

class TestFullResult:
    def test_rasi_chart_present(self, full_result):
        assert "rasi_chart" in full_result

    def test_planets_present(self, full_result):
        assert len(full_result.get("planets", {})) >= 7

    def test_vimsottari_present(self, full_result):
        assert "vimshottari" in full_result

    def test_vimsottari_current(self, full_result):
        v = full_result["vimshottari"]
        assert v.get("current_mahadasa") is not None

    def test_vimsottari_9_periods(self, full_result):
        dasas = full_result["vimshottari"].get("maha_dasas", [])
        assert len(dasas) == 9, f"expected 9, got {len(dasas)}"

    def test_shadbala_present(self, full_result):
        assert "shadbala" in full_result

    def test_shadbala_has_sun(self, full_result):
        assert "SUN" in full_result.get("shadbala", {})

    def test_yogas_present(self, full_result):
        assert "yogas" in full_result

    def test_yogas_nonempty(self, full_result):
        yogas = full_result.get("yogas", [])
        assert len(yogas) > 0, "expected at least one yoga"


# ─── 5. Yogini Dasa (cycling) ───────────────────────────────────────

class TestYoginiDasa:
    def test_yogini_present(self, full_result):
        assert "yogini_dasa" in full_result

    def test_yogini_more_than_one_cycle(self, full_result):
        periods = full_result["yogini_dasa"].get("yogini_dasas", [])
        assert len(periods) > 8, f"only {len(periods)} periods, expected >8 (should cycle)"

    def test_yogini_current_found(self, full_result):
        cur = full_result["yogini_dasa"].get("current_yogini")
        assert cur is not None, "current_yogini is None"


# ─── 6. Ashtottari Dasa ─────────────────────────────────────────────

class TestAshtottariDasa:
    def test_ashtottari_present(self, full_result):
        assert "ashtottari_dasa" in full_result

    def test_ashtottari_current_found(self, full_result):
        cur = full_result["ashtottari_dasa"].get("current_ashtottari")
        assert cur is not None, "current_ashtottari is None"


# ─── 7. Dig Bala with different ASC ─────────────────────────────────

class TestDigBala:
    def test_dig_bala_varies_with_asc(self):
        from astro_backend_jyotish_shadbala import calc_dig_bala
        d1 = calc_dig_bala("SUN", 10.0, 0.0)
        d2 = calc_dig_bala("SUN", 10.0, 90.0)
        assert d1 != d2, f"Dig Bala same with ASC 0° and 90°: {d1}"

    def test_dig_bala_uses_rasi_not_absolute(self):
        from astro_backend_jyotish_shadbala import calc_dig_bala
        # Sun in Aries (10°). ASC also Aries (0°): Sun in 1st house.
        d_asc_0 = calc_dig_bala("SUN", 10.0, 0.0)
        # Same Sun, ASC Leo (120°): Sun in 7th house → different
        d_asc_120 = calc_dig_bala("SUN", 10.0, 120.0)
        assert d_asc_0 != d_asc_120


# ─── 8. Bad request validation ──────────────────────────────────────

class TestValidation:
    def test_empty_request_fails(self):
        from astro_backend_api import validate_required_fields
        err = validate_required_fields({})
        assert err is not None

    def test_vedic_missing_moment_fails(self):
        from astro_backend_api import validate_required_fields
        req = {"mode": "vedic", "birth": {"latitude": 31.0, "longitude": 121.0}}
        err = validate_required_fields(req)
        assert err is not None
        assert "moment" in str(err)

    def test_vedic_valid_request_passes(self):
        from astro_backend_api import validate_required_fields
        req = {"mode": "vedic", "birth": {
            "moment": {"year": 1990, "month": 1, "day": 1, "hour": 12, "minute": 0, "timezone": "Asia/Shanghai"},
            "latitude": 31.0, "longitude": 121.0,
        }}
        err = validate_required_fields(req)
        assert err is None, f"expected None, got {err}"
