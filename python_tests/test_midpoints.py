from __future__ import annotations

from copy import deepcopy

import pytest

import astro_backend_midpoints as midpoints
from astro_backend_api import validate_required_fields
from astro_backend_midpoints import (
    build_canonical_midpoint_axis,
    build_midpoint_axes,
    build_midpoint_hits,
    calculate_midpoints,
    resolve_natal_midpoint_points,
)


AXIS_KEYS = {
    "id",
    "point_a_id",
    "point_a_name",
    "point_b_id",
    "point_b_name",
    "midpoint_longitude",
    "opposite_longitude",
    "midpoint_text",
    "opposite_text",
    "trace",
}
TREE_KEYS = {"focus_point_id", "focus_point_name", "hits"}
HIT_KEYS = {
    "id",
    "focus_point_id",
    "focus_point_name",
    "source_point_id",
    "source_point_name",
    "axis_id",
    "axis_branch",
    "hit_longitude",
    "axis_longitude",
    "separation",
    "orb",
    "source_type",
    "reference_utc",
}


def _point(point_id: str, longitude: float, kind: str = "body") -> dict:
    return {
        "point_id": point_id,
        "name": point_id,
        "kind": kind,
        "longitude": longitude,
    }


def _birth() -> dict:
    return {
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
        "houseSystem": "whole_sign",
        "zodiac": "tropical",
    }


def _reference() -> dict:
    return {
        "year": 2026,
        "month": 7,
        "day": 13,
        "hour": 12,
        "minute": 0,
        "timezone": "Asia/Shanghai",
    }


def _request(**overrides: object) -> dict:
    request = {
        "mode": "midpoint",
        "birth": _birth(),
        "point_set": {
            "body_ids": ["SUN", "MOON"],
            "include_nodes": False,
            "custom_asteroids": [],
            "angle_ids": [],
            "house_cusps": [],
            "lot_ids": [],
        },
        "focus_point_ids": ["SUN"],
        "activation_sources": [
            "natal",
            "transit",
            "secondary_progression",
            "solar_arc",
        ],
        "activation_orb": 1.0,
        "modulus": 360,
        "include_opposite_axis": True,
    }
    request.update(overrides)
    return request


def test_wrap_midpoint_and_antipodal_tie_are_canonical() -> None:
    wrap = build_canonical_midpoint_axis(_point("A", 350), _point("B", 10))
    assert wrap["id"] == "midpoint|A|B"
    assert wrap["midpoint_longitude"] == 0
    assert wrap["opposite_longitude"] == 180
    assert wrap["trace"]["input_longitudes"] == [350, 10]

    antipodal = build_canonical_midpoint_axis(_point("B", 190), _point("A", 10))
    reversed_input = build_canonical_midpoint_axis(_point("A", 10), _point("B", 190))
    assert antipodal == reversed_input
    assert antipodal["midpoint_longitude"] == 100
    assert antipodal["opposite_longitude"] == 280
    assert antipodal["trace"]["input_longitudes"] == [10, 190]
    assert set(antipodal) == AXIS_KEYS


def test_axis_count_pair_deduplication_and_order_stability() -> None:
    points = [_point("C", 90), _point("A", 0), _point("B", 30), _point("A", 360)]
    axes = build_midpoint_axes(points)
    assert len(axes) == 3
    assert [axis["id"] for axis in axes] == [
        "midpoint|A|B",
        "midpoint|A|C",
        "midpoint|B|C",
    ]
    assert axes == build_midpoint_axes(list(reversed(points)))


def test_duplicate_point_id_with_conflicting_longitude_is_rejected() -> None:
    with pytest.raises(ValueError, match="conflicting longitudes"):
        build_midpoint_axes([_point("A", 0), _point("A", 1)])


