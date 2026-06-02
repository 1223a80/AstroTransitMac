from __future__ import annotations

from typing import Any

import pytest

pytestmark = [pytest.mark.requires_ephemeris]


class TestAngularDelta:
    def test_same(self) -> None:
        from astro_backend_horary import angular_delta
        assert angular_delta(10.0, 10.0) == 0.0

    def test_positive_offset(self) -> None:
        from astro_backend_horary import angular_delta
        assert angular_delta(20.0, 50.0) == 30.0

    def test_wrap_around(self) -> None:
        from astro_backend_horary import angular_delta
        assert angular_delta(350.0, 10.0) == 20.0

    def test_exactly_180(self) -> None:
        from astro_backend_horary import angular_delta
        assert angular_delta(0.0, 180.0) == 180.0


class TestQuestionPatterns:
    def test_relationships_mapped_to_7th(self) -> None:
        from astro_backend_horary import QUESTION_PATTERNS
        for keywords, config in QUESTION_PATTERNS:
            if any(k in ("恋爱", "关系", "感情", "婚", "对象") for k in keywords):
                assert config["house"] == 7
                return
        assert False, "no relationship pattern found"

    def test_work_mapped_to_10th(self) -> None:
        from astro_backend_horary import QUESTION_PATTERNS
        for keywords, config in QUESTION_PATTERNS:
            if any(k in ("工作", "事业", "升职", "老板", "职业") for k in keywords):
                assert config["house"] == 10
                return
        assert False, "no work pattern found"

    def test_all_patterns_have_valid_house(self) -> None:
        from astro_backend_horary import QUESTION_PATTERNS
        for keywords, config in QUESTION_PATTERNS:
            assert 1 <= config["house"] <= 12
            assert config["natural"] in ("VENUS", "SUN", "JUPITER", "MOON", "MERCURY", "SATURN")

    def test_infer_matter_relationship(self) -> None:
        from astro_backend_horary import infer_matter_role
        house_rulers = [{"house": h, "sign": "白羊", "ruler": "MARS"} for h in range(1, 13)]
        house, ruler = infer_matter_role("感情问题", house_rulers)
        assert house == 7

    def test_infer_matter_finance(self) -> None:
        from astro_backend_horary import infer_matter_role
        house_rulers = [{"house": h, "sign": "金牛", "ruler": "VENUS"} for h in range(1, 13)]
        house, ruler = infer_matter_role("最近投资怎么样", house_rulers)
        assert house == 2

    def test_infer_matter_no_match(self) -> None:
        from astro_backend_horary import infer_matter_role
        house_rulers = [{"house": h, "sign": "白羊", "ruler": "MARS"} for h in range(1, 13)]
        house, ruler = infer_matter_role("xxx", house_rulers)
        assert house == 0
        assert ruler == ""

    def test_infer_natural_significator(self) -> None:
        from astro_backend_horary import infer_natural_significator
        assert infer_natural_significator("感情") == "VENUS"
        assert infer_natural_significator("工作") == "SUN"
        assert infer_natural_significator("健康") == "SATURN"
        assert infer_natural_significator("no match") == ""


class TestHouseRulers:
    def test_basic_construction(self) -> None:
        from astro_backend_horary import house_rulers
        houses = [
            {"house": 1, "sign": "白羊", "ruler": "MARS", "longitude": 0.0},
            {"house": 2, "sign": "金牛", "ruler": "VENUS", "longitude": 30.0},
        ]
        result = house_rulers(houses)
        assert len(result) == 2
        assert result[0]["house"] == 1
        assert result[1]["ruler"] == "VENUS"


