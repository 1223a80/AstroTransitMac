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


class TestPerfectionTiming:
    def test_sun_moon_conjunction_and_opposition_are_found(self) -> None:
        from datetime import datetime

        from astro_backend_core import BODY_REGISTRY, angular_separation
        from astro_backend_ephemeris import body_longitude_at
        from astro_backend_horary import next_exact_for_pair

        start = datetime(2026, 6, 10, 0, 0)
        warnings: list[str] = []
        conjunction = next_exact_for_pair(start, "MOON", "SUN", 0.0, warnings, set(), max_days=30, step_hours=1)
        opposition = next_exact_for_pair(start, "MOON", "SUN", 180.0, warnings, set(), max_days=30, step_hours=1)

        assert conjunction is not None
        assert opposition is not None

        moon_at_conjunction = body_longitude_at(conjunction, BODY_REGISTRY["MOON"], warnings, set())
        sun_at_conjunction = body_longitude_at(conjunction, BODY_REGISTRY["SUN"], warnings, set())
        moon_at_opposition = body_longitude_at(opposition, BODY_REGISTRY["MOON"], warnings, set())
        sun_at_opposition = body_longitude_at(opposition, BODY_REGISTRY["SUN"], warnings, set())
        assert moon_at_conjunction is not None
        assert sun_at_conjunction is not None
        assert moon_at_opposition is not None
        assert sun_at_opposition is not None
        assert angular_separation(moon_at_conjunction[0], sun_at_conjunction[0]) < 0.01
        assert abs(angular_separation(moon_at_opposition[0], sun_at_opposition[0]) - 180.0) < 0.01

    def test_moon_near_future_trine_is_applying(self) -> None:
        from astro_backend_classical import classical_aspect_signature

        moon = {"id": "MOON", "name": "月亮", "longitude": 118.0, "speed": 13.0}
        target = {"id": "SUN", "name": "太阳", "longitude": 0.0, "speed": 0.0}
        signature = classical_aspect_signature(moon, target, 8.0)

        assert signature is not None
        assert signature[1] == "degree"
        assert signature[3] == "入相"

    def test_degree_based_key_aspects_accept_degree_geometry(self) -> None:
        from datetime import datetime

        from astro_backend_horary import degree_based_key_aspects

        planets = [
            {"id": "MARS", "name": "火星", "longitude": 0.0, "speed": 0.5, "house": 1},
            {"id": "VENUS", "name": "金星", "longitude": 118.0, "speed": 1.2, "house": 7},
        ]
        candidates = [{"planet_id": "MARS"}, {"planet_id": "VENUS"}]
        rows = degree_based_key_aspects(datetime(2026, 1, 1), candidates, planets, [], 8.0)

        assert len(rows) == 1
        assert rows[0]["aspect"] == "拱相"
        assert rows[0]["applying"] == "入相"

    def test_exact_time_rejects_sign_geometry(self) -> None:
        from datetime import datetime

        from astro_backend_horary import exact_time_for_signature

        left = {"id": "MARS", "name": "火星"}
        right = {"id": "VENUS", "name": "金星"}
        signature = ("整宫拱相", "sign", None, None, "sign-based aspect")

        perfects, exact_time = exact_time_for_signature(datetime(2026, 1, 1), left, right, signature, [])

        assert perfects is False
        assert exact_time == ""

    def test_exact_time_rejects_same_body_signature(self) -> None:
        from datetime import datetime

        from astro_backend_horary import exact_time_for_signature

        left = {"id": "MOON", "name": "月亮"}
        right = {"id": "MOON", "name": "月亮"}
        signature = ("合相", "degree", 0.0, "入相", "degree-based aspect")

        perfects, exact_time = exact_time_for_signature(datetime(2026, 1, 1), left, right, signature, [])

        assert perfects is False
        assert exact_time == ""

    def test_exact_time_rejects_perfection_after_sign_exit(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from datetime import datetime, timedelta

        import astro_backend_horary as horary

        chart_dt = datetime(2026, 1, 1)

        monkeypatch.setattr(
            horary,
            "next_exact_for_pair",
            lambda *args, **kwargs: chart_dt + timedelta(days=2),
        )
        monkeypatch.setattr(
            horary,
            "body_exits_sign_before",
            lambda _chart_dt, _exact_dt, body_id, _warnings, _warning_keys, sidereal=False: body_id == "MARS",
        )

        left = {"id": "MARS", "name": "火星"}
        right = {"id": "VENUS", "name": "金星"}
        signature = ("拱相", "degree", 1.0, "入相", "degree-based aspect")
        perfects, exact_time = horary.exact_time_for_signature(chart_dt, left, right, signature, [])

        assert perfects is False
        assert exact_time == ""

    def test_slow_jupiter_saturn_perfection_found_beyond_30_days(self) -> None:
        from datetime import datetime, timedelta

        from astro_backend_classical import classical_aspect_signature
        from astro_backend_core import BODY_REGISTRY
        from astro_backend_ephemeris import body_longitude_at, body_speed_at
        from astro_backend_horary import body_exits_sign_before, exact_datetime_for_signature

        # Start after the 2016/17 interruption; from here the slow application
        # is continuous for more than 30 days until exact perfection.
        chart_dt = datetime(2017, 7, 14, 0, 0)
        warnings: list[str] = []
        warning_keys: set[str] = set()
        planets = []
        for body_id, name in [("JUPITER", "木星"), ("SATURN", "土星")]:
            longitude = body_longitude_at(chart_dt, BODY_REGISTRY[body_id], warnings, warning_keys)
            speed = body_speed_at(chart_dt, BODY_REGISTRY[body_id], warnings, warning_keys)
            assert longitude is not None
            assert speed is not None
            planets.append({"id": body_id, "name": name, "longitude": longitude[0], "speed": speed[0]})

        signature = classical_aspect_signature(planets[0], planets[1], 8.0)
        assert signature is not None
        assert signature[0] == "六合"
        assert signature[1] == "degree"
        assert signature[3] == "入相"

        exact = exact_datetime_for_signature(chart_dt, planets[0], planets[1], signature, warnings)

        assert exact is not None
        assert exact > chart_dt + timedelta(days=30)
        assert exact.date() == datetime(2017, 8, 27).date()
        assert body_exits_sign_before(chart_dt, exact, "JUPITER", warnings, warning_keys) is False
        assert body_exits_sign_before(chart_dt, exact, "SATURN", warnings, warning_keys) is False

    def test_key_links_do_not_perfect_same_significator_roles(self) -> None:
        from datetime import datetime

        from astro_backend_horary import key_significator_links

        candidates = [
            {"role": "Querent", "planet_id": "MARS"},
            {"role": "Moon", "planet_id": "MOON"},
            {"role": "Matter / Outcome", "planet_id": "MOON"},
            {"role": "Natural significator", "planet_id": "MARS"},
        ]
        planets = [
            {"id": "MOON", "name": "月亮", "longitude": 0.0, "speed": 13.0, "house": 1},
            {"id": "MARS", "name": "火星", "longitude": 120.0, "speed": 0.5, "house": 7},
        ]

        rows = key_significator_links(
            datetime(2026, 1, 1),
            candidates,
            planets,
            [],
            {"before_sign_exit_aspects": []},
            [],
            8.0,
        )
        same_rows = [row for row in rows if row["perfection_reason"] == "same significator"]

        assert {row["id"] for row in same_rows} == {"MOON|MOON|link", "MARS|MARS|link"}
        assert all(row["perfects_before_sign_exit"] is False for row in same_rows)
        assert all(row["next_perfection"] == "" for row in same_rows)

    def test_moon_storyline_excludes_aspect_when_target_exits_first(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from datetime import datetime, timedelta

        import astro_backend_horary as horary

        chart_dt = datetime(2026, 1, 1, 0, 0)
        exact_dt = chart_dt + timedelta(minutes=20)
        planets = [
            {"id": "MOON", "name": "月亮", "longitude": 10.0, "speed": 13.0, "house": 1, "degree_text": "10°00'00\" 白羊"},
            {"id": "SUN", "name": "太阳", "longitude": 40.0, "speed": 1.0, "house": 2},
            {"id": "MERCURY", "name": "水星", "longitude": 10.0, "speed": 1.2, "house": 2},
            {"id": "VENUS", "name": "金星", "longitude": 80.0, "speed": 1.0, "house": 3},
            {"id": "MARS", "name": "火星", "longitude": 120.0, "speed": 0.5, "house": 4},
            {"id": "JUPITER", "name": "木星", "longitude": 180.0, "speed": 0.1, "house": 7},
            {"id": "SATURN", "name": "土星", "longitude": 240.0, "speed": 0.05, "house": 9},
        ]

        def fake_next_exact(
            query_dt: datetime,
            _left_id: str,
            right_id: str,
            angle: float,
            *_args: Any,
            **_kwargs: Any,
        ) -> datetime | None:
            if query_dt == chart_dt and right_id == "MERCURY" and angle == 0.0:
                return exact_dt
            return None

        monkeypatch.setattr(horary, "next_exact_for_pair", fake_next_exact)
        monkeypatch.setattr(horary, "previous_exact_for_pair", lambda *args, **kwargs: None)
        monkeypatch.setattr(
            horary,
            "next_sign_exit_for_body",
            lambda _chart_dt, body_id, *_args, **_kwargs: chart_dt + timedelta(hours=1) if body_id == "MOON" else None,
        )
        monkeypatch.setattr(
            horary,
            "body_exits_sign_before",
            lambda _chart_dt, _exact_dt, body_id, *_args, **_kwargs: body_id == "MERCURY",
        )

        result = horary.moon_storyline(chart_dt, planets, [])

        assert result["upcoming_aspects"][0]["target_id"] == "MERCURY"
        assert result["before_sign_exit_aspects"] == []
        assert result["voc"] is True

    def test_moon_storyline_sorts_same_minute_events_by_datetime(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from datetime import datetime, timedelta

        import astro_backend_horary as horary

        chart_dt = datetime(2026, 1, 1, 0, 0)
        planets = [
            {"id": "MOON", "name": "月亮", "longitude": 10.0, "speed": 13.0, "house": 1, "degree_text": "10°00'00\" 白羊"},
            {"id": "SUN", "name": "太阳", "longitude": 10.0, "speed": 1.0, "house": 2},
            {"id": "MERCURY", "name": "水星", "longitude": 10.0, "speed": 1.2, "house": 2},
            {"id": "VENUS", "name": "金星", "longitude": 80.0, "speed": 1.0, "house": 3},
            {"id": "MARS", "name": "火星", "longitude": 120.0, "speed": 0.5, "house": 4},
            {"id": "JUPITER", "name": "木星", "longitude": 180.0, "speed": 0.1, "house": 7},
            {"id": "SATURN", "name": "土星", "longitude": 240.0, "speed": 0.05, "house": 9},
        ]

        def fake_next_exact(
            query_dt: datetime,
            _left_id: str,
            right_id: str,
            angle: float,
            *_args: Any,
            **_kwargs: Any,
        ) -> datetime | None:
            if query_dt != chart_dt or angle != 0.0:
                return None
            if right_id == "SUN":
                return chart_dt + timedelta(seconds=50)
            if right_id == "MERCURY":
                return chart_dt + timedelta(seconds=10)
            return None

        monkeypatch.setattr(horary, "next_exact_for_pair", fake_next_exact)
        monkeypatch.setattr(horary, "previous_exact_for_pair", lambda *args, **kwargs: None)
        monkeypatch.setattr(
            horary,
            "next_sign_exit_for_body",
            lambda _chart_dt, body_id, *_args, **_kwargs: chart_dt + timedelta(hours=1) if body_id == "MOON" else None,
        )
        monkeypatch.setattr(horary, "body_exits_sign_before", lambda *args, **kwargs: False)

        result = horary.moon_storyline(chart_dt, planets, [])

        assert result["next_aspect"]["target_id"] == "MERCURY"
        assert result["before_sign_exit_aspects"][0]["target_id"] == "MERCURY"
        assert result["before_sign_exit_aspects"][1]["target_id"] == "SUN"

    def test_moon_storyline_keeps_full_before_sign_exit_for_key_links(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from datetime import datetime, timedelta

        import astro_backend_horary as horary

        chart_dt = datetime(2026, 1, 1, 0, 0)
        planets = [
            {"id": "MOON", "name": "月亮", "longitude": 10.0, "speed": 13.0, "house": 1, "degree_text": "10°00'00\" 白羊"},
            {"id": "SUN", "name": "太阳", "longitude": 40.0, "speed": 1.0, "house": 2},
            {"id": "MERCURY", "name": "水星", "longitude": 70.0, "speed": 1.2, "house": 3},
            {"id": "VENUS", "name": "金星", "longitude": 95.0, "speed": 1.0, "house": 4},
            {"id": "MARS", "name": "火星", "longitude": 130.0, "speed": 0.5, "house": 5},
            {"id": "JUPITER", "name": "木星", "longitude": 190.0, "speed": 0.1, "house": 7},
            {"id": "SATURN", "name": "土星", "longitude": 41.0, "speed": 0.05, "house": 9},
        ]
        exacts: dict[tuple[str, float], datetime] = {}
        minute = 1
        for angle in [0.0, 60.0, 90.0, 120.0, 180.0]:
            exacts[("SUN", angle)] = chart_dt + timedelta(minutes=minute)
            minute += 1
        for angle in [0.0, 60.0, 90.0]:
            exacts[("MERCURY", angle)] = chart_dt + timedelta(minutes=minute)
            minute += 1
        exacts[("SATURN", 0.0)] = chart_dt + timedelta(minutes=minute)

        def fake_next_exact(
            query_dt: datetime,
            _left_id: str,
            right_id: str,
            angle: float,
            *_args: Any,
            **_kwargs: Any,
        ) -> datetime | None:
            if query_dt != chart_dt:
                return None
            return exacts.get((right_id, angle))

        monkeypatch.setattr(horary, "next_exact_for_pair", fake_next_exact)
        monkeypatch.setattr(horary, "previous_exact_for_pair", lambda *args, **kwargs: None)
        monkeypatch.setattr(
            horary,
            "next_sign_exit_for_body",
            lambda _chart_dt, body_id, *_args, **_kwargs: chart_dt + timedelta(hours=1) if body_id == "MOON" else None,
        )
        monkeypatch.setattr(horary, "body_exits_sign_before", lambda *args, **kwargs: False)

        moon_story = horary.moon_storyline(chart_dt, planets, [])
        rows = horary.key_significator_links(
            chart_dt,
            [{"role": "Moon", "planet_id": "MOON"}, {"role": "Matter / Outcome", "planet_id": "SATURN"}],
            planets,
            [],
            moon_story,
            [],
            8.0,
        )

        assert len(moon_story["upcoming_aspects"]) == 8
        assert len(moon_story["before_sign_exit_aspects"]) == 9
        assert rows[0]["id"] == "MOON|SATURN|link"
        assert rows[0]["perfects_before_sign_exit"] is True
        assert rows[0]["next_perfection"] == "2026-01-01 00:09"

    def test_moon_key_link_uses_current_orb_for_future_perfection(self) -> None:
        from datetime import datetime

        from astro_backend_horary import key_significator_links

        candidates = [
            {"role": "Moon", "planet_id": "MOON"},
            {"role": "Matter / Outcome", "planet_id": "VENUS"},
        ]
        planets = [
            {"id": "MOON", "name": "月亮", "longitude": 118.0, "speed": 13.0, "house": 1},
            {"id": "VENUS", "name": "金星", "longitude": 0.0, "speed": 1.0, "house": 7},
        ]
        moon_story = {
            "before_sign_exit_aspects": [
                {
                    "target_id": "VENUS",
                    "aspect_id": "trine",
                    "aspect_name": "拱相",
                    "exact_local": "2026-01-01 04:00",
                }
            ]
        }

        rows = key_significator_links(datetime(2026, 1, 1), candidates, planets, [], moon_story, [], 8.0)
        row = rows[0]

        assert row["id"] == "MOON|VENUS|link"
        assert row["perfects_before_sign_exit"] is True
        assert row["orb"] == pytest.approx(2.0)


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

    def test_station_thresholds_are_planet_specific(self) -> None:
        from astro_backend_horary import planetary_speeds

        saturn_fast = planetary_speeds([{"id": "SATURN", "name": "土星", "speed": 0.04, "motion": "顺行"}])
        saturn_station = planetary_speeds([{"id": "SATURN", "name": "土星", "speed": 0.0005, "motion": "顺行"}])
        mercury_old_cutoff = planetary_speeds([{"id": "MERCURY", "name": "水星", "speed": 0.045, "motion": "顺行"}])

        assert saturn_fast[0]["station"] is False
        assert saturn_station[0]["station"] is True
        assert mercury_old_cutoff[0]["station"] is False


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

    def test_translation_rejects_translator_same_as_target(self) -> None:
        from astro_backend_horary import _detect_translation

        candidates = [
            {"role": "Querent", "planet_id": "VENUS"},
            {"role": "Moon", "planet_id": "MOON"},
            {"role": "Matter / Outcome", "planet_id": "MOON"},
        ]
        planets = [
            {"id": "MOON", "name": "月亮", "longitude": 122.0, "speed": 13.0, "house": 7},
            {"id": "VENUS", "name": "金星", "longitude": 0.0, "speed": 0.0, "house": 1},
        ]

        result = _detect_translation(candidates, [], {"voc": False}, planets)

        assert result["status"] == "not detected"

    def test_degree_signature_rejects_same_body(self) -> None:
        from astro_backend_horary import degree_signature

        moon_a = {"id": "MOON", "name": "月亮", "longitude": 10.0, "speed": 13.0}
        moon_b = {"id": "MOON", "name": "月亮", "longitude": 10.0, "speed": 13.0}

        assert degree_signature(moon_a, moon_b, 8.0) is None

    def test_collection_rejects_same_querent_and_matter(self) -> None:
        from astro_backend_horary import _detect_collection

        candidates = [
            {"role": "Querent", "planet_id": "MARS"},
            {"role": "Matter / Outcome", "planet_id": "MARS"},
        ]
        planets = [
            {"id": "MARS", "name": "火星", "longitude": 30.0, "speed": 0.5, "house": 1},
            {"id": "SATURN", "name": "土星", "longitude": 148.0, "speed": 0.03, "house": 10},
        ]

        result = _detect_collection(candidates, [], planets)

        assert result["status"] == "not detected"
        assert "同一征象星" in result["details"]

    def test_prohibition_rejects_same_querent_and_matter(self) -> None:
        from astro_backend_horary import _detect_prohibition

        candidates = [
            {"role": "Querent", "planet_id": "MARS"},
            {"role": "Matter / Outcome", "planet_id": "MARS"},
        ]
        planets = [{"id": "MARS", "name": "火星", "longitude": 30.0, "speed": 0.5, "house": 1}]

        result = _detect_prohibition(candidates, [], [], {"voc": False}, planets)

        assert result["status"] == "not detected"
        assert "同一征象星" in result["details"]

    def test_frustration_rejects_same_querent_and_matter(self) -> None:
        from astro_backend_horary import _detect_frustration

        candidates = [
            {"role": "Querent", "planet_id": "MARS"},
            {"role": "Matter / Outcome", "planet_id": "MARS"},
        ]
        planets = [{"id": "MARS", "name": "火星", "longitude": 30.0, "speed": 0.5, "house": 1}]

        result = _detect_frustration(candidates, [], [], {"voc": False}, planets)

        assert result["status"] == "not detected"
        assert "同一征象星" in result["details"]

    def test_frustration_detects_slow_significator_perfecting_with_third_first(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from datetime import datetime, timedelta

        import astro_backend_horary as horary

        chart_dt = datetime(2026, 1, 1)
        candidates = [
            {"role": "Querent", "planet_id": "MARS"},
            {"role": "Matter / Outcome", "planet_id": "SATURN"},
        ]
        planets = [
            {"id": "MARS", "name": "火星", "longitude": 118.0, "speed": 1.0, "house": 1},
            {"id": "SATURN", "name": "土星", "longitude": 0.0, "speed": 0.1, "house": 7},
            {"id": "JUPITER", "name": "木星", "longitude": 1.0, "speed": 0.05, "house": 8},
        ]

        def fake_exact(
            _chart_dt: datetime,
            left_row: dict[str, Any],
            right_row: dict[str, Any],
            _signature: tuple[str, str, float | None, str | None, str | None] | None,
            _warnings: list[str],
            sidereal: bool = False,
        ) -> datetime | None:
            pair = {left_row["id"], right_row["id"]}
            if pair == {"MARS", "SATURN"}:
                return chart_dt + timedelta(days=10)
            if pair == {"SATURN", "JUPITER"}:
                return chart_dt + timedelta(days=5)
            return None

        monkeypatch.setattr(horary, "exact_datetime_for_signature", fake_exact)

        result = horary._detect_frustration(candidates, [], [], {"voc": False}, planets, chart_dt, [], 8.0)

        assert result["status"] == "detected"
        assert result["frustrating_planet"] == "木星"
        assert result["frustrated_planet"] == "火星"

    def test_collection_does_not_use_fixed_sign_or_angle_as_collector(self) -> None:
        from astro_backend_horary import _detect_collection

        candidates = [
            {"role": "Querent", "planet_id": "MARS"},
            {"role": "Matter / Outcome", "planet_id": "VENUS"},
        ]
        planets = [
            {"id": "MARS", "name": "火星", "longitude": 30.0, "speed": 0.5, "house": 1},
            {"id": "VENUS", "name": "金星", "longitude": 90.0, "speed": 1.0, "house": 7},
        ]
        key_aspects = [{"body_a": "火星", "body_b": "金星", "applying": "入相"}]

        result = _detect_collection(candidates, key_aspects, planets)

        assert result["status"] == "not detected"

    def test_prohibition_requires_third_perfection_before_main(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from datetime import datetime, timedelta

        import astro_backend_horary as horary

        chart_dt = datetime(2026, 1, 1)
        candidates = [
            {"role": "Querent", "planet_id": "MARS"},
            {"role": "Matter / Outcome", "planet_id": "VENUS"},
        ]
        planets = [
            {"id": "MARS", "name": "火星", "longitude": 118.0, "speed": 13.0, "house": 1},
            {"id": "VENUS", "name": "金星", "longitude": 0.0, "speed": 0.0, "house": 7},
            {"id": "MERCURY", "name": "水星", "longitude": 58.0, "speed": 13.0, "house": 3},
        ]

        def fake_exact(
            _chart_dt: datetime,
            left_row: dict[str, Any],
            right_row: dict[str, Any],
            _signature: tuple[str, str, float | None, str | None, str | None] | None,
            _warnings: list[str],
            sidereal: bool = False,
        ) -> datetime:
            pair = {left_row["id"], right_row["id"]}
            if pair == {"MARS", "VENUS"}:
                return chart_dt + timedelta(days=2)
            return chart_dt + timedelta(days=3)

        monkeypatch.setattr(horary, "exact_datetime_for_signature", fake_exact)

        result = horary._detect_prohibition(
            candidates,
            [],
            [],
            {"voc": False},
            planets,
            chart_dt,
            [],
            8.0,
        )

        assert result["status"] == "not detected"

    def test_frustration_does_not_report_plain_separating_aspect(self) -> None:
        from astro_backend_horary import _detect_frustration

        candidates = [
            {"role": "Querent", "planet_id": "MARS"},
            {"role": "Matter / Outcome", "planet_id": "VENUS"},
        ]
        planets = [
            {"id": "MARS", "name": "火星", "longitude": 122.0, "speed": 0.5},
            {"id": "VENUS", "name": "金星", "longitude": 0.0, "speed": 0.0},
        ]
        key_links = [
            {
                "pair": "Querent ruler – Matter ruler",
                "applying": "离相",
                "perfection_reason": "separating",
            }
        ]

        result = _detect_frustration(candidates, key_links, [], {"voc": False}, planets)

        assert result["status"] == "not detected"


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
