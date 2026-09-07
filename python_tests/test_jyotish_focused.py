"""Focused pytest tests for new Vedic AI export features.

Covers: panchanga, solar_day, divisional_charts, moon_chart, bhava_chart,
planet_relationships, arudha, jaimini_karakas, ashtakavarga, vimshottari.antardashas.
"""

import sys
import os
import pytest
from datetime import datetime, timezone, timedelta

_backend_dir = os.path.join(
    os.path.dirname(__file__), "..", "Sources", "TransitStudio", "Resources", "backend"
)
sys.path.insert(0, os.path.abspath(_backend_dir))


# ─── Shared Fixtures ─────────────────────────────────────────────────

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


@pytest.fixture(scope="module")
def positions_with_reference():
    """Full Vedic result for the sample request."""
    from astro_backend_jyotish import calculate_vedic
    request = {
        "birth": {
            "moment": {"year": 1990, "month": 4, "day": 20, "hour": 8, "minute": 30,
                       "timezone": "Asia/Shanghai"},
            "latitude": 39.93, "longitude": 116.41,
            "houseSystem": "whole_sign",
            "zodiac": "sidereal_citra",
        },
        "reference": {"year": 2026, "month": 6, "day": 4, "hour": 12, "minute": 0,
                      "timezone": "Asia/Shanghai"},
        "full": True,
    }
    return calculate_vedic(request, [])


@pytest.fixture(scope="module")
def linyi_reference_result():
    from astro_backend_jyotish import calculate_vedic
    request = {
        "birth": {
            "moment": {"year": 2004, "month": 8, "day": 9, "hour": 16, "minute": 16,
                       "timezone": "Asia/Shanghai"},
            "latitude": 35.0576, "longitude": 118.3346,
            "houseSystem": "whole_sign",
            "zodiac": "sidereal_lahiri",
        },
        "reference": {"year": 2004, "month": 8, "day": 9, "hour": 16, "minute": 16,
                      "timezone": "Asia/Shanghai"},
        "full": True,
    }
    return calculate_vedic(request, [])


# ─── 1. Panchanga ────────────────────────────────────────────────────

class TestPanchanga:
    def test_panchanga_present(self, positions_with_reference):
        assert "panchanga" in positions_with_reference

    def test_panchanga_has_all_limbs(self, positions_with_reference):
        p = positions_with_reference["panchanga"]
        for limb in ("tithi", "vara", "nakshatra", "yoga", "karana"):
            assert limb in p, f"missing {limb}"

    def test_tithi_has_index(self, positions_with_reference):
        t = positions_with_reference["panchanga"]["tithi"]
        assert "index" in t
        assert 0 <= t["index"] <= 29

    def test_tithi_has_bounds(self, positions_with_reference):
        t = positions_with_reference["panchanga"]["tithi"]
        assert "start_longitude" in t
        assert "end_longitude" in t
        assert t["end_longitude"] > t["start_longitude"]

    def test_vara_has_name(self, positions_with_reference):
        v = positions_with_reference["panchanga"]["vara"]
        assert v["name_sa"]
        assert v["name_zh"]

    def test_nakshatra_has_lord(self, positions_with_reference):
        n = positions_with_reference["panchanga"]["nakshatra"]
        assert "lord" in n

    def test_yoga_has_name(self, positions_with_reference):
        y = positions_with_reference["panchanga"]["yoga"]
        assert y["name_sa"]
        assert y["name_zh"]

    def test_karana_has_bounds(self, positions_with_reference):
        k = positions_with_reference["panchanga"]["karana"]
        assert "start_longitude" in k
        assert "end_longitude" in k

    def test_panchanga_calc_tithi(self):
        from astro_backend_jyotish_panchanga import calc_tithi
        # Example: Sun at 0°, Moon at 45° → tithi index = floor(45/12) = 3
        result = calc_tithi(0.0, 45.0)
        assert result["index"] == 3
        assert result["name_sa"] == "Chaturthi"
        assert result["paksha"] == "Shukla"

    def test_panchanga_calc_yoga(self):
        from astro_backend_jyotish_panchanga import calc_panchanga_yoga
        # Sun=10°, Moon=20° → sum=30° → yoga_index = floor(30/13.333) = 2
        result = calc_panchanga_yoga(10.0, 20.0)
        assert 0 <= result["index"] < 27

    def test_panchanga_calc_karana(self):
        from astro_backend_jyotish_panchanga import calc_karana
        # diff = 12° → karana_index = floor(12/6) = 2
        result = calc_karana(0.0, 12.0)
        assert 0 <= result["index"] < 60

    # ─── Value correctness tests ──────────────────────────────────

    def test_vara_friday_19900420(self, birth_jd):
        """1990-04-20 was a Friday (Shukravara)."""
        from astro_backend_jyotish_panchanga import calc_vara
        v = calc_vara(birth_jd, utc_offset_hours=8.0)
        assert v["index"] == 5, f"Expected 5 (Fri), got {v['index']} for {v['name_sa']}"
        assert v["name_sa"] == "Shukravara"

    def test_vara_same_with_dst(self, birth_jd):
        """Test with DST offset for China 1990 (UTC+9)."""
        from astro_backend_jyotish_panchanga import calc_vara
        v = calc_vara(birth_jd, utc_offset_hours=9.0)
        assert v["index"] == 5, f"Expected 5 (Fri) with DST, got {v['index']}"

    def test_sunrise_sunset_non_none(self):
        """Sunrise/sunset should return valid times for reasonable request."""
        from astro_backend_jyotish_panchanga import calc_sunrise_sunset
        from astro_backend_core import swe
        jd_0h = swe.julday(1990, 4, 20, 0.0) - 0.5
        r = calc_sunrise_sunset(2448001.5, 39.93, 116.41, utc_offset_hours=8.0, jd_0h=jd_0h)
        assert r["sunrise_local"] is not None, f"sunrise is None: {r}"
        assert r["sunset_local"] is not None, f"sunset is None: {r}"
        assert "1990-04-20" in r["sunrise_local"], f"sunrise date wrong: {r['sunrise_local']}"
        assert "1990-04-20" in r["sunset_local"], f"sunset date wrong: {r['sunset_local']}"

    def test_sunrise_sunset_exception_records_error(self, monkeypatch):
        """rise_trans exceptions must not be swallowed; record per-side errors."""
        from astro_backend_jyotish_panchanga import calc_sunrise_sunset
        from astro_backend_core import swe

        def boom(*args, **kwargs):
            raise RuntimeError("rise_trans exploded")

        monkeypatch.setattr(swe, "rise_trans", boom)
        jd_0h = swe.julday(1990, 4, 20, 0.0) - 0.5
        r = calc_sunrise_sunset(2448001.5, 39.93, 116.41, utc_offset_hours=8.0, jd_0h=jd_0h)
        assert r["sunrise_local"] is None
        assert r["sunset_local"] is None
        assert "rise_trans exploded" in r.get("sunrise_error", "")
        assert "rise_trans exploded" in r.get("sunset_error", "")

    def test_d9_upagrahas_different_from_d1(self, positions_with_reference):
        """D9 upagraha longitudes should differ from D1 (varga-mapped)."""
        dc = positions_with_reference.get("divisional_charts", {})
        d1 = dc.get("D1", {})
        d9 = dc.get("D9", {})
        d1_upas = d1.get("upagrahas", [])
        d9_upas = d9.get("upagrahas", [])
        assert len(d1_upas) > 0, "No D1 upagrahas"
        assert len(d9_upas) > 0, "No D9 upagrahas"
        # Check at least one upa has different longitude
        different = False
        for i in range(min(len(d1_upas), len(d9_upas))):
            if abs(d1_upas[i]["longitude"] - d9_upas[i]["longitude"]) > 0.1:
                different = True
                break
        assert different, "All D9 upagrahas identical to D1"

    def test_d9_special_lagnas_different_from_d1(self, positions_with_reference):
        """D9 special lagna longitudes should differ from D1 (varga-mapped)."""
        dc = positions_with_reference.get("divisional_charts", {})
        d1 = dc.get("D1", {})
        d9 = dc.get("D9", {})
        d1_lag = d1.get("special_lagnas", [])
        d9_lag = d9.get("special_lagnas", [])
        assert len(d1_lag) > 0, "No D1 special_lagnas"
        assert len(d9_lag) > 0, "No D9 special_lagnas"
        different = False
        for i in range(min(len(d1_lag), len(d9_lag))):
            if abs(d1_lag[i]["longitude"] - d9_lag[i]["longitude"]) > 0.1:
                different = True
                break
        assert different, "All D9 special_lagnas identical to D1"

    def test_divisional_nakshatra_uses_varga_lon(self):
        """Divisional chart nakshatra should be based on varga longitude, not natal."""
        from astro_backend_jyotish_varga import calc_varga_longitude
        from astro_backend_jyotish_data import nakshatra_for_longitude
        # Sun at ~5.96° in Aries (natal): nakshatra = Ashvini (idx 0)
        natal_lon = 5.96
        nat_nak = nakshatra_for_longitude(natal_lon)
        # D2 of Sun: varga longitude ~131.92° = Leo → nakshatra = Magha (idx 9)
        v_lon_d2 = calc_varga_longitude(natal_lon, 2)
        d2_nak = nakshatra_for_longitude(v_lon_d2 % 360)
        assert abs(d2_nak["index"] - 9) <= 1, \
            f"D2 nakshatra idx={d2_nak['index']}, expected ~9(Magha), natal was {nat_nak['index']}({nat_nak['name_sa']})"
        assert d2_nak["index"] != nat_nak["index"], \
            "D2 nakshatra must differ from natal"


