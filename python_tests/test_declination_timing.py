"""Focused tests for mode=declination_timing (B7)."""

from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from astro_backend_api import validate_required_fields
from astro_backend_declination_timing import (
    body_declination_at,
    calculate_declination_timing,
    true_obliquity,
)
from astro_backend_modern_timing import _find_roots, _refine_root

ROOT = Path(__file__).resolve().parents[1]


def _sample_request() -> dict:
    return {
        "mode": "declination_timing",
        "birth": {
            "moment": {
                "year": 1990,
                "month": 1,
                "day": 1,
                "hour": 12,
                "minute": 0,
                "timezone": "Asia/Shanghai",
            },
            "latitude": 31.2304,
            "longitude": 121.4737,
            "houseSystem": "placidus",
            "zodiac": "tropical",
        },
        "start": {
            "year": 2026,
            "month": 1,
            "day": 1,
            "hour": 0,
            "minute": 0,
            "timezone": "Asia/Shanghai",
        },
        "end": {
            "year": 2026,
            "month": 2,
            "day": 15,
            "hour": 0,
            "minute": 0,
            "timezone": "Asia/Shanghai",
        },
        "display_timezone": "Asia/Shanghai",
        "moving_body_ids": ["MOON", "MARS"],
        "event_types": [
            "parallel",
            "contraparallel",
            "oob_entry",
            "oob_exit",
            "declination_station",
        ],
        "declination_orb": 1.0,
        "target_point_set": {
            "body_ids": ["SUN", "MOON", "MARS"],
            "include_nodes": False,
            "node_mode": "true_node",
            "custom_asteroids": [],
            "angle_ids": ["ASC"],
            "house_cusps": [],
            "lot_ids": [],
        },
    }


@pytest.fixture(scope="module")
def sample_result() -> dict:
    request = _sample_request()
    assert validate_required_fields(request) is None
    return calculate_declination_timing(request, [])


class TestTrueObliquity:
    def test_true_obliquity_near_mean_and_labelled(self) -> None:
        threshold, method = true_obliquity(2460676.0)
        assert 23.4 < threshold < 23.5
        assert method.startswith("true_obliquity") or method.startswith("mean_obliquity")


class TestBodyDeclination:
    def test_moon_equatorial_speed_present(self) -> None:
        value = body_declination_at(
            datetime(2025, 1, 1, tzinfo=timezone.utc),
            "MOON",
            [],
            set(),
        )
        assert value is not None
        assert abs(value.declination) > 0
        assert abs(value.declination_speed) > 0
        assert value.threshold_method.startswith("true_obliquity")
        assert value.out_of_bounds == (abs(value.declination) > value.oob_threshold)