class TestRadicality:
    def test_asc_early_degree(self) -> None:
        from astro_backend_horary import radicality_flags
        snapshot = {
            "angles": [{"id": "ASC", "longitude": 1.0}],
            "planets": [{"id": "SATURN", "house": 5}, {"id": "MOON", "house": 3}],
        }
        moon_story = {"voc": False}
        flags = radicality_flags(snapshot, moon_story)
        assert any(f["id"] == "asc_early" for f in flags)

    def test_asc_late_degree(self) -> None:
        from astro_backend_horary import radicality_flags
        snapshot = {
            "angles": [{"id": "ASC", "longitude": 359.0}],
            "planets": [{"id": "SATURN", "house": 5}, {"id": "MOON", "house": 3}],
        }
        moon_story = {"voc": False}
        flags = radicality_flags(snapshot, moon_story)
        assert any(f["id"] == "asc_late" for f in flags)

    def test_saturn_in_7(self) -> None:
        from astro_backend_horary import radicality_flags
        snapshot = {
            "angles": [{"id": "ASC", "longitude": 100.0}],
            "planets": [
                {"id": "SATURN", "house": 7},
                {"id": "MOON", "house": 3},
            ],
        }
        moon_story = {"voc": False}
        flags = radicality_flags(snapshot, moon_story)
        assert any(f["id"] == "saturn_in_7" for f in flags)

    def test_moon_voc(self) -> None:
        from astro_backend_horary import radicality_flags
        snapshot = {
            "angles": [{"id": "ASC", "longitude": 100.0}],
            "planets": [{"id": "SATURN", "house": 5}, {"id": "MOON", "house": 3}],
        }
        moon_story = {"voc": True}
        flags = radicality_flags(snapshot, moon_story)
        assert any(f["id"] == "moon_voc" for f in flags)

    def test_no_flags(self) -> None:
        from astro_backend_horary import radicality_flags
        snapshot = {
            "angles": [{"id": "ASC", "longitude": 100.0}],
            "planets": [{"id": "SATURN", "house": 5}, {"id": "MOON", "house": 3}],
        }
        moon_story = {"voc": False}
        flags = radicality_flags(snapshot, moon_story)
        assert len(flags) == 0


class TestSignificatorCandidates:
    def test_has_querent_and_moon(self, sample_snapshot: dict[str, Any]) -> None:
        from astro_backend_horary import significator_candidates
        candidates = significator_candidates("感情", sample_snapshot)
        roles = {c["role"] for c in candidates}
        assert "Querent" in roles
        assert "Moon" in roles
        assert "Matter / Outcome" in roles

    def test_matter_unknown_with_no_match(self, sample_snapshot: dict[str, Any]) -> None:
        from astro_backend_horary import significator_candidates
        candidates = significator_candidates("xxx", sample_snapshot)
        matter = next(c for c in candidates if c["role"] == "Matter / Outcome")
        assert matter["planet"] == "unknown"

    def test_natural_not_present_with_no_match(self, sample_snapshot: dict[str, Any]) -> None:
        from astro_backend_horary import significator_candidates
        candidates = significator_candidates("xxx", sample_snapshot)
        natural = next(c for c in candidates if c["role"] == "Natural significator")
        assert natural["planet"] == "unknown"

    def test_all_have_required_fields(self, sample_snapshot: dict[str, Any]) -> None:
        from astro_backend_horary import significator_candidates
        candidates = significator_candidates("感情", sample_snapshot)
        for c in candidates:
            assert "id" in c
            assert "role" in c
            assert "planet" in c
            assert "source" in c


class TestPlanetarySpeeds:
    def test_station_detected_when_slow(self) -> None:
        from astro_backend_horary import planetary_speeds
        planets = [{"id": "MARS", "name": "火星", "speed": 0.01, "motion": "顺行"}]
        rows = planetary_speeds(planets)
        assert rows[0]["station"] is True

    def test_no_station_when_fast(self) -> None:
        from astro_backend_horary import planetary_speeds
        planets = [{"id": "MARS", "name": "火星", "speed": 0.5, "motion": "顺行"}]
        rows = planetary_speeds(planets)
        assert rows[0]["station"] is False

    def test_sun_moon_never_station(self) -> None:
        from astro_backend_horary import planetary_speeds
        planets = [
            {"id": "SUN", "name": "太阳", "speed": 0.001, "motion": "顺行"},
            {"id": "MOON", "name": "月亮", "speed": 0.001, "motion": "顺行"},
        ]
        rows = planetary_speeds(planets)
        assert rows[0]["station"] is False
        assert rows[1]["station"] is False