# ─── 2. Solar Day ───────────────────────────────────────────────────

class TestSolarDay:
    def test_solar_day_present(self, positions_with_reference):
        assert "solar_day" in positions_with_reference

    def test_solar_day_has_fields(self, positions_with_reference):
        sd = positions_with_reference["solar_day"]
        assert "sunrise_local" in sd
        assert "sunset_local" in sd


# ─── 3. Divisional Charts ───────────────────────────────────────────

class TestDivisionalCharts:
    def test_divisional_charts_present(self, positions_with_reference):
        assert "divisional_charts" in positions_with_reference

    def test_all_16_vargas_present(self, positions_with_reference):
        dc = positions_with_reference["divisional_charts"]
        expected = ["D1", "D2", "D3", "D4", "D7", "D9", "D10", "D12",
                     "D16", "D20", "D24", "D27", "D30", "D40", "D45", "D60"]
        for vg in expected:
            assert vg in dc, f"missing {vg}"

    def test_each_chart_has_planets(self, positions_with_reference):
        dc = positions_with_reference["divisional_charts"]
        for vg_id, chart in dc.items():
            assert "planets" in chart, f"{vg_id} missing planets"
            assert len(chart["planets"]) >= 7, f"{vg_id} has < 7 planets"

    def test_d1_has_upagrahas(self, positions_with_reference):
        d1 = positions_with_reference["divisional_charts"].get("D1", {})
        assert "upagrahas" in d1

    def test_d9_has_special_lagnas(self, positions_with_reference):
        d9 = positions_with_reference["divisional_charts"].get("D9", {})
        assert "special_lagnas" in d9


# ─── 3b. Divisional Chart Reference Values (against sample-vedic-ai-request.json) ──

