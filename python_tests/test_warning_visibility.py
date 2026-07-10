from __future__ import annotations

"""Warnings must surface instead of silent fallbacks.

Covers three previously-silent paths:
- unknown zodiac falling back to tropical (set_zodiac_mode)
- unknown house system / house calculation failure falling back to Whole Sign (build_houses)
- chart-shape and yoga detector crashes dropping results (find_patterns / detect_all_yogas)
"""

import pytest

from astro_backend_core import set_zodiac_mode
from astro_backend_ephemeris import build_houses

J2000 = 2451545.0


class TestZodiacFallbackWarning:
    def test_unknown_zodiac_warns_and_falls_back_to_tropical(self) -> None:
        warnings: list[str] = []
        sidereal = set_zodiac_mode("sidereal_lahri", warnings)  # typo of lahiri
        assert sidereal is False
        assert len(warnings) == 1
        assert "sidereal_lahri" in warnings[0]
        assert "tropical" in warnings[0]

    def test_unknown_zodiac_warning_deduped(self) -> None:
        warnings: list[str] = []
        set_zodiac_mode("vedic", warnings)
        set_zodiac_mode("vedic", warnings)
        assert len(warnings) == 1

    @pytest.mark.parametrize("zodiac", ["", "tropical", "sidereal_lahiri", "sidereal_citra", "lahiri"])
    def test_recognized_zodiac_no_warning(self, zodiac: str) -> None:
        warnings: list[str] = []
        set_zodiac_mode(zodiac, warnings)
        assert warnings == []

    def test_without_warnings_list_still_returns_false(self) -> None:
        assert set_zodiac_mode("sidereal_lahri") is False


class TestHouseSystemWarnings:
    def test_unknown_house_system_warns_and_uses_whole_sign(self) -> None:
        warnings: list[str] = []
        _, _, label = build_houses(J2000, 31.23, 121.47, "placidus_typo", False, warnings)
        assert label == "Whole Sign"
        assert len(warnings) == 1
        assert "placidus_typo" in warnings[0]

    def test_polar_placidus_fallback_warns_once(self) -> None:
        warnings: list[str] = []
        for _ in range(20):  # classical builds ~20 snapshots per request
            _, _, label = build_houses(J2000, 78.22, 15.65, "placidus", False, warnings)
        assert label == "Whole Sign"
        fallback = [w for w in warnings if "宫位计算失败" in w]
        assert len(fallback) == 1

    def test_normal_latitude_placidus_no_warning(self) -> None:
        warnings: list[str] = []
        _, _, label = build_houses(J2000, 31.23, 121.47, "placidus", False, warnings)
        assert label == "Placidus"
        assert warnings == []


