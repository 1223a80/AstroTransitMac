from __future__ import annotations

from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from astro_backend_api import validate_required_fields
from astro_backend_modern_timing import (
    PositionValue,
    TargetPoint,
    TimingContext,
    _aspect_events,
    _build_targets,
    _dedupe_and_number_events,
    estimate_modern_timing_work_units,
)


ROOT = Path(__file__).resolve().parents[1]


def _sample_request() -> dict:
    return json.loads((ROOT / "Examples" / "sample-modern-timing-request.json").read_text())


def _pair_only_point_set() -> dict:
    return {
        "midpoint_pairs": [
            {"point_a_id": "SUN", "point_b_id": "MOON"},
        ],
    }


def test_pair_only_target_set_expands_two_branches_without_default_targets() -> None:
    request = _sample_request()
    context = TimingContext(request, [], sidereal=False)
    targets, effective = _build_targets(context, _pair_only_point_set(), "true_node")

    assert len(targets) == 2
    assert {target.point_id for target in targets} == {"midpoint|MOON|SUN"}
    assert {target.kind for target in targets} == {"midpoint_axis"}
    assert {target.axis_branch for target in targets} == {"direct", "opposite"}
    assert effective["body_ids"] == []
    assert effective["angle_ids"] == []
    assert effective["midpoint_pairs"] == [
        {"point_a_id": "MOON", "point_b_id": "SUN"}
    ]


@pytest.mark.parametrize(
    "partial_selector",
    [
        {"include_nodes": False},
        {"body_ids": []},
        {"angle_ids": []},
        {"custom_asteroids": []},
    ],
)
def test_pair_only_partial_selectors_do_not_leak_ordinary_defaults(
    partial_selector: dict,
) -> None:
    request = _sample_request()
    context = TimingContext(request, [], sidereal=False)
    point_set = {**_pair_only_point_set(), **partial_selector}
    targets, effective = _build_targets(context, point_set, "true_node")

    assert len(targets) == 2
    assert {target.kind for target in targets} == {"midpoint_axis"}
    assert effective["body_ids"] == []
    assert effective["include_nodes"] is False
    assert effective["custom_asteroids"] == []
    assert effective["angle_ids"] == []
    assert effective["house_cusps"] == []
    assert effective["lot_ids"] == []


def test_midpoint_targets_contribute_actual_branch_count_to_estimator() -> None:
    request = _sample_request()
    context = TimingContext(request, [], sidereal=False)
    targets, _ = _build_targets(context, _pair_only_point_set(), "true_node")
    start = datetime(2030, 1, 1, tzinfo=timezone.utc)
    end = start + timedelta(days=14)
    techniques = [
        {
            "id": "transit",
            "moving_body_ids": ["MOON"],
            "event_types": ["aspect"],
            "aspects": [{"id": "square", "name": "刑相", "angle": 90.0, "orb": 1.0}],
        }
    ]

    assert estimate_modern_timing_work_units(start, end, techniques, len(targets)) == 337 * 2 * 2


class _LinearContext:
    warnings: list[str] = []

    def __init__(self, start: datetime) -> None:
        self.start = start

    def evaluator(self, source_type: str, point_id: str):
        assert source_type == "transit"
        assert point_id == "SUN"

        def evaluate(at_utc: datetime) -> PositionValue:
            hours = (at_utc - self.start).total_seconds() / 3600.0
            return PositionValue(80.0 + hours * 2.0, 2.0, "太阳", "synthetic")

        return evaluate


def test_direct_and_opposite_90_degree_exacts_keep_unique_branch_signatures() -> None:
    start = datetime(2030, 1, 1, tzinfo=timezone.utc)
    targets = [
        TargetPoint("midpoint|A|B", "A/B 中点轴", "midpoint_axis", 0.0, "direct"),
        TargetPoint("midpoint|A|B", "A/B 中点轴", "midpoint_axis", 180.0, "opposite"),
    ]
    rows = _aspect_events(
        _LinearContext(start),
        "transit",
        ["SUN"],
        [{"id": "square", "name": "刑相", "angle": 90.0, "orb": 1.0}],
        targets,
        start,
        start + timedelta(hours=10),
        ZoneInfo("UTC"),
        lambda _: None,
    )
    events = _dedupe_and_number_events(rows)

    assert len(events) == 2
    assert {event["target_point_id"] for event in events} == {"midpoint|A|B"}
    assert {event["target_axis_branch"] for event in events} == {"direct", "opposite"}
    assert len({event["group_id"] for event in events}) == 2
    assert len({event["id"] for event in events}) == 2
    assert all(event["pass_count_in_window"] == 1 for event in events)


def test_ordinary_target_group_signature_is_unchanged() -> None:
    start = datetime(2030, 1, 1, tzinfo=timezone.utc)
    rows = _aspect_events(
        _LinearContext(start),
        "transit",
        ["SUN"],
        [{"id": "square", "name": "刑相", "angle": 90.0, "orb": 1.0}],
        [TargetPoint("ASC", "ASC", "angle", 0.0)],
        start,
        start + timedelta(hours=10),
        ZoneInfo("UTC"),
        lambda _: None,
    )

    assert {row["group_id"] for row in rows} == {"transit|SUN|square|ASC"}
    assert {row["target_axis_branch"] for row in rows} == {None}


@pytest.mark.parametrize(
    "pairs, expected_text",
    [
        (
            [{"point_a_id": "SUN", "point_b_id": "SUN"}],
            "two different point IDs",
        ),
        (
            [
                {"point_a_id": "SUN", "point_b_id": "MOON"},
                {"point_a_id": "MOON", "point_b_id": "SUN"},
            ],
            "duplicate pair",
        ),
        ([{"point_a_id": "SUN"}], "point_b_id"),
    ],
)
def test_api_rejects_malformed_midpoint_pairs(pairs: list[dict], expected_text: str) -> None:
    request = _sample_request()
    request["target_point_set"]["midpoint_pairs"] = pairs
    error = validate_required_fields(request)

    assert error is not None
    assert expected_text in ";".join(error.get("invalid", []))


def test_unknown_midpoint_endpoint_is_not_silently_removed() -> None:
    request = _sample_request()
    context = TimingContext(request, [], sidereal=False)
    point_set = {
        "body_ids": [],
        "include_nodes": False,
        "custom_asteroids": [],
        "angle_ids": [],
        "house_cusps": [],
        "lot_ids": [],
        "midpoint_pairs": [
            {"point_a_id": "SUN", "point_b_id": "NOT_A_POINT"},
        ],
    }

    with pytest.raises(ValueError, match="unknown"):
        _build_targets(context, point_set, "true_node")
