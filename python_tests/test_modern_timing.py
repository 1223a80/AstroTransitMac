from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from astro_backend_api import validate_required_fields
from astro_backend_core import angular_separation, signed_orb
from astro_backend_modern_timing import (
    TimingContext,
    _find_roots,
    _lifecycle_bounds,
    calculate_modern_timing,
    estimate_modern_timing_work_units,
)
from astro_backend_progressions import calculate_progressions
from astro_backend_scan import exact_longitudes_for_aspect, reject_oversized_scan
from astro_backend_solar_arc import calculate_solar_arc


ROOT = Path(__file__).resolve().parents[1]


def _sample_request() -> dict:
    return json.loads((ROOT / "Examples" / "sample-modern-timing-request.json").read_text())


@pytest.fixture(scope="module")
def sample_result() -> dict:
    request = _sample_request()
    error = validate_required_fields(request)
    assert error is None
    return calculate_modern_timing(request, [])


class TestSyntheticRootEngine:
    def test_linear_exact_and_lifecycle_roots(self) -> None:
        start = datetime(2030, 1, 1, tzinfo=timezone.utc)
        end = start + timedelta(hours=10)

        def exact_value(value: datetime) -> float:
            return (value - start).total_seconds() / 3600.0 - 5.0

        roots = _find_roots(exact_value, start, end, timedelta(hours=1))
        assert len(roots) == 1
        exact, residual = roots[0]
        assert exact == start + timedelta(hours=5)
        assert residual <= 1e-10

        def boundary(value: datetime) -> float:
            return abs(exact_value(value)) - 2.0

        entering, leaving, clipped_start, clipped_end = _lifecycle_bounds(
            boundary,
            exact,
            start,
            end,
            timedelta(hours=1),
            2.0,
        )
        assert entering == start + timedelta(hours=3)
        assert leaving == start + timedelta(hours=7)
        assert clipped_start is False
        assert clipped_end is False

    def test_window_clipping_uses_null_not_boundary_time(self) -> None:
        start = datetime(2030, 1, 1, tzinfo=timezone.utc)
        exact = start + timedelta(hours=1)
        end = start + timedelta(hours=5)

        def boundary(value: datetime) -> float:
            distance = abs((value - exact).total_seconds() / 3600.0)
            return distance - 2.0

        entering, leaving, clipped_start, clipped_end = _lifecycle_bounds(
            boundary,
            exact,
            start,
            end,
            timedelta(minutes=30),
            2.0,
        )
        assert entering is None
        assert clipped_start is True
        assert leaving == exact + timedelta(hours=2)
        assert clipped_end is False

    def test_three_retrograde_passes_are_not_deduped(self) -> None:
        start = datetime(2030, 1, 1, tzinfo=timezone.utc)
        end = start + timedelta(hours=10)

        def three_passes(value: datetime) -> float:
            hour = (value - start).total_seconds() / 3600.0
            return ((hour - 2.0) * (hour - 5.0) * (hour - 8.0)) / 100.0

        roots = _find_roots(three_passes, start, end, timedelta(minutes=30))
        assert [round((root[0] - start).total_seconds() / 3600.0, 6) for root in roots] == [2.0, 5.0, 8.0]

    def test_zero_degree_wrap_crossing_is_refined(self) -> None:
        start = datetime(2030, 1, 1, tzinfo=timezone.utc)
        end = start + timedelta(hours=2)

        def wrapped_branch(value: datetime) -> float:
            hour = (value - start).total_seconds() / 3600.0
            return signed_orb((359.0 + hour) % 360.0, 0.0)

        roots = _find_roots(wrapped_branch, start, end, timedelta(hours=2))
        assert len(roots) == 1
        assert roots[0][0] == start + timedelta(hours=1)

    def test_root_on_step_boundary_is_not_duplicated(self) -> None:
        start = datetime(2030, 1, 1, tzinfo=timezone.utc)
        end = start + timedelta(hours=4)

        def station_like_speed(value: datetime) -> float:
            return (value - start).total_seconds() / 3600.0 - 2.0

        roots = _find_roots(station_like_speed, start, end, timedelta(hours=1))
        assert [root[0] for root in roots] == [start + timedelta(hours=2)]

    def test_multiple_exacts_share_one_continuous_lifecycle(self) -> None:
        start = datetime(2030, 1, 1, tzinfo=timezone.utc)
        end = start + timedelta(hours=12)

        def boundary(value: datetime) -> float:
            hour = (value - start).total_seconds() / 3600.0
            return abs(hour - 6.0) - 5.0

        exacts = [start + timedelta(hours=4), start + timedelta(hours=8)]
        lifecycles = [
            _lifecycle_bounds(boundary, exact, start, end, timedelta(hours=1), 1.0)
            for exact in exacts
        ]
        assert lifecycles == [
            (start + timedelta(hours=1), start + timedelta(hours=11), False, False),
            (start + timedelta(hours=1), start + timedelta(hours=11), False, False),
        ]

    @pytest.mark.parametrize(
        ("angle", "expected"),
        [
            (0.0, [350.0]),
            (180.0, [170.0]),
            (60.0, [50.0, 290.0]),
            (90.0, [80.0, 260.0]),
            (120.0, [110.0, 230.0]),
            (150.0, [140.0, 200.0]),
        ],
    )
    def test_aspect_branch_values(self, angle: float, expected: list[float]) -> None:
        assert exact_longitudes_for_aspect(350.0, angle) == expected