class TestPanchangaSunriseSunsetWarnings:
    def test_sunrise_sunset_errors_surface_as_warnings(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        from astro_backend_jyotish import calculate_vedic
        import astro_backend_jyotish_panchanga as panchanga_mod

        def boom_solar_day(*args, **kwargs):
            return {
                "sunrise_local": None,
                "sunset_local": None,
                "sunrise_error": "rise boom",
                "sunset_error": "set boom",
            }

        # calculate_vedic does `from ... import calc_sunrise_sunset` each call,
        # so patch the module attribute that import will bind.
        monkeypatch.setattr(panchanga_mod, "calc_sunrise_sunset", boom_solar_day)

        request = {
            "mode": "vedic",
            "birth": {
                "moment": {
                    "year": 1990, "month": 4, "day": 20, "hour": 12, "minute": 0,
                    "timezone": "Asia/Shanghai",
                },
                "latitude": 39.93,
                "longitude": 116.41,
                "houseSystem": "whole_sign",
                "zodiac": "sidereal_lahiri",
            },
            "reference": {
                "year": 2026, "month": 1, "day": 1, "hour": 12, "minute": 0,
                "timezone": "Asia/Shanghai",
            },
            "full": False,
            "vargas": ["D1"],
            "dasas": ["vimshottari"],
            "shadbala": False,
            "yogas": False,
        }
        warnings: list[str] = []
        result = calculate_vedic(request, warnings)
        combined = list(result.get("warnings", [])) + warnings
        assert any("日出计算失败" in w and "rise boom" in w for w in combined)
        assert any("日落计算失败" in w and "set boom" in w for w in combined)


class TestAshtakavargaMissingASC:
    def test_missing_asc_records_note(self) -> None:
        from astro_backend_jyotish_ashtakavarga import compute_ashtakavarga

        positions = {
            "SUN": {"longitude": 10.0},
            "MOON": {"longitude": 40.0},
            "MARS": {"longitude": 70.0},
            "MERCURY": {"longitude": 100.0},
            "JUPITER": {"longitude": 130.0},
            "VENUS": {"longitude": 160.0},
            "SATURN": {"longitude": 190.0},
        }
        result = compute_ashtakavarga(positions, None)
        assert "notes" in result
        assert any("ASC 缺失" in n for n in result["notes"])
        assert "bav" in result and "sav" in result


class TestSolarArcInternalAspectWarning:
    def test_internal_aspect_failure_warns(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from astro_backend_solar_arc import calculate_solar_arc

        import astro_backend_solar_arc as sa_mod

        original = sa_mod.find_aspects
        calls = {"n": 0}

        def flaky_find_aspects(*args, **kwargs):
            calls["n"] += 1
            if calls["n"] >= 2:
                raise RuntimeError("internal aspects exploded")
            return original(*args, **kwargs)

        monkeypatch.setattr(sa_mod, "find_aspects", flaky_find_aspects)
        request = {
            "mode": "solar_arc",
            "birth": {
                "moment": {
                    "year": 1990, "month": 1, "day": 1, "hour": 12, "minute": 0,
                    "timezone": "Asia/Shanghai",
                },
                "latitude": 31.23,
                "longitude": 121.47,
                "houseSystem": "whole_sign",
                "zodiac": "tropical",
            },
            "reference": {
                "year": 2026, "month": 1, "day": 1, "hour": 12, "minute": 0,
                "timezone": "Asia/Shanghai",
            },
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "aspects": [{"id": "conjunction", "name": "合相", "angle": 0, "orb": 8}],
            "patterns_enabled": True,
        }
        warnings: list[str] = []
        result = calculate_solar_arc(request, warnings)
        assert any("内部相位" in w for w in warnings)
        assert result.get("section_errors", {}).get("solar_arc_internal")


class TestPatternShapeFailureWarning:
    def test_chart_shape_crash_appends_warning(self, monkeypatch: pytest.MonkeyPatch) -> None:
        import astro_backend_patterns as patterns_mod

        def boom(*args, **kwargs):
            raise RuntimeError("shape detector exploded")

        monkeypatch.setattr(patterns_mod, "find_chart_shapes", boom)
        warnings: list[str] = []
        lons = {"SUN": 0.0, "MOON": 90.0, "MARS": 180.0}
        result = patterns_mod.find_patterns(lons, [], warnings=warnings)
        assert isinstance(result, list)
        assert len(warnings) == 1
        assert "shape detector exploded" in warnings[0]

    def test_no_warnings_list_does_not_crash(self, monkeypatch: pytest.MonkeyPatch) -> None:
        import astro_backend_patterns as patterns_mod

        def boom(*args, **kwargs):
            raise RuntimeError("boom")

        monkeypatch.setattr(patterns_mod, "find_chart_shapes", boom)
        lons = {"SUN": 0.0, "MOON": 90.0}
        assert isinstance(patterns_mod.find_patterns(lons, []), list)


class TestYogaDetectorFailureWarning:
    def test_crashing_detector_appends_warning_and_keeps_others(
        self, monkeypatch: pytest.MonkeyPatch, sample_planet_positions
    ) -> None:
        import astro_backend_jyotish_yoga as yoga_mod

        def boom(*args, **kwargs):
            raise RuntimeError("detector exploded")

        monkeypatch.setattr(yoga_mod, "yoga_hans", boom)
        warnings: list[str] = []
        yogas = yoga_mod.detect_all_yogas(sample_planet_positions, 0, warnings=warnings)
        assert isinstance(yogas, list)
        assert len(warnings) == 1
        assert "boom" in warnings[0] or "detector exploded" in warnings[0]

    def test_no_warnings_list_does_not_crash(
        self, monkeypatch: pytest.MonkeyPatch, sample_planet_positions
    ) -> None:
        import astro_backend_jyotish_yoga as yoga_mod

        def boom(*args, **kwargs):
            raise RuntimeError("boom")

        monkeypatch.setattr(yoga_mod, "yoga_hans", boom)
        assert isinstance(yoga_mod.detect_all_yogas(sample_planet_positions, 0), list)
