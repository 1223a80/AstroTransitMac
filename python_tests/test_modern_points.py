from __future__ import annotations

import pytest

from astro_backend_api import validate_required_fields
from astro_backend_modern_points import resolve_point_set, validate_point_set


def test_default_point_set_has_ten_planets_and_true_nodes() -> None:
    point_set = resolve_point_set(None)

    assert point_set["body_ids"] == [
        "SUN", "MOON", "MERCURY", "VENUS", "MARS",
        "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
    ]
    assert point_set["resolved_body_ids"][-2:] == ["TRUE_NODE", "SOUTH_TRUE_NODE"]


def test_custom_set_unions_asteroids_and_supports_new_angles() -> None:
    point_set = resolve_point_set({
        "body_ids": ["SUN", "CHIRON"],
        "include_nodes": True,
        "custom_asteroids": [433, 433],
        "angle_ids": ["ASC", "VERTEX", "ANTIVERTEX", "EQUATORIAL_ASCENDANT"],
        "house_cusps": [1, 7],
        "lot_ids": [],
    })

    assert point_set["custom_asteroids"] == [433]
    assert point_set["resolved_body_ids"] == [
        "SUN", "CHIRON", "TRUE_NODE", "SOUTH_TRUE_NODE", "AST:433",
    ]
    assert point_set["angle_ids"][-3:] == ["VERTEX", "ANTIVERTEX", "EQUATORIAL_ASCENDANT"]


@pytest.mark.parametrize(
    "payload, fragment",
    [
        ({"body_ids": ["TRUE_NODE"]}, "must not contain node ID"),
        ({"body_ids": ["NOT_A_BODY"]}, "is unknown"),
        ({"angle_ids": ["POLAR_ASCENDANT"]}, "is unknown"),
        ({"house_cusps": [1, 1]}, "duplicate house"),
        ({"custom_asteroids": [0]}, "positive integer"),
    ],
)
def test_invalid_point_set_is_rejected(payload: dict[str, object], fragment: str) -> None:
    errors = validate_point_set(payload)

    assert any(fragment in error for error in errors)
    with pytest.raises(ValueError, match="point_set"):
        resolve_point_set(payload)


def test_lot_validation_uses_existing_lot_registry() -> None:
    assert validate_point_set({"lot_ids": ["fortune"]}) == []
    assert any("unknown" in error for error in validate_point_set({"lot_ids": ["invented"]}))


def test_moment_requires_an_exact_timezone_and_clock_time() -> None:
    request = {
        "mode": "moment",
        "natal": {"year": 1990, "month": 1, "day": 1, "timezone": "Asia/Shanghai"},
        "transit": {"year": 2026, "month": 1, "day": 1, "hour": 12, "minute": 0, "timezone": "Asia/Shanghai"},
    }

    error = validate_required_fields(request)

    assert error is not None
    assert "natal.hour" in error["missing"]
    assert "natal.minute" in error["missing"]


def test_modern_node_mode_is_structurally_validated() -> None:
    request = {
        "mode": "synastry",
        "person_a": {},
        "person_b": {},
        "node_mode": "noon_convention",
    }

    error = validate_required_fields(request)

    assert error is not None
    assert any("node_mode" in item for item in error["invalid"])