class TestDivisionalReferenceValues:
    """Lock ALL 8 D2 entries against sample-vedic-ai-expected.txt values.

    Every assertion checks varga_rasi (0-indexed), nakshatra.name_sa,
    nakshatra.pada, nakshatra.lord, and degree range.
    This protects against regression in calc_varga_longitude(D2) formula.
    """

    _D2_REF = {
        # pid: (rasi_0idx, nakshatra_name, nak_lord, pada, deg_min, deg_max)
        "ASC":     (4, "Uttara Phalguni", "SUN", 1, 28.80, 29.80),
        "SUN":     (4, "Magha",           "KETU", 4, 11.80, 12.10),
        "MOON":    (4, "Purva Phalguni",  "VENUS", 3, 22.80, 23.50),
        "MARS":    (4, "Magha",           "KETU", 4, 11.00, 11.50),
        "MERCURY": (3, "Pushya",          "SATURN", 4, 16.30, 16.90),
        "JUPITER": (4, "Purva Phalguni",  "VENUS", 3, 22.80, 23.20),
        "VENUS":   (3, "Pushya",          "SATURN", 3, 11.20, 11.70),
        "SATURN":  (3, "Punarvasu",       "JUPITER", 4, 2.60, 3.30),
    }

    def _check_d2(self, pid, exp_rasi, exp_nak, exp_lord, exp_pada, deg_lo, deg_hi,
                  planets: dict):
        p = planets[pid]
        n = p["nakshatra"]
        errs = []
        if p["varga_rasi"] != exp_rasi:
            errs.append(f"rasi={p['varga_rasi']}(exp={exp_rasi})")
        if n["name_sa"] != exp_nak:
            errs.append(f"nak={n['name_sa']}(exp={exp_nak})")
        if n["lord"] != exp_lord:
            errs.append(f"lord={n['lord']}(exp={exp_lord})")
        if n["pada"] != exp_pada:
            errs.append(f"pada={n['pada']}(exp={exp_pada})")
        d = p["varga_degree"]
        if not (deg_lo <= d <= deg_hi):
            errs.append(f"deg={d:.4f}(expected {deg_lo}–{deg_hi})")
        assert not errs, f"D2 {pid}: {'; '.join(errs)}"

    def test_d2_asc(self, positions_with_reference):
        self._check_d2("ASC", *self._D2_REF["ASC"],
                       positions_with_reference["divisional_charts"]["D2"]["planets"])

    def test_d2_sun(self, positions_with_reference):
        self._check_d2("SUN", *self._D2_REF["SUN"],
                       positions_with_reference["divisional_charts"]["D2"]["planets"])

    def test_d2_moon(self, positions_with_reference):
        self._check_d2("MOON", *self._D2_REF["MOON"],
                       positions_with_reference["divisional_charts"]["D2"]["planets"])

    def test_d2_mars(self, positions_with_reference):
        self._check_d2("MARS", *self._D2_REF["MARS"],
                       positions_with_reference["divisional_charts"]["D2"]["planets"])

    def test_d2_mercury(self, positions_with_reference):
        self._check_d2("MERCURY", *self._D2_REF["MERCURY"],
                       positions_with_reference["divisional_charts"]["D2"]["planets"])

    def test_d2_jupiter(self, positions_with_reference):
        self._check_d2("JUPITER", *self._D2_REF["JUPITER"],
                       positions_with_reference["divisional_charts"]["D2"]["planets"])

    def test_d2_venus(self, positions_with_reference):
        self._check_d2("VENUS", *self._D2_REF["VENUS"],
                       positions_with_reference["divisional_charts"]["D2"]["planets"])

    def test_d2_saturn(self, positions_with_reference):
        self._check_d2("SATURN", *self._D2_REF["SATURN"],
                       positions_with_reference["divisional_charts"]["D2"]["planets"])


class TestD30Trimsamsha:
    """Test D30 Trimsamsa division boundaries and degree mapping."""

    @pytest.mark.parametrize(
        ("rasi_len", "expected_rasi", "sign_name"),
        [
            (0.0, 1, "Taurus"),
            (4.999999, 1, "Taurus"),
            (5.0, 5, "Virgo"),
            (5.000001, 5, "Virgo"),
            (11.999999, 5, "Virgo"),
            (12.0, 11, "Pisces"),
            (12.000001, 11, "Pisces"),
            (19.999999, 11, "Pisces"),
            (20.0, 9, "Capricorn"),
            (20.000001, 9, "Capricorn"),
            (24.999999, 9, "Capricorn"),
            (25.0, 7, "Scorpio"),
            (25.000001, 7, "Scorpio"),
            (29.999999, 7, "Scorpio"),
        ],
    )
    def test_even_sign_boundaries(self, rasi_len, expected_rasi, sign_name):
        from astro_backend_jyotish_varga import calc_varga, calc_varga_longitude
        # Taurus is even sign (rasi index 1, offset 30°)
        lon = 30.0 + rasi_len
        actual_rasi = calc_varga(lon, 30)
        actual_varga_lon = calc_varga_longitude(lon, 30)
        assert 0.0 <= actual_varga_lon < 360.0
        assert actual_rasi == expected_rasi, (
            f"Degree {rasi_len}° in even sign should be {sign_name} ({expected_rasi}), got {actual_rasi}"
        )

    def test_even_sign_reverse_mapping_slope(self):
        from astro_backend_jyotish_varga import calc_varga_longitude
        # Within Virgo segment [5, 12), as rasi_len increases, the degree within Virgo decreases
        lon_a = 30.0 + 6.0
        lon_b = 30.0 + 10.0
        v_a = calc_varga_longitude(lon_a, 30)
        v_b = calc_varga_longitude(lon_b, 30)
        assert v_a > v_b, "Even sign segment must map in reverse order"

    def test_odd_sign_boundaries(self):
        from astro_backend_jyotish_varga import calc_varga
        # Aries is odd sign (rasi index 0): 0..5 Ar(0), 5..10 Aq(10), 10..18 Sg(8), 18..25 Ge(2), 25..30 Li(6)
        assert calc_varga(2.0, 30) == 0   # Aries
        assert calc_varga(7.0, 30) == 10  # Aquarius
        assert calc_varga(14.0, 30) == 8  # Sagittarius
        assert calc_varga(21.0, 30) == 2  # Gemini
        assert calc_varga(27.0, 30) == 6  # Libra


# ─── 4. Moon Chart ──────────────────────────────────────────────────

class TestMoonChart:
    def test_moon_chart_present(self, positions_with_reference):
        assert "moon_chart" in positions_with_reference

    def test_moon_chart_has_planets(self, positions_with_reference):
        mc = positions_with_reference["moon_chart"]
        assert "planets" in mc
        assert len(mc["planets"]) >= 7

    def test_moon_chart_has_moon_rasi(self, positions_with_reference):
        mc = positions_with_reference["moon_chart"]
        assert "moon_rasi" in mc
        assert 0 <= mc["moon_rasi"] <= 11


# ─── 5. Bhava Chart ─────────────────────────────────────────────────

class TestBhavaChart:
    def test_bhava_chart_present(self, positions_with_reference):
        assert "bhava_chart" in positions_with_reference

    def test_bhava_chart_has_planets(self, positions_with_reference):
        bc = positions_with_reference["bhava_chart"]
        assert "planets" in bc
        assert len(bc["planets"]) >= 7

    def test_bhava_chart_has_houses(self, positions_with_reference):
        bc = positions_with_reference["bhava_chart"]
        for pid, planet in bc["planets"].items():
            if pid == "ASC":
                assert planet["house"] == 1

    def test_bhava_angles_are_quadrants_from_asc(self):
        from astro_backend_jyotish_divisional import build_bhava_chart
        chart = build_bhava_chart({}, 15.0)
        angles = {row["id"]: row["longitude"] for row in chart["angles"]}
        assert angles["ASC"] == 15.0
        assert angles["MC"] == 105.0
        assert angles["DSC"] == 195.0
        assert angles["IC"] == 285.0


# ─── 6. Planet Relationships ────────────────────────────────────────

