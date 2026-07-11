from __future__ import annotations

import pytest

pytestmark = [pytest.mark.requires_ephemeris]


def sample_request(zodiac: str = "tropical") -> dict:
    return {
        "mode": "horary",
        "chart": {
            "moment": {
                "year": 2026, "month": 5, "day": 5,
                "hour": 15, "minute": 30, "timezone": "Asia/Shanghai",
            },
            "latitude": 31.2304,
            "longitude": 121.4737,
            "houseSystem": "regiomontanus",
            "zodiac": zodiac,
            "boundsSystem": "egyptian",
            "triplicitySystem": "dorothean",
        },
        "questionText": "我最近能找到新工作吗？",
        "placeName": "上海",
        "aspectOrb": 3.5,
    }


def test_horary_nested_validation_is_structured() -> None:
    from astro_backend_api import validate_required_fields

    error = validate_required_fields({"mode": "horary", "chart": {}})
    assert error is not None
    assert "chart.moment" in error["missing"]
    assert "chart.latitude" in error["missing"]
    assert "chart.longitude" in error["missing"]
    assert "questionText" in error["missing"]


@pytest.mark.parametrize(
    ("field", "value"),
    [("latitude", 91), ("longitude", -181)],
)
def test_horary_coordinate_ranges_are_validated(field: str, value: float) -> None:
    from astro_backend_api import validate_required_fields

    request = sample_request()
    request["chart"][field] = value
    error = validate_required_fields(request)
    assert error is not None
    assert any(f"chart.{field}" in item for item in error["invalid"])


def test_horary_aspect_orb_range_is_validated() -> None:
    from astro_backend_api import validate_required_fields

    request = sample_request()
    request["aspectOrb"] = 10.1
    error = validate_required_fields(request)
    assert error is not None
    assert any("aspectOrb" in item for item in error["invalid"])


@pytest.mark.parametrize(
    ("zodiac", "label"),
    [
        ("sidereal_lahiri", "Lahiri Sidereal"),
        ("sidereal_raman", "Raman Sidereal"),
        ("sidereal_krishnamurti", "Krishnamurti Sidereal"),
        ("sidereal_yukteshwar", "Yukteshwar Sidereal"),
    ],
)
def test_horary_meta_preserves_sidereal_mode(zodiac: str, label: str) -> None:
    from astro_backend_horary import calculate_horary

    result = calculate_horary(sample_request(zodiac), [])
    assert result["meta"]["zodiac"] == label
    assert result["meta"]["aspect_orb"] == 3.5