def test_direct_and_opposite_hits_cross_zero_boundary() -> None:
    axis = build_canonical_midpoint_axis(_point("A", 350), _point("B", 10))
    sources = [_point("DIRECT", 359.75), _point("OPPOSITE", 180.25)]
    hits = build_midpoint_hits(
        sources,
        [axis],
        activation_orb=0.25,
        source_type="transit",
        reference_utc="2026-07-13T04:00:00+00:00",
        include_opposite_axis=True,
    )
    assert {(hit["source_point_id"], hit["axis_branch"]) for hit in hits} == {
        ("DIRECT", "direct"),
        ("OPPOSITE", "opposite"),
    }
    assert {hit["axis_id"] for hit in hits} == {"midpoint|A|B"}
    assert all(hit["separation"] == hit["orb"] == 0.25 for hit in hits)
    assert {hit["hit_longitude"] for hit in hits} == {359.75, 180.25}
    assert {hit["axis_longitude"] for hit in hits} == {0.0, 180.0}
    assert all(set(hit) == HIT_KEYS for hit in hits)

    direct_only = build_midpoint_hits(
        sources,
        [axis],
        activation_orb=0.25,
        source_type="transit",
        reference_utc="2026-07-13T04:00:00+00:00",
        include_opposite_axis=False,
    )
    assert [(hit["source_point_id"], hit["axis_branch"]) for hit in direct_only] == [
        ("DIRECT", "direct")
    ]