class TestPlanetRelationships:
    def test_relationships_present(self, positions_with_reference):
        assert "planet_relationships" in positions_with_reference

    def test_has_naisargika(self, positions_with_reference):
        rel = positions_with_reference["planet_relationships"]
        assert "naisargika" in rel
        assert "data" in rel["naisargika"]

    def test_has_temporary(self, positions_with_reference):
        rel = positions_with_reference["planet_relationships"]
        assert "temporary" in rel
        assert "data" in rel["temporary"]

    def test_has_compound(self, positions_with_reference):
        rel = positions_with_reference["planet_relationships"]
        assert "compound" in rel
        assert "data" in rel["compound"]

    def test_compound_has_both_friendship_types(self, positions_with_reference):
        rel = positions_with_reference["planet_relationships"]
        comp = rel["compound"]["data"]
        # Check at least one planet has relationships
        for a, friends in comp.items():
            if a == "ASC":
                continue
            assert len(friends) > 0
            break

    def test_sun_has_all_relationships(self, positions_with_reference):
        rel = positions_with_reference["planet_relationships"]
        for section in ("naisargika", "temporary", "compound"):
            assert "SUN" in rel[section]["data"]

    def test_naisargika_sun_moon_is_friend(self):
        from astro_backend_jyotish_data import NAISARGIKA_FRIENDSHIP
        assert NAISARGIKA_FRIENDSHIP["SUN"]["MOON"] == 0  # friend

    def test_naisargika_sun_saturn_is_enemy(self):
        from astro_backend_jyotish_data import NAISARGIKA_FRIENDSHIP
        assert NAISARGIKA_FRIENDSHIP["SUN"]["SATURN"] == 2  # enemy

    def test_naisargika_classical_values_follow_reference(self):
        from astro_backend_jyotish_data import NAISARGIKA_FRIENDSHIP
        assert NAISARGIKA_FRIENDSHIP["SUN"]["MARS"] == 0
        assert NAISARGIKA_FRIENDSHIP["SUN"]["MERCURY"] == 1
        assert NAISARGIKA_FRIENDSHIP["MOON"]["MERCURY"] == 0
        assert NAISARGIKA_FRIENDSHIP["MERCURY"]["MOON"] == 2
        assert "RAHU" not in NAISARGIKA_FRIENDSHIP
        assert "KETU" not in NAISARGIKA_FRIENDSHIP


# ─── 7. Arudha ──────────────────────────────────────────────────────

class TestArudha:
    def test_arudha_present(self, positions_with_reference):
        assert "arudha" in positions_with_reference

    def test_arudha_has_al(self, positions_with_reference):
        ar = positions_with_reference["arudha"]
        assert "AL" in ar

    def test_arudha_has_ul(self, positions_with_reference):
        ar = positions_with_reference["arudha"]
        assert "UL" in ar

    def test_arudha_has_a_series(self, positions_with_reference):
        ar = positions_with_reference["arudha"]
        for i in range(2, 12):
            assert f"A{i}" in ar, f"missing A{i}"

    def test_arudha_pada_has_rasi(self, positions_with_reference):
        al = positions_with_reference["arudha"]["AL"]
        assert "rasi" in al
        assert 0 <= al["rasi"] <= 11

    def test_arudha_pada_has_house(self, positions_with_reference):
        al = positions_with_reference["arudha"]["AL"]
        assert "house" in al
        assert 1 <= al["house"] <= 12

    def test_arudha_same_house_exception_shifts_nine(self):
        from astro_backend_jyotish_arudha import calc_arudha_pada
        # Aries house (0), Mars in Aries (rasi 0): initial pada = 0 -> shifts to 10th from house = 9 (Capricorn)
        positions = {"MARS": {"longitude": 10.0}}
        assert calc_arudha_pada(0, 0, positions) == 9

    def test_arudha_opposite_house_exception_shifts_three(self):
        from astro_backend_jyotish_arudha import calc_arudha_pada
        # Aries house (0), Mars in Cancer (rasi 3): initial pada = 3 + 3 = 6 (Libra, opposite of Aries)
        # Exception shifts to 4th from house = (0 + 3) = 3 (Cancer)
        positions = {"MARS": {"longitude": 100.0}}
        assert calc_arudha_pada(0, 0, positions) == 3

    def test_arudha_normal_case_no_exception(self):
        from astro_backend_jyotish_arudha import calc_arudha_pada
        # Aries house (0), Mars in Gemini (rasi 2): initial pada = 2 + 2 = 4 (Leo, neither 0 nor 6)
        positions = {"MARS": {"longitude": 70.0}}
        assert calc_arudha_pada(0, 0, positions) == 4

    def test_arudha_wraparound_near_pisces(self):
        from astro_backend_jyotish_arudha import calc_arudha_pada
        # Pisces house (11), Jupiter in Pisces (rasi 11): initial pada = 11 -> shifts to (11 + 9) % 12 = 8 (Sagittarius)
        positions = {"JUPITER": {"longitude": 340.0}}
        assert calc_arudha_pada(11, 0, positions) == 8

        # Pisces house (11), Jupiter in Gemini (rasi 2): initial pada = (2 + (2 - 11)) % 12 = 5 (Virgo, opposite)
        # Exception shifts to (11 + 3) % 12 = 2 (Gemini)
        positions_opp = {"JUPITER": {"longitude": 70.0}}
        assert calc_arudha_pada(11, 0, positions_opp) == 2

    def test_compute_arudha_all_padas_valid_range(self):
        from astro_backend_jyotish_arudha import compute_arudha
        positions = {
            "SUN": {"longitude": 10.0},
            "MOON": {"longitude": 40.0},
            "MARS": {"longitude": 10.0},
            "MERCURY": {"longitude": 70.0},
            "JUPITER": {"longitude": 340.0},
            "VENUS": {"longitude": 190.0},
            "SATURN": {"longitude": 280.0},
        }
        res = compute_arudha(15.0, positions)
        assert 0 <= res["AL"]["rasi"] <= 11
        assert 0 <= res["UL"]["rasi"] <= 11
        for i in range(2, 12):
            assert 0 <= res[f"A{i}"]["rasi"] <= 11


# ─── 8. Jaimini Karakas ─────────────────────────────────────────────

