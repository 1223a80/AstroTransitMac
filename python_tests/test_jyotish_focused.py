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

    def test_arudha_opposite_exception_shifts_ten_signs(self):
        from astro_backend_jyotish_arudha import calc_arudha_pada
        positions = {"MARS": {"longitude": 90.0}}
        assert calc_arudha_pada(0, 0, positions) == 4


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

    def test_rahu_longitude_is_ranked_retrograde(self):
        from astro_backend_jyotish_jaimini import compute_chara_karakas
        positions = {
            "SUN": {"longitude": 5.0},
            "MOON": {"longitude": 10.0},
            "MARS": {"longitude": 15.0},
            "MERCURY": {"longitude": 20.0},
            "JUPITER": {"longitude": 25.0},
            "VENUS": {"longitude": 1.0},
            "SATURN": {"longitude": 2.0},
            "RAHU": {"longitude": 3.0},
        }
        result = compute_chara_karakas(positions)
        assert result["chara_karakas"][0]["planet"] == "RAHU"
        assert result["chara_karakas"][0]["effective_longitude"] == 27.0


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