class TestDeclinationTimingResponse:
    def test_contract_shape(self, sample_result: dict) -> None:
        assert sample_result["meta"]["mode"] == "declination_timing"
        assert sample_result["meta"]["method"] == "declination_timing_v1"
        assert sample_result["meta"]["coordinate_kind"] == "declination"
        assert sample_result["meta"]["oob_threshold_method"] == "true_obliquity_at_event_time"
        assert sample_result["meta"]["search_method"] == "bracket_plus_bisection"
        assert "requested_config" in sample_result
        assert "effective_config" in sample_result
        assert sample_result["effective_config"]["event_types"]
        assert sample_result["calculation_assumptions"]
        assert isinstance(sample_result["warnings"], list)
        assert "events" in sample_result

    def test_has_parallel_and_contraparallel(self, sample_result: dict) -> None:
        types = {event["event_type"] for event in sample_result["events"]}
        assert "parallel" in types
        assert "contraparallel" in types

    def test_has_oob_and_station(self, sample_result: dict) -> None:
        types = {event["event_type"] for event in sample_result["events"]}
        assert "oob_entry" in types or "oob_exit" in types
        assert "declination_station" in types

    def test_exact_times_are_refined_not_grid(self, sample_result: dict) -> None:
        parallels = [e for e in sample_result["events"] if e["event_type"] == "parallel"]
        assert parallels
        for event in parallels[:5]:
            residual = abs(event["moving_declination"] - event["target_declination"])
            assert residual < 1e-4
            assert event["exact_orb"] < 1e-4
            # Refined times should carry sub-minute resolution in ISO string.
            assert "T" in event["exact_utc"]
            assert event["exact_utc"].endswith("Z")

        stations = [e for e in sample_result["events"] if e["event_type"] == "declination_station"]
        assert stations
        for event in stations[:3]:
            assert abs(event["moving_declination_speed"]) < 1e-4
            assert event["exact_orb"] < 1e-4

    def test_oob_threshold_recorded_on_events(self, sample_result: dict) -> None:
        oob_events = [
            e
            for e in sample_result["events"]
            if e["event_type"] in {"oob_entry", "oob_exit", "declination_station"}
        ]
        assert oob_events
        for event in oob_events:
            assert event["oob_threshold"] is not None
            assert 23.0 < event["oob_threshold"] < 24.0
            assert event["threshold_method"]

    def test_lifecycle_fields_for_aspects(self, sample_result: dict) -> None:
        aspects = [
            e
            for e in sample_result["events"]
            if e["event_type"] in {"parallel", "contraparallel"}
        ]
        assert aspects
        for event in aspects:
            assert "entering_utc" in event
            assert "leaving_utc" in event
            assert "window_clipped_start" in event
            assert "window_clipped_end" in event
            if not event["window_clipped_start"]:
                assert event["entering_utc"] is not None
            if not event["window_clipped_end"]:
                assert event["leaving_utc"] is not None

    def test_multi_pass_numbering(self, sample_result: dict) -> None:
        multi = [e for e in sample_result["events"] if e["pass_count_in_window"] > 1]
        assert multi, "expected declination multi-hit pass numbering in sample window"
        for event in multi:
            assert 1 <= event["pass_index_in_window"] <= event["pass_count_in_window"]

    def test_timezone_local_offset(self, sample_result: dict) -> None:
        assert sample_result["events"]
        assert all("+08:00" in e["exact_local"] for e in sample_result["events"])
        assert all(e["exact_utc"].endswith("Z") for e in sample_result["events"])

    def test_empty_window_returns_no_events(self) -> None:
        request = _sample_request()
        request["start"] = {
            "year": 2026,
            "month": 1,
            "day": 1,
            "hour": 0,
            "minute": 0,
            "timezone": "Asia/Shanghai",
        }
        request["end"] = {
            "year": 2026,
            "month": 1,
            "day": 1,
            "hour": 0,
            "minute": 30,
            "timezone": "Asia/Shanghai",
        }
        request["moving_body_ids"] = ["PLUTO"]
        request["event_types"] = ["declination_station"]
        result = calculate_declination_timing(request, [])
        assert result["events"] == []
        assert result["meta"]["event_count"] == 0
        assert result["calculation_assumptions"]

    def test_invalid_event_type_rejected_by_api(self) -> None:
        request = _sample_request()
        request["event_types"] = ["parallel", "not_a_real_event"]
        error = validate_required_fields(request)
        assert error is not None
        assert "event_types" in str(error).lower() or "unsupported" in str(error).lower()

    def test_invalid_orb_rejected_by_api(self) -> None:
        request = _sample_request()
        request["declination_orb"] = 99
        error = validate_required_fields(request)
        assert error is not None

    def test_missing_birth_rejected(self) -> None:
        request = _sample_request()
        del request["birth"]
        error = validate_required_fields(request)
        assert error is not None

    def test_section_error_degradation_on_empty_targets(self) -> None:
        request = _sample_request()
        request["target_point_set"] = {
            "body_ids": [],
            "include_nodes": False,
            "node_mode": "true_node",
            "custom_asteroids": [],
            "angle_ids": [],
            "house_cusps": [],
            "lot_ids": [],
        }
        request["event_types"] = ["parallel", "declination_station"]
        result = calculate_declination_timing(request, [])
        # Stations still compute without natal targets.
        station_events = [e for e in result["events"] if e["event_type"] == "declination_station"]
        assert station_events or result.get("section_errors")
        parallel_events = [e for e in result["events"] if e["event_type"] == "parallel"]
        assert parallel_events == []
        assert any("目标" in w or "target" in w.lower() for w in result["warnings"]) or result.get(
            "section_errors"
        )

    def test_example_sample_file_validates(self) -> None:
        import json

        request = json.loads(
            (ROOT / "Examples" / "sample-declination-timing-request.json").read_text()
        )
        assert validate_required_fields(request) is None
        # Shorten end for speed in unit suite — full sample used in smoke.
        request = deepcopy(request)
        request["end"] = {
            "year": 2026,
            "month": 1,
            "day": 20,
            "hour": 0,
            "minute": 0,
            "timezone": "Asia/Shanghai",
        }
        request["moving_body_ids"] = ["MOON"]
        result = calculate_declination_timing(request, [])
        assert result["meta"]["mode"] == "declination_timing"
        assert isinstance(result["events"], list)


class TestRootRefinementNotSampleGrid:
    def test_synthetic_declination_root_not_step_endpoint(self) -> None:
        start = datetime(2030, 1, 1, tzinfo=timezone.utc)
        end = start + timedelta(hours=10)

        def residual(value: datetime) -> float:
            # Zero at 3.37 hours — between 1h samples.
            return (value - start).total_seconds() / 3600.0 - 3.37

        roots = _find_roots(residual, start, end, timedelta(hours=1))
        assert len(roots) == 1
        exact, abs_residual = roots[0]
        hour = (exact - start).total_seconds() / 3600.0
        assert abs(hour - 3.37) < 1e-5
        # Residual is in residual-units (hours here); time bisection stops at ~0.05s.
        assert abs_residual < 1e-5
        # Not equal to a coarse one-hour sample grid point.
        assert exact != start + timedelta(hours=3)
        assert exact != start + timedelta(hours=4)

    def test_refine_root_converges(self) -> None:
        start = datetime(2030, 1, 1, tzinfo=timezone.utc)
        left = start
        right = start + timedelta(hours=2)

        def residual(value: datetime) -> float:
            return (value - start).total_seconds() / 3600.0 - 1.25

        refined = _refine_root(residual, left, right)
        assert refined is not None
        exact, abs_residual = refined
        assert abs((exact - start).total_seconds() / 3600.0 - 1.25) < 1e-6
        assert abs_residual < 1e-9