def test_authoritative_natal_resolver_supports_all_point_kinds_and_shrinks(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def fake_positions(jd, specs, warnings, sidereal=False):
        rows = []
        longitude_by_id = {
            "SUN": 10.0,
            "MOON": 20.0,
            "MERCURY": 30.0,
            "VENUS": 40.0,
            "MARS": 50.0,
            "JUPITER": 60.0,
            "SATURN": 70.0,
            "AST:433": 80.0,
        }
        for spec in specs:
            if spec.body_id == "CHIRON" or spec.body_id not in longitude_by_id:
                continue
            rows.append(
                {
                    "body_id": spec.body_id,
                    "name": spec.name,
                    "longitude": longitude_by_id[spec.body_id],
                }
            )
        return rows

    monkeypatch.setattr(midpoints, "calculate_positions", fake_positions)
    monkeypatch.setattr(
        midpoints,
        "build_houses",
        lambda *args, **kwargs: (
            [float(index * 30) for index in range(12)],
            {"ASC": 0.0, "MC": 270.0, "DSC": 180.0, "IC": 90.0},
            "Whole Sign",
        ),
    )
    monkeypatch.setattr(
        midpoints,
        "calculate_lots",
        lambda *args, **kwargs: [{"id": "fortune", "name": "福点", "longitude": 25.0}],
    )

    warnings: list[str] = []
    points, effective = resolve_natal_midpoint_points(
        _birth(),
        {
            "body_ids": ["SUN", "CHIRON"],
            "include_nodes": False,
            "custom_asteroids": [433],
            "angle_ids": ["ASC", "VERTEX"],
            "house_cusps": [1],
            "lot_ids": ["fortune"],
        },
        warnings,
    )

    assert {(row["point_id"], row["kind"]) for row in points} == {
        ("SUN", "body"),
        ("AST:433", "body"),
        ("ASC", "angle"),
        ("HOUSE_CUSP_1", "house_cusp"),
        ("fortune", "lot"),
    }
    assert effective["resolved_body_ids"] == ["SUN", "AST:433"]
    assert effective["body_ids"] == ["SUN"]
    assert effective["custom_asteroids"] == [433]
    assert effective["angle_ids"] == ["ASC"]
    assert effective["house_cusps"] == [1]
    assert effective["lot_ids"] == ["fortune"]
    assert any("CHIRON" in warning for warning in warnings)
    assert any("VERTEX" in warning for warning in warnings)


def test_authoritative_natal_resolver_accepts_existing_timing_context() -> None:
    from astro_backend_modern_timing import TimingContext

    warnings: list[str] = []
    context = TimingContext({"birth": _birth()}, warnings, sidereal=False)
    points, effective = resolve_natal_midpoint_points(
        context,
        {
            "body_ids": ["SUN"],
            "include_nodes": False,
            "custom_asteroids": [],
            "angle_ids": ["ASC"],
            "house_cusps": [1],
            "lot_ids": [],
        },
        warnings,
    )
    assert {(point["point_id"], point["kind"]) for point in points} == {
        ("SUN", "body"),
        ("ASC", "angle"),
        ("HOUSE_CUSP_1", "house_cusp"),
    }
    assert effective["resolved_body_ids"] == ["SUN"]
    assert effective["angle_ids"] == ["ASC"]
    assert effective["house_cusps"] == [1]


def test_point_set_reduction_also_reduces_axes_and_focus_trees(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    effective = {
        "body_ids": ["A", "B"],
        "include_nodes": False,
        "node_mode": "true_node",
        "custom_asteroids": [],
        "angle_ids": [],
        "house_cusps": [],
        "lot_ids": [],
        "resolved_body_ids": ["A", "B"],
    }
    monkeypatch.setattr(
        midpoints,
        "resolve_natal_midpoint_points",
        lambda *args, **kwargs: ([_point("A", 350), _point("B", 10)], effective),
    )
    request = _request(focus_point_ids=["A", "REMOVED"])
    result = calculate_midpoints(request, [])
    assert [axis["id"] for axis in result["axes"]] == ["midpoint|A|B"]
    assert [tree["focus_point_id"] for tree in result["trees"]] == ["A"]
    assert any("REMOVED" in warning for warning in result["warnings"])


def test_focus_tree_uses_natal_focus_against_shared_axis(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    points = [_point("A", 350), _point("B", 10), _point("FOCUS", 0)]
    effective = {
        "body_ids": ["A", "B", "FOCUS"],
        "include_nodes": False,
        "node_mode": "true_node",
        "custom_asteroids": [],
        "angle_ids": [],
        "house_cusps": [],
        "lot_ids": [],
        "resolved_body_ids": ["A", "B", "FOCUS"],
    }
    monkeypatch.setattr(
        midpoints,
        "resolve_natal_midpoint_points",
        lambda *args, **kwargs: (points, effective),
    )
    result = calculate_midpoints(
        _request(focus_point_ids=["FOCUS"], activation_orb=0.1),
        [],
    )
    tree = result["trees"][0]
    assert set(tree) == TREE_KEYS
    assert tree["focus_point_id"] == "FOCUS"
    assert [(hit["axis_id"], hit["axis_branch"]) for hit in tree["hits"]] == [
        ("midpoint|A|B", "direct")
    ]
    assert tree["hits"][0]["focus_point_id"] == "FOCUS"
    assert tree["hits"][0]["focus_point_name"] == "FOCUS"
    assert set(tree["hits"][0]) == HIT_KEYS


def test_no_reference_returns_no_snapshot_activations() -> None:
    result = calculate_midpoints(_request(), [])
    assert len(result["axes"]) == 1
    assert result["snapshot_activations"] == []
    assert result["meta"]["reference_utc"] is None
    assert {
        "schema_version",
        "method",
        "modulus",
        "activation_orb",
        "include_opposite_axis",
        "birth_utc",
        "reference_utc",
        "ephemeris",
        "effective_point_set",
    } <= set(result["meta"])
    assert result["section_errors"] is None


def test_all_four_activation_sources_and_independent_orb(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    points = [_point("A", 350), _point("B", 10)]
    effective = {
        "body_ids": ["A", "B"],
        "include_nodes": False,
        "node_mode": "true_node",
        "custom_asteroids": [],
        "angle_ids": [],
        "house_cusps": [],
        "lot_ids": [],
        "resolved_body_ids": ["A", "B"],
    }
    monkeypatch.setattr(
        midpoints,
        "resolve_natal_midpoint_points",
        lambda *args, **kwargs: (points, effective),
    )

    def fake_source(source_type, *args, **kwargs):
        return [_point(f"SOURCE:{source_type}", 0.75)]

    monkeypatch.setattr(midpoints, "_activation_points_for_source", fake_source)
    request = _request(reference=_reference(), focus_point_ids=[])
    result = calculate_midpoints(request, [])
    assert result["meta"]["activation_orb"] == 1.0
    assert {hit["source_type"] for hit in result["snapshot_activations"]} == {
        "natal",
        "transit",
        "secondary_progression",
        "solar_arc",
    }
    assert all(hit["axis_id"] == "midpoint|A|B" for hit in result["snapshot_activations"])
    assert all(hit["axis_branch"] == "direct" for hit in result["snapshot_activations"])
    assert all(hit["orb"] == 0.75 for hit in result["snapshot_activations"])
    assert all(hit["focus_point_id"] is None for hit in result["snapshot_activations"])
    assert all(hit["focus_point_name"] is None for hit in result["snapshot_activations"])
    assert all(set(hit) == HIT_KEYS for hit in result["snapshot_activations"])
    assert all(hit["reference_utc"].endswith("+00:00") for hit in result["snapshot_activations"])

    tighter = deepcopy(request)
    tighter["activation_orb"] = 0.5
    assert calculate_midpoints(tighter, [])["snapshot_activations"] == []


def test_activation_source_failure_is_isolated(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    points = [_point("A", 350), _point("B", 10)]
    effective = {
        "body_ids": ["A", "B"],
        "include_nodes": False,
        "node_mode": "true_node",
        "custom_asteroids": [],
        "angle_ids": [],
        "house_cusps": [],
        "lot_ids": [],
        "resolved_body_ids": ["A", "B"],
    }
    monkeypatch.setattr(
        midpoints,
        "resolve_natal_midpoint_points",
        lambda *args, **kwargs: (points, effective),
    )

    def fake_source(source_type, *args, **kwargs):
        if source_type == "transit":
            raise RuntimeError("synthetic transit failure")
        return [_point(f"SOURCE:{source_type}", 0.75)]

    monkeypatch.setattr(midpoints, "_activation_points_for_source", fake_source)
    warnings: list[str] = []
    result = calculate_midpoints(
        _request(reference=_reference(), focus_point_ids=[]),
        warnings,
    )

    assert result["section_errors"] == {"transit": "synthetic transit failure"}
    assert {hit["source_type"] for hit in result["snapshot_activations"]} == {
        "natal",
        "secondary_progression",
        "solar_arc",
    }
    assert any("transit" in warning and "synthetic transit failure" in warning for warning in warnings)


def test_real_ephemeris_paths_cover_all_four_activation_sources() -> None:
    result = calculate_midpoints(
        _request(reference=_reference(), focus_point_ids=[], activation_orb=180),
        [],
    )
    assert result["section_errors"] is None
    assert {hit["source_type"] for hit in result["snapshot_activations"]} == {
        "natal",
        "transit",
        "secondary_progression",
        "solar_arc",
    }
    assert result["meta"]["ephemeris"] == "Swiss Ephemeris"


def test_point_set_node_mode_takes_priority_over_top_level(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, str] = {}

    def fake_resolver(*args, **kwargs):
        captured["node_mode"] = kwargs["node_mode"]
        return (
            [_point("MEAN_NODE", 10), _point("SOUTH_MEAN_NODE", 190)],
            {
                "body_ids": [],
                "include_nodes": True,
                "node_mode": "mean_node",
                "custom_asteroids": [],
                "angle_ids": [],
                "house_cusps": [],
                "lot_ids": [],
                "resolved_body_ids": ["MEAN_NODE", "SOUTH_MEAN_NODE"],
            },
        )

    monkeypatch.setattr(midpoints, "resolve_natal_midpoint_points", fake_resolver)
    point_set = deepcopy(_request()["point_set"])
    point_set["include_nodes"] = True
    point_set["node_mode"] = "mean_node"
    result = calculate_midpoints(
        _request(point_set=point_set, node_mode="true_node", focus_point_ids=[]),
        [],
    )
    assert captured["node_mode"] == "mean_node"
    assert result["meta"]["effective_point_set"]["node_mode"] == "mean_node"


@pytest.mark.parametrize("field", ["hour", "minute", "timezone"])
def test_api_rejects_inexact_midpoint_birth_time(field: str) -> None:
    request = _request()
    request["birth"]["moment"].pop(field)
    error = validate_required_fields(request)

    assert error is not None
    assert f"birth.moment.{field}" in error.get("missing", [])


def test_api_rejects_invalid_reference_timezone_and_non_360_modulus() -> None:
    request = _request(reference=_reference(), modulus=90)
    request["reference"]["timezone"] = "Not/AZone"
    error = validate_required_fields(request)

    assert error is not None
    invalid = ";".join(error.get("invalid", []))
    assert "reference is invalid" in invalid
    assert "modulus currently only supports 360" in invalid


def test_api_rejects_invalid_nested_point_set_node_mode() -> None:
    request = _request()
    request["point_set"]["node_mode"] = "bogus"
    error = validate_required_fields(request)

    assert error is not None
    assert "point_set: node_mode must be one of: true_node, mean_node" in error.get("invalid", [])


@pytest.mark.parametrize("modulus", [45, 90, "90", True])
def test_v1_rejects_non_360_modulus(modulus: object) -> None:
    with pytest.raises(ValueError, match="modulus must be 360"):
        calculate_midpoints(_request(modulus=modulus), [])
