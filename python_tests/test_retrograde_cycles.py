"""Focused tests for mode=retrograde_cycles (B8 shadows)."""

from __future__ import annotations

from pathlib import Path

from astro_backend_api import validate_required_fields
from astro_backend_retrograde_cycles import calculate_retrograde_cycles

ROOT = Path(__file__).resolve().parents[1]


def _request() -> dict:
    return {
        "mode": "retrograde_cycles",
        "start": {
            "year": 2025,
            "month": 1,
            "day": 1,
            "hour": 0,
            "minute": 0,
            "timezone": "Asia/Shanghai",
        },
        "end": {
            "year": 2025,
            "month": 12,
            "day": 31,
            "hour": 23,
            "minute": 59,
            "timezone": "Asia/Shanghai",
        },
        "display_timezone": "Asia/Shanghai",
        "body_ids": ["MERCURY", "MARS"],
        "zodiac": "tropical",
    }


def test_api_accepts_sample_shape() -> None:
    assert validate_required_fields(_request()) is None


def test_mercury_has_shadow_cycle_from_true_stations() -> None:
    result = calculate_retrograde_cycles(_request(), [])
    assert result["meta"]["method"] == "retrograde_shadow_from_true_stations_v1"
    assert result["requested_config"]
    assert result["effective_config"]
    assert result["calculation_assumptions"]
    mercury_cycles = [c for c in result["cycles"] if c["body_id"] == "MERCURY"]
    assert mercury_cycles, "expected at least one Mercury retrograde cycle in 2025"
    cycle = mercury_cycles[0]
    assert cycle["retrograde_station_utc"]
    assert cycle["direct_station_utc"]
    assert cycle["retrograde_station_utc"] < cycle["direct_station_utc"]
    assert cycle["shadow_longitude_pre"] == cycle["direct_station_longitude"]
    assert cycle["shadow_longitude_post"] == cycle["retrograde_station_longitude"]
    # Pre/post may clip at pad edges, but method must record clipping honestly.
    assert "window_clipped" in cycle
    assert cycle["phases"]
    phase_ids = {p["phase"] for p in cycle["phases"]}
    assert phase_ids == {"pre_shadow", "retrograde", "post_shadow"}


def test_stations_have_refined_speed_near_zero() -> None:
    result = calculate_retrograde_cycles(_request(), [])
    assert result["stations"]
    for station in result["stations"][:6]:
        assert abs(station["speed"]) < 1e-3
        assert station["exact_utc"].endswith("Z")
        assert "+08:00" in station["exact_local"]


def test_sun_rejected() -> None:
    request = _request()
    request["body_ids"] = ["SUN"]
    error = validate_required_fields(request)
    assert error is not None


def test_empty_window_no_crash() -> None:
    request = _request()
    request["start"] = {
        "year": 2025,
        "month": 1,
        "day": 1,
        "hour": 0,
        "minute": 0,
        "timezone": "Asia/Shanghai",
    }
    request["end"] = {
        "year": 2025,
        "month": 1,
        "day": 3,
        "hour": 0,
        "minute": 0,
        "timezone": "Asia/Shanghai",
    }
    request["body_ids"] = ["PLUTO"]
    result = calculate_retrograde_cycles(request, [])
    assert result["cycles"] == [] or isinstance(result["cycles"], list)
    assert result["meta"]["cycle_count"] == len(result["cycles"])
