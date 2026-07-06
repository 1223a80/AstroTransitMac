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