class TestJaiminiKarakas:
    def test_jaimini_present(self, positions_with_reference):
        assert "jaimini_karakas" in positions_with_reference

    def test_has_chara_karakas(self, positions_with_reference):
        jk = positions_with_reference["jaimini_karakas"]
        assert "chara_karakas" in jk

    def test_atma_karaka_present(self, positions_with_reference):
        jk = positions_with_reference["jaimini_karakas"]
        ck = jk["chara_karakas"]
        assert len(ck) >= 7
        # Atma Karaka is the first one
        assert ck[0]["karaka_type"] == 0

    def test_dara_karaka_present(self, positions_with_reference):
        jk = positions_with_reference["jaimini_karakas"]
        ck = jk["chara_karakas"]
        # Last one should be Dara Karaka
        assert len(ck) >= 7
        assert any(k["karaka_type"] == 6 for k in ck)

    def test_karaka_has_planet(self, positions_with_reference):
        jk = positions_with_reference["jaimini_karakas"]
        assert jk["chara_karakas"][0]["planet"] in ("SUN", "MOON", "MARS", "MERCURY",
                                                      "JUPITER", "VENUS", "SATURN", "RAHU")

    def test_eight_planets_complete_order(self):
        from astro_backend_jyotish_jaimini import compute_chara_karakas
        positions = {
            "SUN": {"longitude": 28.0},      # rasi_len 28.0 (1st: Atma)
            "MOON": {"longitude": 24.0},     # rasi_len 24.0 (2nd: Amatya)
            "MARS": {"longitude": 20.0},     # rasi_len 20.0 (3rd: Bhratri)
            "MERCURY": {"longitude": 16.0},  # rasi_len 16.0 (4th: Matri)
            "JUPITER": {"longitude": 12.0},  # rasi_len 12.0 (5th: Pitri)
            "VENUS": {"longitude": 8.0},     # rasi_len 8.0  (6th: Putra)
            "SATURN": {"longitude": 4.0},    # rasi_len 4.0  (7th: Gnati)
            "RAHU": {"longitude": 29.0},     # eff_len 30 - 29 = 1.0 (8th: Dara)
        }
        res = compute_chara_karakas(positions, include_rahu=True)
        ck = res["chara_karakas"]
        assert len(ck) == 8
        assert res["system"] == "8-planet"
        assert [k["karaka_type"] for k in ck] == list(range(8))
        assert ck[0]["name_sa"] == "Atma Karaka"
        assert ck[4]["name_sa"] == "Pitri Karaka"
        assert ck[5]["name_sa"] == "Putra Karaka"
        assert ck[6]["name_sa"] == "Gnati Karaka"
        assert ck[7]["name_sa"] == "Dara Karaka"
        assert ck[4]["planet"] == "JUPITER"
        assert ck[7]["planet"] == "RAHU"

    def test_seven_planets_complete_order(self):
        from astro_backend_jyotish_jaimini import compute_chara_karakas
        positions = {
            "SUN": {"longitude": 28.0},
            "MOON": {"longitude": 24.0},
            "MARS": {"longitude": 20.0},
            "MERCURY": {"longitude": 16.0},
            "JUPITER": {"longitude": 12.0},
            "VENUS": {"longitude": 8.0},
            "SATURN": {"longitude": 4.0},
            "RAHU": {"longitude": 29.0},
        }
        res = compute_chara_karakas(positions, include_rahu=False)
        ck = res["chara_karakas"]
        assert len(ck) == 7
        assert res["system"] == "7-planet"
        assert [k["karaka_type"] for k in ck] == list(range(7))
        assert ck[0]["name_sa"] == "Atma Karaka"
        assert ck[4]["name_sa"] == "Putra Karaka"  # In 7-planet, 5th is Putra
        assert ck[5]["name_sa"] == "Gnati Karaka"
        assert ck[6]["name_sa"] == "Dara Karaka"
        assert all(k["planet"] != "RAHU" for k in ck)

    def test_missing_planet_does_not_create_dummy(self):
        from astro_backend_jyotish_jaimini import compute_chara_karakas
        # Only 6 planets provided
        positions = {
            "SUN": {"longitude": 28.0},
            "MOON": {"longitude": 24.0},
            "MARS": {"longitude": 20.0},
            "MERCURY": {"longitude": 16.0},
            "JUPITER": {"longitude": 12.0},
            "VENUS": {"longitude": 8.0},
        }
        res = compute_chara_karakas(positions, include_rahu=False)
        ck = res["chara_karakas"]
        assert len(ck) == 6
        assert all(k["planet"] in positions for k in ck)
        assert res["complete"] is False
        assert res["requested_system"] == "7-planet"
        assert res["system"] == "7-planet (incomplete)"
        assert res["missing_planets"] == ["SATURN"]

    def test_include_rahu_true_but_missing_rahu_completeness_flag(self):
        from astro_backend_jyotish_jaimini import compute_chara_karakas
        # 7 classical planets provided, but include_rahu=True
        positions = {
            "SUN": {"longitude": 28.0},
            "MOON": {"longitude": 24.0},
            "MARS": {"longitude": 20.0},
            "MERCURY": {"longitude": 16.0},
            "JUPITER": {"longitude": 12.0},
            "VENUS": {"longitude": 8.0},
            "SATURN": {"longitude": 4.0},
        }
        res = compute_chara_karakas(positions, include_rahu=True)
        assert res["complete"] is False
        assert res["requested_system"] == "8-planet"
        assert res["system"] == "8-planet (incomplete)"
        assert res["missing_planets"] == ["RAHU"]
        assert len(res["chara_karakas"]) == 7

    def test_tie_break_order_is_deterministic(self):
        from astro_backend_jyotish_jaimini import compute_chara_karakas
        positions = {
            "SUN": {"longitude": 15.0},
            "MOON": {"longitude": 15.0},
            "MARS": {"longitude": 15.0},
            "MERCURY": {"longitude": 15.0},
            "JUPITER": {"longitude": 15.0},
            "VENUS": {"longitude": 15.0},
            "SATURN": {"longitude": 15.0},
        }
        res1 = compute_chara_karakas(positions, include_rahu=False)
        res2 = compute_chara_karakas(positions, include_rahu=False)
        assert [k["planet"] for k in res1["chara_karakas"]] == [k["planet"] for k in res2["chara_karakas"]]