class TestEstimator:
    def test_formula_matches_documented_components(self) -> None:
        start = datetime(2026, 1, 1, tzinfo=timezone.utc)
        end = start + timedelta(days=14)
        techniques = [
            {
                "id": "transit",
                "moving_body_ids": ["MOON"],
                "event_types": ["aspect", "ingress", "station"],
                "aspects": [
                    {"id": "conjunction", "name": "合相", "angle": 0.0, "orb": 1.0},
                    {"id": "square", "name": "刑相", "angle": 90.0, "orb": 1.0},
                ],
            },
            {
                "id": "secondary_progression",
                "moving_body_ids": ["SUN", "MOON"],
                "event_types": ["aspect", "moon_ingress", "lunation"],
                "aspects": [{"id": "opposition", "name": "冲相", "angle": 180.0, "orb": 1.0}],
            },
        ]
        # Moon transit: 337 steps. Aspect branches 1+2 over 3 targets,
        # then one ingress and one station pass. Progression: 3 steps per
        # point, plus Moon ingress and one lunation pass.
        expected = (337 * 3 * 3) + 337 + 337 + (6 * 3 * 1) + 3 + 3
        assert estimate_modern_timing_work_units(start, end, techniques, 3) == expected

    def test_shared_confirmation_and_hard_limits_remain_authoritative(self) -> None:
        with pytest.raises(ValueError, match="确认"):
            reject_oversized_scan(2_500_001)
        with pytest.raises(ValueError, match="窗口过大"):
            reject_oversized_scan(5_000_001, confirmed=True)


class TestValidation:
    def test_accepts_exact_sample(self) -> None:
        assert validate_required_fields(_sample_request()) is None

    @pytest.mark.parametrize("field", ["hour", "minute", "timezone"])
    def test_rejects_inexact_birth_time(self, field: str) -> None:
        request = _sample_request()
        request["birth"]["moment"].pop(field)
        error = validate_required_fields(request)
        assert error is not None
        assert f"birth.moment.{field}" in error.get("missing", [])

    def test_rejects_invalid_display_timezone_and_empty_aspect_table(self) -> None:
        request = _sample_request()
        request["display_timezone"] = "Not/AZone"
        request["techniques"][0]["aspects"] = []
        error = validate_required_fields(request)
        assert error is not None
        text = ";".join(error.get("invalid", []))
        assert "display_timezone" in text
        assert "aspects must be non-empty" in text

    def test_rejects_duplicate_or_unsupported_techniques(self) -> None:
        request = _sample_request()
        request["techniques"][1]["id"] = "transit"
        request["techniques"][2]["id"] = "invented"
        error = validate_required_fields(request)
        assert error is not None
        text = ";".join(error.get("invalid", []))
        assert "duplicated" in text
        assert "unsupported" in text

    @pytest.mark.parametrize(
        "mutate",
        [
            lambda request: request.update({"birth": []}),
            lambda request: request["birth"]["moment"].update({"month": 13}),
            lambda request: request["techniques"][0].update({"id": []}),
            lambda request: request["techniques"][0].update({"event_types": [["aspect"]]}),
            lambda request: request["techniques"][2].update({"moving_body_ids": [{"id": "ASC"}]}),
        ],
    )
    def test_malformed_payloads_return_validation_errors_instead_of_raising(self, mutate) -> None:
        request = _sample_request()
        mutate(request)
        error = validate_required_fields(request)
        assert error is not None
        assert error.get("invalid") or error.get("missing")


