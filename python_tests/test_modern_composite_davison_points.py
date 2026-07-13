from __future__ import annotations

from typing import Any

import pytest

from astro_backend_composite import calculate_composite
from astro_backend_core import (
    circular_midpoint,
    geographic_longitude_midpoint,
    jd_from_datetime,
    moment_to_jd,
    moment_to_local_datetime,
)
from astro_backend_davison import calculate_davison
from astro_backend_ephemeris import build_houses


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
DEFAULT_BODY_IDS = [
    "SUN",
    "MOON",
    "MERCURY",
    "VENUS",
    "MARS",
    "JUPITER",
    "SATURN",
    "URANUS",
    "NEPTUNE",
    "PLUTO",
]


def _request(
    mode: str,
    *,
    house_system: str = "whole_sign",
    node_mode: str = "true_node",
    point_set: dict[str, Any] | None = None,
) -> dict[str, Any]:
    request: dict[str, Any] = {
        "mode": mode,
        "person_a": PERSON_A,
        "person_b": PERSON_B,
        "house_system": house_system,
        "zodiac": "tropical",
        "node_mode": node_mode,
        "aspects": [],
    }
    if point_set is not None:
        request["point_set"] = point_set
    return request


@pytest.mark.parametrize(
    ("mode", "node_mode", "node_ids"),
    [
        ("composite", "true_node", ["TRUE_NODE", "SOUTH_TRUE_NODE"]),
        ("composite", "mean_node", ["MEAN_NODE", "SOUTH_MEAN_NODE"]),
        ("davison", "true_node", ["TRUE_NODE", "SOUTH_TRUE_NODE"]),
        ("davison", "mean_node", ["MEAN_NODE", "SOUTH_MEAN_NODE"]),
    ],
)
def test_omitted_point_set_preserves_default_planets_and_shape(
    mode: str,
    node_mode: str,
    node_ids: list[str],
) -> None:
    calculator = calculate_composite if mode == "composite" else calculate_davison
    warnings: list[str] = []

    result = calculator(_request(mode, node_mode=node_mode), warnings)

    assert set(result) == {
        "meta",
        "angles",
        "houses",
        "planets",
        "aspects",
        "patterns",
        "warnings",
        "section_errors",
    }
    expected_ids = DEFAULT_BODY_IDS + node_ids
    assert [row["body_id"] for row in result["planets"]] == expected_ids
    assert [row["id"] for row in result["angles"]] == ["ASC", "MC", "DSC", "IC"]
    assert set(result["angles"][0]) == {
        "id",
        "name",
        "longitude",
        "sign",
        "degree_text",
        "house",
        "ruler",
        "formula",
        "formula_day",
        "formula_night",
        "used_formula",
    }
    expected_planet_fields = (
        {
            "body_id",
            "name",
            "longitude",
            "latitude",
            "speed",
            "sign",
            "degree_text",
            "house",
        }
        if mode == "composite"
        else {
            "body_id",
            "name",
            "longitude",
            "latitude",
            "declination",
            "out_of_bounds",
            "speed",
            "sign",
            "degree_text",
            "_ephemeris",
            "house",
        }
    )
    assert set(result["planets"][0]) == expected_planet_fields
    assert result["meta"]["method"] in {
        "composite_midpoint",
        "davison_midtime_midspace",
    }
    assert result["meta"]["effective_point_set"]["resolved_body_ids"] == expected_ids


def _fake_position_row(spec: Any, longitude: float) -> dict[str, Any]:
    return {
        "body_id": spec.body_id,
        "name": spec.name,
        "longitude": longitude,
        "latitude": 0.0,
        "declination": 0.0,
        "out_of_bounds": False,
        "speed": 1.0,
        "sign": "",
        "degree_text": "",
        "_ephemeris": "test ephemeris",
    }


