from __future__ import annotations

import json
from copy import deepcopy
from datetime import timezone
from pathlib import Path
from typing import Any

import pytest

import astro_backend_progressed_composite as progressed_composite_module
from astro_backend_core import angular_separation, circular_midpoint, moment_to_local_datetime
from astro_backend_progressed_composite import calculate_progressed_composite
from astro_backend_progressions import _calc_progressed_dt
from astro_backend_ephemeris import calculate_positions as real_calculate_positions


PERSON_A = {
    "name": "Person A",
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
}
PERSON_B = {
    "name": "Person B",
    "moment": {
        "year": 1992,
        "month": 6,
        "day": 15,
        "hour": 8,
        "minute": 30,
        "timezone": "America/New_York",
    },
    "latitude": 40.7128,
    "longitude": -74.0060,
}
REFERENCE = {
    # UTC+14 makes the reference's UTC date the previous calendar date.
    "year": 2026,
    "month": 6,
    "day": 2,
    "hour": 12,
    "minute": 0,
    "timezone": "Pacific/Kiritimati",
}
BODY_IDS = ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]
ASPECTS = [
    {"id": "conjunction", "name": "合相", "angle": 0, "orb": 180},
]


def _request(
    *,
    person_a: dict[str, Any] | None = None,
    person_b: dict[str, Any] | None = None,
    point_set: dict[str, Any] | None = None,
    aspects: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    request: dict[str, Any] = {
        "mode": "progressed_composite",
        "person_a": deepcopy(person_a or PERSON_A),
        "person_b": deepcopy(person_b or PERSON_B),
        "reference": deepcopy(REFERENCE),
        "zodiac": "tropical",
        "node_mode": "true_node",
        "aspects": deepcopy(aspects if aspects is not None else ASPECTS),
    }
    if point_set is not None:
        request["point_set"] = deepcopy(point_set)
    return request


def _rows_by_id(result: dict[str, Any], key: str) -> dict[str, dict[str, Any]]:
    return {row["body_id"]: row for row in result[key]}


def test_progressed_utc_uses_each_person_birth_utc_and_exact_reference() -> None:
    result = calculate_progressed_composite(_request(), [])
    meta = result["meta"]

    a_birth_dt = moment_to_local_datetime(PERSON_A["moment"]).astimezone(timezone.utc)
    b_birth_dt = moment_to_local_datetime(PERSON_B["moment"]).astimezone(timezone.utc)
    reference_dt = moment_to_local_datetime(REFERENCE).astimezone(timezone.utc)
    expected_a_dt, _ = _calc_progressed_dt(a_birth_dt, reference_dt)
    expected_b_dt, _ = _calc_progressed_dt(b_birth_dt, reference_dt)

    assert meta["method"] == "progress_each_person_then_midpoint"
    assert meta["schema_version"] == 1
    assert meta["zodiac"] == "tropical"
    assert meta["person_a_birth_utc"] == "1990-01-01T04:00:00+00:00"
    # New York is on daylight time for this birth moment.
    assert meta["person_b_birth_utc"] == "1992-06-15T12:30:00+00:00"
    assert meta["reference_utc"] == "2026-06-01T22:00:00+00:00"
    assert meta["person_a_progressed_utc"] == expected_a_dt.isoformat()
    assert meta["person_b_progressed_utc"] == expected_b_dt.isoformat()
    assert meta["person_a_progressed_utc"] != meta["person_b_progressed_utc"]


def test_each_radix_and_progressed_trace_recomputes_circular_midpoint() -> None:
    result = calculate_progressed_composite(_request(), [])

    for key, expected_phase in (
        ("radix_composite_planets", "radix"),
        ("progressed_composite_planets", "progressed"),
    ):
        rows = result[key]
        assert rows
        for row in rows:
            trace = row["trace"]
            assert trace["phase"] == expected_phase
            assert trace["reference_utc"] == result["meta"]["reference_utc"]
            expected = circular_midpoint(
                trace["person_a"]["input_longitude"],
                trace["person_b"]["input_longitude"],
            )
            assert row["longitude"] == pytest.approx(expected, abs=1e-12)
            assert trace["composite_longitude"] == pytest.approx(expected, abs=1e-12)
            assert trace["person_a"]["birth_utc"] == result["meta"]["person_a_birth_utc"]
            assert trace["person_b"]["birth_utc"] == result["meta"]["person_b_birth_utc"]
            if expected_phase == "radix":
                assert trace["person_a"]["progressed_utc"] == result["meta"]["person_a_birth_utc"]
                assert trace["person_b"]["progressed_utc"] == result["meta"]["person_b_birth_utc"]
            else:
                assert trace["person_a"]["progressed_utc"] == result["meta"]["person_a_progressed_utc"]
                assert trace["person_b"]["progressed_utc"] == result["meta"]["person_b_progressed_utc"]


def test_ab_swap_preserves_positions_traces_and_aspects() -> None:
    original = calculate_progressed_composite(_request(), [])
    swapped = calculate_progressed_composite(
        _request(person_a=PERSON_B, person_b=PERSON_A), []
    )

    for key in ("radix_composite_planets", "progressed_composite_planets"):
        original_rows = _rows_by_id(original, key)
        swapped_rows = _rows_by_id(swapped, key)
        assert original_rows.keys() == swapped_rows.keys()
        for body_id in original_rows:
            assert swapped_rows[body_id]["longitude"] == pytest.approx(
                original_rows[body_id]["longitude"], abs=1e-12
            )
            original_trace = original_rows[body_id]["trace"]
            swapped_trace = swapped_rows[body_id]["trace"]
            assert swapped_trace["person_a"]["input_longitude"] == original_trace["person_b"]["input_longitude"]
            assert swapped_trace["person_b"]["input_longitude"] == original_trace["person_a"]["input_longitude"]

    assert swapped["progressed_to_radix_aspects"] == original["progressed_to_radix_aspects"]


def test_omitted_chart_zodiac_has_ab_independent_tropical_default() -> None:
    person_a = deepcopy(PERSON_A)
    person_b = deepcopy(PERSON_B)
    person_a["zodiac"] = "sidereal_lahiri"
    person_b["zodiac"] = "tropical"
    original_request = _request(person_a=person_a, person_b=person_b)
    swapped_request = _request(person_a=person_b, person_b=person_a)
    original_request.pop("zodiac")
    swapped_request.pop("zodiac")

    original = calculate_progressed_composite(original_request, [])
    swapped = calculate_progressed_composite(swapped_request, [])

    assert [row["longitude"] for row in original["radix_composite_planets"]] == pytest.approx(
        [row["longitude"] for row in swapped["radix_composite_planets"]], abs=1e-12
    )
    assert [row["longitude"] for row in original["progressed_composite_planets"]] == pytest.approx(
        [row["longitude"] for row in swapped["progressed_composite_planets"]], abs=1e-12
    )


def test_progressed_to_radix_aspects_use_existing_aspect_helper() -> None:
    result = calculate_progressed_composite(_request(), [])
    assert result["progressed_to_radix_aspects"]

    progressed = _rows_by_id(result, "progressed_composite_planets")
    radix = _rows_by_id(result, "radix_composite_planets")
    hit = result["progressed_to_radix_aspects"][0]
    assert hit["transit_body_id"] in progressed
    assert hit["natal_body_id"] in radix
    assert hit["aspect_id"] == "conjunction"
    expected_separation = angular_separation(
        progressed[hit["transit_body_id"]]["longitude"],
        radix[hit["natal_body_id"]]["longitude"],
    )
    assert hit["separation"] == pytest.approx(expected_separation)


def test_response_has_only_v1_sections_and_no_houses_or_angles() -> None:
    result = calculate_progressed_composite(_request(), [])
    assert set(result) == {
        "meta",
        "radix_composite_planets",
        "progressed_composite_planets",
        "progressed_to_radix_aspects",
        "warnings",
        "section_errors",
    }
    assert "houses" not in result
    assert "angles" not in result
    assert result["meta"]["effective_point_set"]["angle_ids"] == []


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("angle_ids", ["ASC"]),
        ("angles", ["ASC"]),
        ("house_cusps", [1]),
        ("lot_ids", ["fortune"]),
        ("midpoint_pairs", [{"point_a_id": "SUN", "point_b_id": "MOON"}]),
    ],
)
def test_v1_rejects_nonempty_nonplanet_point_set_sections(
    field: str,
    value: Any,
) -> None:
    point_set = {"body_ids": ["SUN"], "include_nodes": False, field: value}
    with pytest.raises(ValueError, match=rf"point_set\.{field}"):
        calculate_progressed_composite(_request(point_set=point_set), [])