class TestRealTimeline:
    def test_one_year_sample_covers_all_three_techniques(self, sample_result: dict) -> None:
        assert sample_result["meta"]["schema_version"] == 1
        assert sample_result["meta"]["target_count"] == 7
        assert sample_result["meta"]["technique_configs"] == _sample_request()["techniques"]
        assert sample_result["section_errors"] is None
        assert {event["source_type"] for event in sample_result["events"]} == {
            "transit", "secondary_progression", "solar_arc"
        }

    def test_events_are_sorted_stable_and_finite(self, sample_result: dict) -> None:
        events = sample_result["events"]
        assert events == sorted(events, key=lambda row: (row["exact_utc"], row["id"]))
        assert len({event["id"] for event in events}) == len(events)
        for event in events:
            assert event["exact_utc"].endswith("Z")
            assert "+08:00" in event["exact_local"]
            assert event["exact_orb"] is None or event["exact_orb"] <= 1e-5
            assert event["moving_longitude"] == pytest.approx(event["moving_longitude"])

    def test_each_exact_recomputes_with_its_declared_adapter(self, sample_result: dict) -> None:
        request = _sample_request()
        context = TimingContext(request, [], sidereal=False)
        for event in sample_result["events"]:
            exact = datetime.fromisoformat(event["exact_utc"].replace("Z", "+00:00"))
            recomputed = context.evaluator(event["source_type"], event["moving_point_id"])(exact)
            assert recomputed is not None
            assert recomputed.longitude == pytest.approx(event["moving_longitude"], abs=2e-8)
            if event["event_type"] == "aspect":
                separation = angular_separation(recomputed.longitude, event["target_longitude"])
                assert abs(separation - event["aspect_angle"]) <= 1e-5
            elif event["event_type"] in {"ingress", "moon_ingress"}:
                assert abs(signed_orb(recomputed.longitude, event["target_longitude"])) <= 1e-5
            elif event["event_type"] == "station":
                assert abs(recomputed.speed) <= 1e-5

    def test_aspect_lifecycle_and_pass_grouping(self, sample_result: dict) -> None:
        aspects = [event for event in sample_result["events"] if event["event_type"] == "aspect"]
        assert aspects
        assert any(event["pass_count_in_window"] > 1 for event in aspects)
        for event in aspects:
            if event["window_clipped_start"]:
                assert event["entering_utc"] is None
            else:
                assert event["entering_utc"] <= event["exact_utc"]
            if event["window_clipped_end"]:
                assert event["leaving_utc"] is None
            else:
                assert event["leaving_utc"] >= event["exact_utc"]
            assert 1 <= event["pass_index_in_window"] <= event["pass_count_in_window"]

    def test_display_timezone_changes_only_local_representation(self) -> None:
        request = _sample_request()
        request["start"]["month"] = 1
        request["end"]["month"] = 4
        request["end"]["day"] = 1
        request["techniques"] = [request["techniques"][0]]
        shanghai = calculate_modern_timing(request, [])

        new_york_request = deepcopy(request)
        new_york_request["display_timezone"] = "America/New_York"
        new_york = calculate_modern_timing(new_york_request, [])

        assert [event["id"] for event in shanghai["events"]] == [event["id"] for event in new_york["events"]]
        assert [event["exact_utc"] for event in shanghai["events"]] == [event["exact_utc"] for event in new_york["events"]]
        for event in new_york["events"]:
            exact = datetime.fromisoformat(event["exact_utc"].replace("Z", "+00:00"))
            expected = exact.astimezone(ZoneInfo("America/New_York")).isoformat(timespec="milliseconds")
            assert event["exact_local"] == expected

    def test_progressed_moon_ingress_and_lunation_are_registered(self) -> None:
        request = _sample_request()
        request["end"].update({"year": 2061, "month": 1, "day": 1, "hour": 0, "minute": 0})
        request["techniques"] = [
            {
                "id": "secondary_progression",
                "moving_body_ids": ["SUN", "MOON"],
                "event_types": ["moon_ingress", "lunation"],
                "aspects": [],
            }
        ]
        assert validate_required_fields(request) is None
        result = calculate_modern_timing(request, [])
        event_types = {event["event_type"] for event in result["events"]}
        assert {"moon_ingress", "lunation"}.issubset(event_types)

    def test_requested_lot_is_resolved_as_a_timing_target(self) -> None:
        request = _sample_request()
        request["end"].update({"month": 1, "day": 2, "hour": 0, "minute": 0})
        request["target_point_set"] = {
            "body_ids": [],
            "include_nodes": False,
            "node_mode": "true_node",
            "custom_asteroids": [],
            "angle_ids": [],
            "house_cusps": [],
            "lot_ids": ["fortune"],
        }
        request["techniques"] = [
            {
                "id": "transit",
                "moving_body_ids": ["JUPITER"],
                "event_types": ["station"],
                "aspects": [],
            }
        ]
        assert validate_required_fields(request) is None
        result = calculate_modern_timing(request, [])
        assert result["meta"]["target_count"] == 1
        assert result["meta"]["effective_point_set"]["lot_ids"] == ["fortune"]


