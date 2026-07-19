from __future__ import annotations

import copy
import json
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from astro_backend_api import validate_required_fields
from astro_backend_modern_return import calculate_modern_return
from astro_backend_core import moment_to_jd, swe


ROOT = Path(__file__).resolve().parents[1]
EPHEMERIS = ROOT / "Sources" / "TransitStudio" / "Resources" / "ephemeris"


def _request(body_id: str = "SUN") -> dict:
    sample = json.loads((ROOT / f"Examples/sample-modern-{'solar' if body_id == 'SUN' else 'lunar'}-return-request.json").read_text())
    return sample


@pytest.fixture(autouse=True)
def _ephemeris_path() -> None:
    swe.set_ephe_path(str(EPHEMERIS))


def test_solar_return_current_matches_natal_target() -> None:
    request = _request("SUN")
    warnings: list[str] = []
    result = calculate_modern_return(request, warnings)
    current = result["current_cycle_return"]

    assert current is not None
    assert result["previous_return"] is not None
    assert result["next_return"] is not None
    assert current["exact_error"] <= 1e-5
    assert current["chart"]["angles"]
    assert result["meta"]["return_body_id"] == "SUN"
    assert result["meta"]["effective_point_set"]


def test_lunar_occurrences_are_ordered_around_reference() -> None:
    result = calculate_modern_return(_request("MOON"), [])
    previous = result["previous_return"]
    current = result["current_cycle_return"]
    next_return = result["next_return"]

    assert previous and current and next_return
    assert previous["exact_utc"] < current["exact_utc"] < next_return["exact_utc"]
    assert current["exact_error"] <= 1e-5
    assert next_return["exact_error"] <= 1e-5


def test_custom_location_does_not_change_exact_utc_or_longitude() -> None:
    birth_location = _request("SUN")
    custom_location = copy.deepcopy(birth_location)
    custom_location["location_source"] = "custom"
    custom_location["location"] = {
        "name": "London", "latitude": 51.5074, "longitude": -0.1278, "timezone": "Europe/London",
    }
    first = calculate_modern_return(birth_location, [])
    second = calculate_modern_return(custom_location, [])

    assert first["current_cycle_return"]["exact_utc"] == second["current_cycle_return"]["exact_utc"]
    assert first["current_cycle_return"]["return_longitude"] == pytest.approx(
        second["current_cycle_return"]["return_longitude"], abs=1e-8,
    )
    assert first["current_cycle_return"]["chart"]["angles"] != second["current_cycle_return"]["chart"]["angles"]


def test_dst_local_offset_and_sidereal_target_are_explicit() -> None:
    request = _request("SUN")
    request["location_source"] = "custom"
    request["location"] = {
        "name": "New York", "latitude": 40.7128, "longitude": -74.0060, "timezone": "America/New_York",
    }
    request["zodiac"] = "sidereal_lahiri"
    result = calculate_modern_return(request, [])
    current = result["current_cycle_return"]
    assert current is not None
    exact = datetime.fromisoformat(current["exact_utc"].replace("Z", "+00:00"))
    expected_local = exact.astimezone(ZoneInfo("America/New_York")).isoformat()
    assert current["exact_local"] == expected_local
    assert result["meta"]["zodiac"] == "sidereal_lahiri"
    assert current["exact_error"] <= 1e-5


def test_invalid_return_request_is_rejected_at_api_boundary() -> None:
    request = _request("SUN")
    request["return_body_id"] = "NOT_A_PLANET"
    request["precession_correction"] = "with_precession"
    error = validate_required_fields(request)

    assert error is not None
    assert any("return_body_id" in item for item in error["invalid"])
    assert any("precession" in item for item in error["invalid"])


def test_mercury_return_is_supported() -> None:
    request = _request("SUN")
    request["return_body_id"] = "MERCURY"
    assert validate_required_fields(request) is None
    result = calculate_modern_return(request, [])
    assert result["meta"]["return_body_id"] == "MERCURY"
    assert result["current_cycle_return"] is not None
    assert result["current_cycle_return"]["exact_error"] <= 1e-4
    assert result["all_crossings"]
    assert result["calculation_assumptions"]

    invalid_timezone = _request("SUN")
    invalid_timezone["birth"]["moment"]["timezone"] = "Not/AZone"
    timezone_error = validate_required_fields(invalid_timezone)
    assert timezone_error is not None
    assert any("timezone" in item for item in timezone_error["invalid"])

    invalid_location = _request("SUN")
    invalid_location["location_source"] = "custom"
    invalid_location["location"] = {
        "name": "Unknown", "latitude": 31.0, "longitude": 121.0, "timezone": "Not/AZone",
    }
    location_error = validate_required_fields(invalid_location)
    assert location_error is not None
    assert any("location.timezone" in item for item in location_error["invalid"])