def test_point_set_accepts_bodies_nodes_and_custom_asteroids(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    point_set = {
        "body_ids": ["SUN", "CHIRON"],
        "include_nodes": True,
        "custom_asteroids": [433],
        "angle_ids": [],
        "house_cusps": [],
        "lot_ids": [],
    }
    def fake_positions(
        _jd: float,
        specs: list[Any],
        _warnings: list[str],
        *,
        sidereal: bool = False,
    ) -> list[dict[str, Any]]:
        del sidereal
        return [
            {
                "body_id": spec.body_id,
                "name": spec.name,
                "longitude": float(index * 20),
            }
            for index, spec in enumerate(specs)
        ]

    monkeypatch.setattr(progressed_composite_module, "calculate_positions", fake_positions)
    result = calculate_progressed_composite(_request(point_set=point_set), [])
    expected_ids = ["SUN", "CHIRON", "TRUE_NODE", "SOUTH_TRUE_NODE", "AST:433"]
    assert [row["body_id"] for row in result["radix_composite_planets"]] == expected_ids
    assert [row["body_id"] for row in result["progressed_composite_planets"]] == expected_ids
    assert result["meta"]["effective_point_set"]["resolved_body_ids"] == expected_ids


def test_effective_point_set_removes_unavailable_asteroid_and_dedupes_warnings(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    point_set = {
        "body_ids": ["SUN"],
        "include_nodes": False,
        "custom_asteroids": [999999],
        "angle_ids": [],
        "house_cusps": [],
        "lot_ids": [],
    }

    def sun_only_positions(
        _jd: float,
        specs: list[Any],
        warnings: list[str],
        *,
        sidereal: bool = False,
    ) -> list[dict[str, Any]]:
        del sidereal
        warnings.append("synthetic missing asteroid")
        return [
            {"body_id": spec.body_id, "name": spec.name, "longitude": 10.0}
            for spec in specs
            if spec.body_id == "SUN"
        ]

    monkeypatch.setattr(
        progressed_composite_module,
        "calculate_positions",
        sun_only_positions,
    )
    result = calculate_progressed_composite(_request(point_set=point_set), [])
    effective = result["meta"]["effective_point_set"]

    assert effective["body_ids"] == ["SUN"]
    assert effective["resolved_body_ids"] == ["SUN"]
    assert effective["custom_asteroids"] == []
    assert result["warnings"].count("synthetic missing asteroid") == 1


def test_nested_point_set_node_mode_overrides_top_level_fallback() -> None:
    point_set = {
        "body_ids": ["SUN"],
        "include_nodes": True,
        "node_mode": "mean_node",
        "custom_asteroids": [],
        "angle_ids": [],
        "house_cusps": [],
        "lot_ids": [],
    }
    request = _request(point_set=point_set)
    request["node_mode"] = "true_node"

    result = calculate_progressed_composite(request, [])

    assert result["meta"]["effective_point_set"]["node_mode"] == "mean_node"
    assert result["meta"]["effective_point_set"]["resolved_body_ids"] == [
        "SUN",
        "MEAN_NODE",
        "SOUTH_MEAN_NODE",
    ]


def test_radix_section_failure_does_not_suppress_progressed_section(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls = 0

    def fail_radix_positions(
        jd: float,
        specs: list[Any],
        warnings: list[str],
        *,
        sidereal: bool = False,
    ) -> list[dict[str, Any]]:
        nonlocal calls
        calls += 1
        if calls == 1:
            raise RuntimeError("injected radix failure")
        return real_calculate_positions(jd, specs, warnings, sidereal=sidereal)

    monkeypatch.setattr(
        progressed_composite_module,
        "calculate_positions",
        fail_radix_positions,
    )
    result = calculate_progressed_composite(_request(), [])

    assert result["radix_composite_planets"] == []
    assert result["progressed_composite_planets"]
    assert result["section_errors"]["radix_composite_planets"] == "injected radix failure"


def test_aspect_section_failure_does_not_suppress_position_sections(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def fail_aspects(*_args: Any, **_kwargs: Any) -> list[dict[str, Any]]:
        raise RuntimeError("injected aspect failure")

    monkeypatch.setattr(progressed_composite_module, "find_aspects", fail_aspects)
    result = calculate_progressed_composite(_request(), [])

    assert result["radix_composite_planets"]
    assert result["progressed_composite_planets"]
    assert result["progressed_to_radix_aspects"] == []
    assert result["section_errors"]["progressed_to_radix_aspects"] == "injected aspect failure"


def test_real_sample_request() -> None:
    sample_path = Path(__file__).parents[1] / "Examples" / "sample-progressed-composite-request.json"
    request = json.loads(sample_path.read_text(encoding="utf-8"))
    result = calculate_progressed_composite(request, [])

    assert result["meta"]["method"] == "progress_each_person_then_midpoint"
    assert result["radix_composite_planets"]
    assert result["progressed_composite_planets"]
    assert result["section_errors"] is None