class TestAdapterParity:
    def test_progression_adapter_matches_single_point_mode(self) -> None:
        request = _sample_request()
        reference = request["start"]
        context = TimingContext(request, [], sidereal=False)
        reference_utc = datetime.fromisoformat("2025-12-31T16:00:00+00:00")
        adapter_value = context.progression_evaluator("MOON")(reference_utc)
        assert adapter_value is not None

        static = calculate_progressions(
            {
                "mode": "progression",
                "birth": request["birth"],
                "reference": reference,
                "point_set": {
                    "body_ids": ["SUN", "MOON"],
                    "include_nodes": False,
                    "node_mode": "true_node",
                    "custom_asteroids": [],
                    "angle_ids": [],
                    "house_cusps": [],
                    "lot_ids": [],
                },
                "node_mode": "true_node",
                "aspects": [],
            },
            [],
        )
        static_moon = next(row for row in static["progressed_planets"] if row["body_id"] == "MOON")
        assert adapter_value.longitude == pytest.approx(static_moon["longitude"], abs=1e-9)

    def test_solar_arc_adapter_matches_single_point_mode(self) -> None:
        request = _sample_request()
        reference = request["start"]
        context = TimingContext(request, [], sidereal=False)
        reference_utc = datetime.fromisoformat("2025-12-31T16:00:00+00:00")
        adapter_value = context.solar_arc_evaluator("SUN")(reference_utc)
        assert adapter_value is not None

        static = calculate_solar_arc(
            {
                "mode": "solar_arc",
                "birth": request["birth"],
                "reference": reference,
                "point_set": {
                    "body_ids": ["SUN"],
                    "include_nodes": False,
                    "node_mode": "true_node",
                    "custom_asteroids": [],
                    "angle_ids": [],
                    "house_cusps": [],
                    "lot_ids": [],
                },
                "node_mode": "true_node",
                "aspects": [],
            },
            [],
        )
        static_sun = next(row for row in static["solar_arc_planets"] if row["body_id"] == "SUN")
        assert adapter_value.longitude == pytest.approx(static_sun["longitude"], abs=1e-9)
