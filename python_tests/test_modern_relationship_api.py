from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path

import pytest

from astro_backend_api import validate_required_fields


ROOT = Path(__file__).resolve().parents[1]


def _load_sample(name: str) -> dict:
    return json.loads((ROOT / "Examples" / name).read_text())


def _relationship_point_set() -> dict:
    return {
        "body_ids": ["SUN", "MOON"],
        "include_nodes": False,
        "node_mode": "true_node",
        "custom_asteroids": [],
        "angle_ids": ["ASC"],
        "house_cusps": [1],
        "lot_ids": [],
    }


def _relationship_timing(chart_type: str = "composite") -> dict:
    timing = _load_sample("sample-modern-timing-request.json")
    relation = _load_sample("sample-composite-request.json")
    timing.pop("target_point_set")
    timing["target_chart"] = {
        "type": chart_type,
        "person_a": relation["person_a"],
        "person_b": relation["person_b"],
        "point_set": _relationship_point_set(),
    }
    timing["techniques"] = [
        {
            "id": "transit",
            "moving_body_ids": ["SUN", "MOON"],
            "event_types": ["aspect"],
            "aspects": [
                {
                    "id": "conjunction",
                    "name": "合相",
                    "angle": 0.0,
                    "orb": 1.0,
                }
            ],
        }
    ]
    return timing


def _progressed_composite() -> dict:
    relation = _load_sample("sample-composite-request.json")
    return {
        "mode": "progressed_composite",
        "person_a": relation["person_a"],
        "person_b": relation["person_b"],
        "reference": {
            "year": 2030,
            "month": 7,
            "day": 13,
            "hour": 12,
            "minute": 0,
            "timezone": "Pacific/Auckland",
        },
        "zodiac": "tropical",
        "node_mode": "true_node",
        "point_set": {
            "body_ids": ["SUN", "MOON"],
            "include_nodes": False,
            "node_mode": "true_node",
            "custom_asteroids": [],
            "angle_ids": [],
            "house_cusps": [],
            "lot_ids": [],
        },
        "aspects": [
            {
                "id": "conjunction",
                "name": "合相",
                "angle": 0.0,
                "orb": 1.0,
            }
        ],
    }


@pytest.mark.parametrize("chart_type", ["composite", "davison"])
def test_relationship_target_chart_accepts_exact_transit_aspect_contract(
    chart_type: str,
) -> None:
    assert validate_required_fields(_relationship_timing(chart_type)) is None


def test_natal_timing_without_target_chart_keeps_required_target_point_set() -> None:
    request = _load_sample("sample-modern-timing-request.json")
    request.pop("target_point_set")

    error = validate_required_fields(request)

    assert error is not None
    assert "target_point_set" in error.get("missing", [])


def test_target_chart_rejects_ambiguous_top_level_point_set() -> None:
    request = _relationship_timing()
    request["target_point_set"] = _relationship_point_set()

    error = validate_required_fields(request)

    assert error is not None
    assert "target_point_set and target_chart must not both be provided" in error.get("invalid", [])


@pytest.mark.parametrize("field", ["hour", "minute", "timezone"])
def test_relationship_target_chart_rejects_inexact_person_time(field: str) -> None:
    request = _relationship_timing()
    request["target_chart"]["person_b"]["moment"].pop(field)

    error = validate_required_fields(request)

    assert error is not None
    assert f"target_chart.person_b.moment.{field}" in error.get("missing", [])


@pytest.mark.parametrize(
    "mutate, expected",
    [
        (
            lambda request: request["techniques"][0].update(id="secondary_progression"),
            "techniques[0].id must be transit for relationship target_chart v1",
        ),
        (
            lambda request: request["techniques"][0].update(event_types=["aspect", "ingress"]),
            "techniques[0].event_types must contain only aspect for relationship target_chart v1",
        ),
    ],
)
def test_relationship_target_chart_rejects_5b_or_non_target_events(
    mutate,
    expected: str,
) -> None:
    request = _relationship_timing()
    mutate(request)

    error = validate_required_fields(request)

    assert error is not None
    assert expected in error.get("invalid", [])


def test_progressed_composite_accepts_exact_planet_only_contract() -> None:
    assert validate_required_fields(_progressed_composite()) is None


@pytest.mark.parametrize("field", ["hour", "minute", "timezone"])
def test_progressed_composite_rejects_inexact_reference(field: str) -> None:
    request = _progressed_composite()
    request["reference"].pop(field)

    error = validate_required_fields(request)

    assert error is not None
    assert f"reference.{field}" in error.get("missing", [])


@pytest.mark.parametrize(
    "field, value",
    [
        ("angle_ids", ["ASC"]),
        ("angles", ["ASC"]),
        ("house_cusps", [1]),
        ("lot_ids", ["LOT_FORTUNE"]),
        (
            "midpoint_pairs",
            [{"point_a_id": "SUN", "point_b_id": "MOON"}],
        ),
    ],
)
def test_progressed_composite_rejects_5b_point_sections(
    field: str,
    value: list,
) -> None:
    request = _progressed_composite()
    request["point_set"][field] = deepcopy(value)

    error = validate_required_fields(request)

    assert error is not None
    assert (
        f"point_set.{field} is not supported by progressed_composite v1"
        in error.get("invalid", [])
    )


@pytest.mark.parametrize(
    "aspects, expected",
    [
        ("bad", "aspects must be an array"),
        (
            [{"id": "invalid", "name": "", "angle": 181, "orb": 16}],
            "aspects[0].angle must be a finite number in [0, 180]",
        ),
    ],
)
def test_progressed_composite_rejects_malformed_aspect_contract(
    aspects,
    expected: str,
) -> None:
    request = _progressed_composite()
    request["aspects"] = aspects

    error = validate_required_fields(request)

    assert error is not None
    assert expected in error.get("invalid", [])