class TestYogakarakaMapping:
    """Test Yogakaraka planet detection across all 12 ascendants."""

    ALL_POSITIONS = {
        "SUN": {"longitude": 0.0},
        "MOON": {"longitude": 30.0},
        "MARS": {"longitude": 60.0},
        "MERCURY": {"longitude": 90.0},
        "JUPITER": {"longitude": 120.0},
        "VENUS": {"longitude": 150.0},
        "SATURN": {"longitude": 180.0},
    }

    @pytest.mark.parametrize(
        ("asc_rasi", "expected_planet"),
        [
            (0, None),       # Aries
            (1, "SATURN"),   # Taurus
            (2, None),       # Gemini
            (3, "MARS"),     # Cancer
            (4, "MARS"),     # Leo
            (5, None),       # Virgo
            (6, "SATURN"),   # Libra
            (7, None),       # Scorpio
            (8, None),       # Sagittarius
            (9, "VENUS"),    # Capricorn
            (10, "VENUS"),   # Aquarius
            (11, None),      # Pisces
        ],
    )
    def test_all_12_ascendants(self, asc_rasi, expected_planet):
        from astro_backend_jyotish_yoga import yoga_yogakaraka
        res = yoga_yogakaraka(self.ALL_POSITIONS, asc_rasi)
        if expected_planet is None:
            assert res is None, f"Ascendant {asc_rasi} should have no Yogakaraka, got {res}"
        else:
            assert res is not None, f"Ascendant {asc_rasi} should have Yogakaraka {expected_planet}"
            assert res["planets"] == [expected_planet]
            assert expected_planet in res["description"]

    def test_missing_planet_returns_none(self):
        from astro_backend_jyotish_yoga import yoga_yogakaraka
        # Taurus (1) requires SATURN; test with SATURN missing
        positions = {k: v for k, v in self.ALL_POSITIONS.items() if k != "SATURN"}
        assert yoga_yogakaraka(positions, 1) is None


class TestAshtottariDasaFocused:
    def test_ashtottari_uses_28_nakshatra_shifted_start(self):
        from astro_backend_jyotish import _ashtottari_start_index_and_portion
        start_idx, portion = _ashtottari_start_index_and_portion(66.6666666667)
        assert start_idx == 0
        assert 0.0 <= portion <= 1.0

    def test_ashtottari_abhijit_region_maps_into_saturn_group(self):
        from astro_backend_jyotish import _ashtottari_start_index_and_portion
        start_idx, portion = _ashtottari_start_index_and_portion(278.0)
        assert start_idx == 4
        assert 0.0 <= portion <= 1.0


# ─── 9. Ashtakavarga ────────────────────────────────────────────────

class TestAshtakavarga:
    def test_ashtakavarga_present(self, positions_with_reference):
        assert "ashtakavarga" in positions_with_reference

    def test_ashtakavarga_has_bav(self, positions_with_reference):
        av = positions_with_reference["ashtakavarga"]
        assert "bav" in av

    def test_ashtakavarga_has_sav(self, positions_with_reference):
        av = positions_with_reference["ashtakavarga"]
        assert "sav" in av

    def test_bav_has_all_planets(self, positions_with_reference):
        av = positions_with_reference["ashtakavarga"]
        bav = av["bav"]["planets"]
        for pid in ("SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN", "ASC"):
            assert pid in bav, f"missing {pid} in BAV"

    def test_bav_row_has_12_elements(self, positions_with_reference):
        av = positions_with_reference["ashtakavarga"]
        bav_sun = av["bav"]["planets"]["SUN"]
        assert len(bav_sun) == 12

    def test_sav_has_12_elements(self, positions_with_reference):
        av = positions_with_reference["ashtakavarga"]
        sav = av["sav"]["rekha"]
        assert len(sav) == 12

    def test_sav_values_reasonable(self, positions_with_reference):
        av = positions_with_reference["ashtakavarga"]
        sav = av["sav"]["rekha"]
        for v in sav:
            assert 0 <= v <= 56  # SAV max theoretical


class TestEkadhipatyaShodhana:
    """Test Ekadhipatya Shodhana rules across all 7 cases and matrix reduction."""

    @pytest.mark.parametrize(
        ("v1", "v2", "c1", "c2", "expected_v1", "expected_v2", "case_desc"),
        [
            # 1. One side is 0, other > 0: both unchanged
            (0, 4, 0, 0, 0, 4, "zero_and_positive"),
            (5, 0, 1, 0, 5, 0, "positive_and_zero"),
            # 2. Both sides have planets: both unchanged
            (4, 6, 1, 1, 4, 6, "both_occupied"),
            # 3. Both sides have NO planets, different values: both become min
            (4, 7, 0, 0, 4, 4, "both_empty_diff_values"),
            # 4. Both sides have NO planets, equal values: both become 0
            (5, 5, 0, 0, 0, 0, "both_empty_equal_values"),
            # 5. One side has planet, occupied side has smaller value: occupied unchanged, empty subtracts smaller
            (3, 7, 1, 0, 3, 4, "one_occupied_smaller_value"),
            (8, 3, 0, 1, 5, 3, "one_occupied_smaller_value_rev"),
            # 6. One side has planet, occupied side has larger value: occupied unchanged, empty becomes 0
            (7, 3, 1, 0, 7, 0, "one_occupied_larger_value"),
            (2, 6, 0, 1, 0, 6, "one_occupied_larger_value_rev"),
            # 7. One side has planet, both values equal: occupied unchanged, empty becomes 0
            (4, 4, 1, 0, 4, 0, "one_occupied_equal_values"),
            (5, 5, 0, 2, 0, 5, "one_occupied_equal_values_rev"),
        ],
    )
    def test_ekadhipatya_pair_reduction(self, v1, v2, c1, c2, expected_v1, expected_v2, case_desc):
        from astro_backend_jyotish_ashtakavarga import _reduce_ekadhipatya_pair
        out_v1, out_v2 = _reduce_ekadhipatya_pair(v1, v2, c1, c2)
        assert (out_v1, out_v2) == (expected_v1, expected_v2), (
            f"Case '{case_desc}' failed: in=({v1},{v2}) counts=({c1},{c2}) expected=({expected_v1},{expected_v2}) got=({out_v1},{out_v2})"
        )

    def test_full_ashtakavarga_matrix_reduction(self):
        from astro_backend_jyotish_ashtakavarga import compute_ashtakavarga
        positions = {
            "SUN": {"longitude": 10.0},      # Aries (0)
            "MOON": {"longitude": 40.0},     # Taurus (1)
            "MARS": {"longitude": 70.0},     # Gemini (2)
            "MERCURY": {"longitude": 100.0}, # Cancer (3)
            "JUPITER": {"longitude": 130.0}, # Leo (4)
            "VENUS": {"longitude": 160.0},   # Virgo (5)
            "SATURN": {"longitude": 190.0},  # Libra (6)
        }
        res = compute_ashtakavarga(positions, asc_longitude=15.0)
        # Verify trikona and rekha are separate from ekadhi
        for pid in ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN", "ASC"]:
            row = res["bav"]["rekha_by_planet"][pid]
            assert all(v >= 0 for v in row["ekadhi"])
            assert all(v >= 0 for v in row["trikona"])
            assert all(v >= 0 for v in row["rekha"])
            # ekadhi must not be identical copy of rekha
            assert row["ekadhi"] != row["rekha"] or all(v == 0 for v in row["rekha"])

        # SAV excludes the separate ASC BAV row in every reduction layer.
        calc_sarva_ekadhi = [0] * 12
        for pid in ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"]:
            for r in range(12):
                calc_sarva_ekadhi[r] += res["bav"]["rekha_by_planet"][pid]["ekadhi"][r]
        assert res["sav"]["ekadhi"] == calc_sarva_ekadhi