class TestSolarCondition:
    def test_sun_itself_excluded(self, sample_planet_rows: list[dict[str, Any]]) -> None:
        from astro_backend_horary import solar_condition
        rows = solar_condition(sample_planet_rows)
        planets = [r["planet"] for r in rows]
        assert "太阳" not in planets

    def test_distance_computed(self, sample_planet_rows: list[dict[str, Any]]) -> None:
        from astro_backend_horary import solar_condition
        rows = solar_condition(sample_planet_rows)
        for r in rows:
            assert r["distance_from_sun"] >= 0


class TestNegativeReceptions:
    def test_detriment_detected(self) -> None:
        from astro_backend_horary import negative_receptions
        planets = [
            {"id": "MARS", "name": "火星", "longitude": 0.0, "speed": 0.5, "motion": "顺行", "score": 0,
             "solar_phase": "可见", "bonification": [], "maltreatment": [
            ]},
            {"id": "VENUS", "name": "金星", "longitude": 15.0, "speed": 0.5, "motion": "顺行", "score": 5,
             "solar_phase": "可见", "bonification": [], "maltreatment": []},
            {"id": "SATURN", "name": "土星", "longitude": 210.0, "speed": 0.05, "motion": "逆行", "score": 0,
             "solar_phase": "可见", "bonification": [], "maltreatment": []},
        ]
        # MARS in Aries (0°), VENUS in Aries (15°)
        # MARS rules Aries (sign 0), VENUS rules Taurus (sign 1)
        # VENUS in Aries: detriment for Venus (Aries is opposite Libra which Venus rules)
        # Actually Aries is opposite Libra. Venus rules Libra. So yes, Venus in Aries = detriment.
        # Saturn in Scorpio (210°). Mars rules Scorpio. Is Saturn opposite Mars? No.
        receptions = []
        rows = negative_receptions(planets, receptions)
        assert any(r["debility"] == "detriment" for r in rows)

    def test_empty_with_no_debility(self) -> None:
        from astro_backend_horary import negative_receptions
        planets = [
            {"id": "SUN", "name": "太阳", "longitude": 0.0, "speed": 0.955, "motion": "顺行", "score": 0,
             "solar_phase": "-", "bonification": [], "maltreatment": []},
        ]
        rows = negative_receptions(planets, [])
        assert len(rows) == 0


class TestAdvancedDetection:
    def test_translation_missing_planets(self) -> None:
        from astro_backend_horary import _detect_translation
        result = _detect_translation([], [], {"voc": False}, [])
        assert result["type"] == "Translation of Light"
        assert result["status"] == "not detected"

    def test_collection_missing_planets(self) -> None:
        from astro_backend_horary import _detect_collection
        result = _detect_collection([], [], [])
        assert result["type"] == "Collection of Light"
        assert result["status"] == "not detected"

    def test_prohibition_missing_planets(self) -> None:
        from astro_backend_horary import _detect_prohibition
        result = _detect_prohibition([], [], [], {"voc": False}, [])
        assert result["type"] == "Prohibition"
        assert result["status"] == "not evaluated"

    def test_frustration_missing_planets(self) -> None:
        from astro_backend_horary import _detect_frustration
        result = _detect_frustration([], [], [], {"voc": False}, [])
        assert result["type"] == "Frustration"
        assert result["status"] == "not evaluated"


class TestMakeAspectEvent:
    def test_id_construction(self) -> None:
        from astro_backend_horary import make_aspect_event
        from datetime import datetime
        source = {"id": "MOON", "name": "月亮", "longitude": 30.0, "house": 4}
        target = {"id": "VENUS", "name": "金星", "longitude": 70.0, "house": 6}
        dt = datetime(2026, 5, 5, 12, 0)
        event = make_aspect_event(dt, source, target, "square")
        assert event["target_id"] == "VENUS"
        assert event["aspect_id"] == "square"
        assert "MOON|square|VENUS|" in event["id"]


class TestMachineSummary:
    def test_uses_moon_story(self, sample_snapshot: dict[str, Any]) -> None:
        from astro_backend_horary import machine_summary
        moon_story = {
            "voc": False,
            "sign_exit_local": "2026-05-06 12:00",
            "next_aspect": None,
        }
        summary = machine_summary(sample_snapshot, moon_story, [])
        assert len(summary) > 0
        assert any("Moon VOC" not in s for s in summary)
