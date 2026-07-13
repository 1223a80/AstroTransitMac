from __future__ import annotations

from copy import deepcopy
from pathlib import Path
from typing import Any

import pytest

from astro_backend_core import moment_to_jd, norm360, swe
from astro_backend_ephemeris import build_houses
from astro_backend_synastry import calculate_synastry


EPHEMERIS_DIR = Path(__file__).resolve().parents[1] / "Sources" / "TransitStudio" / "Resources" / "ephemeris"


PERSON_A: dict[str, Any] = {
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

PERSON_B: dict[str, Any] = {
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


def _request(
    *,
    person_a: dict[str, Any] | None = None,
    person_b: dict[str, Any] | None = None,
    point_set: dict[str, Any] | None = None,
    aspects: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    request: dict[str, Any] = {
        "mode": "synastry",
        "person_a": deepcopy(person_a or PERSON_A),
        "person_b": deepcopy(person_b or PERSON_B),
        "house_system": "whole_sign",
        "zodiac": "tropical",
        "node_mode": "true_node",
        "aspects": aspects or [],
    }
    if point_set is not None:
        request["point_set"] = point_set
    return request


@pytest.fixture(autouse=True)
def _use_bundled_ephemeris() -> None:
    swe.set_ephe_path(str(EPHEMERIS_DIR))


def test_default_point_set_preserves_legacy_synastry_contract() -> None:
    result = calculate_synastry(_request(), [])
    expected_body_ids = [
        "SUN", "MOON", "MERCURY", "VENUS", "MARS",
        "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
        "TRUE_NODE", "SOUTH_TRUE_NODE",
    ]
    expected_angle_ids = ["ASC", "MC", "DSC", "IC"]

    assert [row["body_id"] for row in result["person_a_planets"]] == expected_body_ids
    assert [row["body_id"] for row in result["person_b_planets"]] == expected_body_ids
    assert [row["id"] for row in result["person_a_angles"]] == expected_angle_ids
    assert [row["id"] for row in result["person_b_angles"]] == expected_angle_ids
    assert result["meta"]["effective_point_set"]["resolved_body_ids"] == expected_body_ids

    for row in result["person_a_planets"] + result["person_b_planets"]:
        assert "declination" in row
        assert "out_of_bounds" in row

    for aspect in result["cross_aspects"]:
        assert aspect["transit_body_id"] in expected_body_ids
        assert aspect["natal_body_id"] in expected_body_ids
    assert "cross_declination_aspects" in result


def test_custom_point_set_applies_to_both_people_and_handles_chiron_asteroid() -> None:
    result = calculate_synastry(
        _request(
            point_set={
                "body_ids": ["SUN", "CHIRON"],
                "include_nodes": False,
                "custom_asteroids": [433],
                "angle_ids": ["ASC"],
            }
        ),
        [],
    )

    for side in ("person_a_planets", "person_b_planets"):
        ids = [row["body_id"] for row in result[side]]
        assert ids[:2] == ["SUN", "CHIRON"]
        assert not any(body_id.endswith("NODE") for body_id in ids)

    effective = result["meta"]["effective_point_set"]
    assert effective["body_ids"] == ["SUN", "CHIRON"]
    assert effective["include_nodes"] is False
    assert effective["angle_ids"] == ["ASC"]

    asteroid_rows = [
        row
        for side in ("person_a_planets", "person_b_planets")
        for row in result[side]
        if row["body_id"] == "AST:433"
    ]
    if asteroid_rows:
        assert effective["custom_asteroids"] == [433]
    else:
        assert effective["custom_asteroids"] == []
        assert any("AST:433" in warning or "小行星 433" in warning for warning in result["warnings"])


def test_requested_vertex_antivertex_and_east_point_are_only_angle_targets() -> None:
    result = calculate_synastry(
        _request(
            point_set={
                "body_ids": ["SUN"],
                "include_nodes": False,
                "angle_ids": ["VERTEX", "ANTIVERTEX", "EQUATORIAL_ASCENDANT"],
            },
            aspects=[{"id": "conjunction", "name": "合相", "angle": 0, "orb": 180}],
        ),
        [],
    )

    requested = ["VERTEX", "ANTIVERTEX", "EQUATORIAL_ASCENDANT"]
    assert [row["id"] for row in result["person_a_angles"]] == requested
    assert [row["id"] for row in result["person_b_angles"]] == requested
    assert not any(
        row["body_id"] in set(requested)
        for row in result["person_a_planets"] + result["person_b_planets"]
    )
    assert result["cross_aspects"]
    assert all(
        aspect["transit_body_id"] == "SUN"
        and aspect["natal_body_id"] == "SUN"
        for aspect in result["cross_aspects"]
    )

    warnings: list[str] = []
    person_a_jd, _ = moment_to_jd(PERSON_A["moment"])
    _, expected_angles, _ = build_houses(
        person_a_jd,
        PERSON_A["latitude"],
        PERSON_A["longitude"],
        "whole_sign",
        False,
        warnings,
    )
    result_angles = {row["id"]: row["longitude"] for row in result["person_a_angles"]}
    assert result_angles["VERTEX"] == pytest.approx(expected_angles["VERTEX"], abs=1e-9)
    assert result_angles["ANTIVERTEX"] == pytest.approx(
        norm360(expected_angles["VERTEX"] + 180.0),
        abs=1e-9,
    )
    assert result_angles["EQUATORIAL_ASCENDANT"] == pytest.approx(
        expected_angles["EQUATORIAL_ASCENDANT"],
        abs=1e-9,
    )


def test_cross_declination_aspects_disambiguate_same_body_id() -> None:
    same_person = deepcopy(PERSON_A)
    result = calculate_synastry(
        _request(
            person_a=PERSON_A,
            person_b=same_person,
            point_set={
                "body_ids": ["SUN"],
                "include_nodes": False,
                "angle_ids": ["ASC"],
            },
        ),
        [],
    )

    aspects = result["cross_declination_aspects"]
    assert len(aspects) == 1
    aspect = aspects[0]
    assert aspect["body1"] == "A_SUN"
    assert aspect["body2"] == "B_SUN"
    assert aspect["person_a_body_id"] == "SUN"
    assert aspect["person_b_body_id"] == "SUN"
    assert aspect["person_a_body_name"] != ""
    assert aspect["person_b_body_name"] != ""