# ─── 10. Vimshottari Antardashas ────────────────────────────────────

class TestVimshottariAntardashas:
    def test_vimshottari_present(self, positions_with_reference):
        assert "vimshottari" in positions_with_reference

    def test_maha_dasas_has_antardashas(self, positions_with_reference):
        v = positions_with_reference["vimshottari"]
        for md in v["maha_dasas"]:
            assert "antardashas" in md, f"MD {md['lord']} missing antardashas"

    def test_each_md_has_9_antardashas(self, positions_with_reference):
        v = positions_with_reference["vimshottari"]
        for md in v["maha_dasas"]:
            assert len(md["antardashas"]) == 9, \
                f"MD {md['lord']} has {len(md['antardashas'])} antardashas, expected 9"

    def test_antardasha_starts_with_same_lord(self, positions_with_reference):
        v = positions_with_reference["vimshottari"]
        for md in v["maha_dasas"]:
            first_ad = md["antardashas"][0]
            assert first_ad["lord"] == md["lord"], \
                f"First AD of {md['lord']} is {first_ad['lord']}, expected same"

    def test_antardasha_has_dates(self, positions_with_reference):
        v = positions_with_reference["vimshottari"]
        md = v["maha_dasas"][0]
        ad = md["antardashas"][0]
        assert "start" in ad
        assert "end" in ad
        assert ad["start"] != ad["end"]

    def test_antardasha_duration_positive(self, positions_with_reference):
        v = positions_with_reference["vimshottari"]
        for md in v["maha_dasas"]:
            for ad in md["antardashas"]:
                assert ad["duration_years"] > 0, \
                    f"AD {ad['lord']} has non-positive duration"

    def test_first_md_lord_mars_for_sample(self, positions_with_reference):
        v = positions_with_reference["vimshottari"]
        assert v["maha_dasas"][0]["lord"] == "MARS"

    def test_current_mahadasa_found(self, positions_with_reference):
        v = positions_with_reference["vimshottari"]
        assert v["current_mahadasa"] is not None


# ─── 11. Shadbala meets_required ────────────────────────────────────

class TestShadbalaExtended:
    def test_shadbala_has_meets_required(self, positions_with_reference):
        assert "shadbala" in positions_with_reference
        sun_sb = positions_with_reference["shadbala"]["SUN"]
        assert "meets_required" in sun_sb

    def test_shadbala_has_required_rupas(self, positions_with_reference):
        sun_sb = positions_with_reference["shadbala"]["SUN"]
        assert "required_rupas" in sun_sb

    def test_shadbala_is_marked_incomplete(self, positions_with_reference):
        sun_sb = positions_with_reference["shadbala"]["SUN"]
        assert sun_sb["status"] == "incomplete"
        assert sun_sb["is_complete"] is False
        assert sun_sb["meets_required"] is None
        assert sun_sb["display_summary"] is None


class TestLinyi2004Reference:
    def test_meta_utc_and_local(self, linyi_reference_result):
        meta = linyi_reference_result["meta"]
        assert meta["birth_local"] == "2004-08-09 16:16"
        assert meta["birth_utc"] == "2004-08-09T08:16:00+00:00"
        assert meta["timezone_label"] == "Asia/Shanghai"
        assert meta["utc_offset_text"] == "UTC+8"

    def test_d1_anchor_positions(self, linyi_reference_result):
        asc = next(a for a in linyi_reference_result["rasi_chart"]["angles"] if a["id"] == "ASC")
        moon = linyi_reference_result["planets"]["MOON"]
        sun = linyi_reference_result["planets"]["SUN"]
        rahu = linyi_reference_result["planets"]["RAHU"]

        assert asc["sign"] == "射手"
        assert 248.5 <= asc["longitude"] <= 248.9

        assert moon["sign"] == "金牛"
        assert 38.8 <= moon["longitude"] <= 39.1
        assert moon["nakshatra"]["nakshatra"]["name_sa"] == "Krittika"
        assert moon["nakshatra"]["nakshatra"]["pada"] == 4

        assert sun["sign"] == "巨蟹"
        assert 113.0 <= sun["longitude"] <= 113.3

        assert rahu["sign"] == "白羊"
        assert 11.7 <= rahu["longitude"] <= 12.1

    def test_panchanga_reference_values(self, linyi_reference_result):
        p = linyi_reference_result["panchanga"]
        assert p["tithi"]["paksha"] == "Krishna"
        assert p["tithi"]["name_sa"] == "Navami"
        assert p["nakshatra"]["name_sa"] == "Krittika"
        assert p["yoga"]["name_sa"] == "Dhruva"
        assert p["karana"]["name_sa"] == "Gara"

    def test_vimshottari_reference_values(self, linyi_reference_result):
        v = linyi_reference_result["vimshottari"]
        assert v["birth_nakshatra_lord"] == "SUN"
        assert v["dasha_balance"]["lord"] == "SUN"
        assert v["dasha_balance"]["years"] == 0
        assert v["dasha_balance"]["months"] == 5
        assert 24 <= v["dasha_balance"]["days"] <= 28
        assert [md["lord"] for md in v["maha_dasas"][:4]] == ["SUN", "MOON", "MARS", "RAHU"]
        assert v["maha_dasas"][0]["start"][:7] == "1999-02"
        assert v["maha_dasas"][0]["end"][:7] == "2005-02"
        assert v["maha_dasas"][1]["end"][:7] == "2015-02"
        assert v["maha_dasas"][2]["end"][:7] == "2022-02"
        assert v["maha_dasas"][3]["end"][:7] == "2040-02"

    def test_moon_chart_degree_modulo_30(self, linyi_reference_result):
        asc = linyi_reference_result["moon_chart"]["planets"]["ASC"]
        assert asc["degree_text"].startswith("8°39'")

    def test_yoga_output_is_condition_only(self, linyi_reference_result):
        yogas = {y["name"]: y for y in linyi_reference_result["yogas"]}
        assert "RajaYogaGeneric" not in yogas
        assert yogas["Gaja Kesari"]["condition_only"] is True
        assert yogas["Gaja Kesari"]["needs_strength_check"] is True

    def test_missing_timezone_defaults_to_asia_shanghai(self):
        from astro_backend_jyotish import calculate_vedic
        request = {
            "birth": {
                "moment": {"year": 2004, "month": 8, "day": 9, "hour": 16, "minute": 16},
                "latitude": 35.0576, "longitude": 118.3346,
                "houseSystem": "whole_sign",
                "zodiac": "sidereal_lahiri",
            },
            "reference": {"year": 2004, "month": 8, "day": 9, "hour": 16, "minute": 16},
        }
        result = calculate_vedic(request, [])
        assert result["meta"]["timezone_label"] == "Asia/Shanghai"
        assert result["meta"]["birth_utc"] == "2004-08-09T08:16:00+00:00"