def test_chiron_and_custom_asteroid_follow_existing_position_paths(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import astro_backend_composite as composite_module
    import astro_backend_davison as davison_module

    composite_calls = {"count": 0}

    def fake_composite_positions(
        jd: float,
        specs: list[Any],
        warnings: list[str],
        *,
        sidereal: bool = False,
    ) -> list[dict[str, Any]]:
        del jd, warnings, sidereal
        offset = composite_calls["count"]
        composite_calls["count"] += 1
        longitudes = {
            "CHIRON": [20.0, 40.0][offset],
            "AST:433": [350.0, 10.0][offset],
        }
        return [_fake_position_row(spec, longitudes[spec.body_id]) for spec in specs]

    seen_davison_ids: list[str] = []

    def fake_davison_positions(
        jd: float,
        specs: list[Any],
        warnings: list[str],
        *,
        sidereal: bool = False,
    ) -> list[dict[str, Any]]:
        del jd, warnings, sidereal
        seen_davison_ids.extend(spec.body_id for spec in specs)
        return [
            _fake_position_row(
                spec,
                {"CHIRON": 123.0, "AST:433": 124.0}[spec.body_id],
            )
            for spec in specs
        ]

    monkeypatch.setattr(composite_module, "calculate_positions", fake_composite_positions)
    monkeypatch.setattr(davison_module, "calculate_positions", fake_davison_positions)

    point_set = {
        "body_ids": ["CHIRON"],
        "include_nodes": False,
        "custom_asteroids": [433],
        "angle_ids": [],
    }
    composite_result = calculate_composite(_request("composite", point_set=point_set), [])
    davison_result = calculate_davison(_request("davison", point_set=point_set), [])

    assert [row["body_id"] for row in composite_result["planets"]] == ["CHIRON", "AST:433"]
    assert composite_result["planets"][0]["longitude"] == pytest.approx(30.0)
    assert composite_result["planets"][1]["longitude"] == pytest.approx(0.0)
    assert seen_davison_ids == ["CHIRON", "AST:433"]
    assert [row["body_id"] for row in davison_result["planets"]] == ["CHIRON", "AST:433"]
    assert davison_result["planets"][1]["name"] == "小行星 433"
    assert composite_result["meta"]["effective_point_set"]["resolved_body_ids"] == [
        "CHIRON",
        "AST:433",
    ]


@pytest.mark.parametrize("mode", ["composite", "davison"])
def test_requested_vertex_and_east_point_use_build_houses_angles(mode: str) -> None:
    point_set = {
        "body_ids": ["SUN"],
        "include_nodes": False,
        "angle_ids": ["VERTEX", "EQUATORIAL_ASCENDANT"],
    }
    calculator = calculate_composite if mode == "composite" else calculate_davison
    result = calculator(_request(mode, point_set=point_set), [])
    angle_map = {row["id"]: row["longitude"] for row in result["angles"]}

    assert list(angle_map) == ["VERTEX", "EQUATORIAL_ASCENDANT"]
    assert result["meta"]["effective_point_set"]["angle_ids"] == [
        "VERTEX",
        "EQUATORIAL_ASCENDANT",
    ]

    if mode == "composite":
        a_jd, _ = moment_to_jd(PERSON_A["moment"])
        b_jd, _ = moment_to_jd(PERSON_B["moment"])
        _, a_angles, _ = build_houses(
            a_jd,
            PERSON_A["latitude"],
            PERSON_A["longitude"],
            "whole_sign",
            False,
            [],
        )
        _, b_angles, _ = build_houses(
            b_jd,
            PERSON_B["latitude"],
            PERSON_B["longitude"],
            "whole_sign",
            False,
            [],
        )
        expected = {
            angle_id: circular_midpoint(a_angles[angle_id], b_angles[angle_id])
            for angle_id in angle_map
        }
    else:
        a_dt = moment_to_local_datetime(PERSON_A["moment"])
        b_dt = moment_to_local_datetime(PERSON_B["moment"])
        mid_dt = a_dt + (b_dt - a_dt) / 2
        mid_jd = jd_from_datetime(mid_dt)
        _, expected_angles, _ = build_houses(
            mid_jd,
            (PERSON_A["latitude"] + PERSON_B["latitude"]) / 2.0,
            geographic_longitude_midpoint(
                PERSON_A["longitude"],
                PERSON_B["longitude"],
            ),
            "whole_sign",
            False,
            [],
        )
        expected = {angle_id: expected_angles[angle_id] for angle_id in angle_map}

    for angle_id, longitude in expected.items():
        assert angle_map[angle_id] == pytest.approx(longitude, abs=1e-9)


@pytest.mark.parametrize("mode", ["composite", "davison"])
def test_unavailable_requested_axes_are_not_fabricated(
    mode: str,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import astro_backend_composite as composite_module
    import astro_backend_davison as davison_module

    def houses_without_optional_axes(*args: Any, **kwargs: Any) -> tuple[list[float], dict[str, float], str]:
        del args, kwargs
        return (
            [float(index * 30) for index in range(12)],
            {"ASC": 0.0, "MC": 90.0, "DSC": 180.0, "IC": 270.0},
            "Whole Sign",
        )

    module = composite_module if mode == "composite" else davison_module
    monkeypatch.setattr(module, "build_houses", houses_without_optional_axes)
    calculator = calculate_composite if mode == "composite" else calculate_davison
    result = calculator(
        _request(
            mode,
            point_set={
                "body_ids": ["SUN"],
                "include_nodes": False,
                "angle_ids": ["VERTEX", "EQUATORIAL_ASCENDANT"],
            },
        ),
        [],
    )

    assert result["angles"] == []
    assert result["meta"]["effective_point_set"]["angle_ids"] == []


@pytest.mark.parametrize("mode", ["composite", "davison"])
def test_non_whole_sign_house_path_remains_intact(mode: str) -> None:
    calculator = calculate_composite if mode == "composite" else calculate_davison
    warnings: list[str] = []

    result = calculator(_request(mode, house_system="placidus"), warnings)

    assert len(result["houses"]) == 12
    assert len({round(row["cusp_longitude"], 8) for row in result["houses"]}) > 1
    assert not any("too many values to unpack" in warning for warning in warnings)