class TestNathonathaBala:
    """Test Nathonatha Bala LMT longitude calculation and diurnal/nocturnal mapping."""

    def test_longitude_affects_nathonatha_output(self):
        from astro_backend_jyotish_shadbala import calc_nathonatha_bala
        jd_ut = 2451545.0  # J2000.0 (2000-01-01 12:00:00 UT)
        # Lat 30, Long 0 vs Long 120E
        res_0 = calc_nathonatha_bala(jd_ut, 30.0, 0.0)
        res_120e = calc_nathonatha_bala(jd_ut, 30.0, 120.0)
        assert res_0["MOON"] != res_120e["MOON"]
        assert res_0["SUN"] != res_120e["SUN"]

    def test_120e_equals_ut_plus_8h_at_0_lon(self):
        from astro_backend_jyotish_shadbala import calc_nathonatha_bala
        jd_ut = 2451545.0
        # 120 deg East is +8 hours (+8/24 = +1/3 day)
        res_120e = calc_nathonatha_bala(jd_ut, 30.0, 120.0)
        res_ut_plus_8h = calc_nathonatha_bala(jd_ut + 8.0 / 24.0, 30.0, 0.0)
        assert res_120e["MOON"] == pytest.approx(res_ut_plus_8h["MOON"], abs=1e-6)
        assert res_120e["SUN"] == pytest.approx(res_ut_plus_8h["SUN"], abs=1e-6)

    def test_120w_equals_ut_minus_8h_at_0_lon(self):
        from astro_backend_jyotish_shadbala import calc_nathonatha_bala
        jd_ut = 2451545.0
        # 120 deg West is -8 hours (-8/24 = -1/3 day)
        res_120w = calc_nathonatha_bala(jd_ut, 30.0, -120.0)
        res_ut_minus_8h = calc_nathonatha_bala(jd_ut - 8.0 / 24.0, 30.0, 0.0)
        assert res_120w["MOON"] == pytest.approx(res_ut_minus_8h["MOON"], abs=1e-6)
        assert res_120w["SUN"] == pytest.approx(res_ut_minus_8h["SUN"], abs=1e-6)

    def test_local_midnight_extremes(self):
        from astro_backend_jyotish_shadbala import calc_nathonatha_bala
        # At lon 0, JD with fractional part .5 is 00:00:00 UT (midnight)
        jd_midnight = 2451544.5  # 2000-01-01 00:00:00 UT
        res = calc_nathonatha_bala(jd_midnight, 0.0, 0.0)
        # At midnight: Nata group (Moon/Mars/Saturn) -> 0.0; Unnata group (Sun/Jupiter/Venus) -> 60.0
        assert res["MOON"] == pytest.approx(0.0, abs=1e-6)
        assert res["MARS"] == pytest.approx(0.0, abs=1e-6)
        assert res["SATURN"] == pytest.approx(0.0, abs=1e-6)
        assert res["SUN"] == pytest.approx(60.0, abs=1e-6)
        assert res["JUPITER"] == pytest.approx(60.0, abs=1e-6)
        assert res["VENUS"] == pytest.approx(60.0, abs=1e-6)
        assert res["MERCURY"] == 60.0

    def test_local_noon_extremes(self):
        from astro_backend_jyotish_shadbala import calc_nathonatha_bala
        # At lon 0, integer JD is 12:00:00 UT (noon)
        jd_noon = 2451545.0  # 2000-01-01 12:00:00 UT
        res = calc_nathonatha_bala(jd_noon, 0.0, 0.0)
        # At noon: Nata group (Moon/Mars/Saturn) -> 60.0; Unnata group (Sun/Jupiter/Venus) -> 0.0
        assert res["MOON"] == pytest.approx(60.0, abs=1e-6)
        assert res["MARS"] == pytest.approx(60.0, abs=1e-6)
        assert res["SATURN"] == pytest.approx(60.0, abs=1e-6)
        assert res["SUN"] == pytest.approx(0.0, abs=1e-6)
        assert res["JUPITER"] == pytest.approx(0.0, abs=1e-6)
        assert res["VENUS"] == pytest.approx(0.0, abs=1e-6)
        assert res["MERCURY"] == 60.0

    def test_day_boundary_wrapping(self):
        from astro_backend_jyotish_shadbala import calc_nathonatha_bala
        # 23:59 LMT vs 00:01 LMT
        jd_before = 2451544.5 - (1.0 / 1440.0)  # 23:59 previous day
        jd_after = 2451544.5 + (1.0 / 1440.0)   # 00:01 current day
        res_b = calc_nathonatha_bala(jd_before, 0.0, 0.0)
        res_a = calc_nathonatha_bala(jd_after, 0.0, 0.0)
        # Both are 1 minute from midnight, so nata value should be nearly equal and close to 0
        assert res_b["MOON"] == pytest.approx(res_a["MOON"], abs=1e-4)
        assert res_b["MOON"] < 1.0


@pytest.mark.parametrize("asc", [0.0, 119.9, 359.9])
def test_sav_sums_seven_planets_and_retains_separate_asc_bav(asc):
    from astro_backend_jyotish_ashtakavarga import compute_ashtakavarga
    planet_ids = ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"]
    positions = {pid: {"longitude": (index * 47.3 + asc) % 360} for index, pid in enumerate(planet_ids)}
    result = compute_ashtakavarga(positions, asc)
    assert sum(result["sav"]["rekha"]) == 337
    assert sum(result["bav"]["rekha_by_planet"]["ASC"]["rekha"]) == 49
    for layer in ("rekha", "trikona", "ekadhi"):
        expected = [sum(result["bav"]["rekha_by_planet"][pid][layer][sign] for pid in planet_ids) for sign in range(12)]
        assert result["sav"][layer] == expected
