from __future__ import annotations

from copy import deepcopy
import math
from typing import Any

import pytest

import astro_backend_harmonic as harmonic_backend
import astro_backend_progressions as progression_backend
import astro_backend_solar_arc as solar_arc_backend
from astro_backend_core import format_longitude
from astro_backend_harmonic import calculate_harmonic
from astro_backend_progressions import _calc_lunation, calculate_progressions
from astro_backend_solar_arc import calculate_solar_arc


BIRTH = {
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

REFERENCE = {
    "year": 2026,
    "month": 6,
    "day": 2,
    "hour": 12,
    "minute": 0,
    "timezone": "Asia/Shanghai",
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
    "TRUE_NODE",
    "SOUTH_TRUE_NODE",
]


def _request(mode: str, *, point_set: dict[str, Any] | None = None) -> dict[str, Any]:
    request: dict[str, Any] = {
        "mode": mode,
        "birth": deepcopy(BIRTH),
        "house_system": "whole_sign",
        "zodiac": "tropical",
        "node_mode": "true_node",
        "aspects": [],
    }
    if mode in {"progression", "solar_arc"}:
        request["reference"] = deepcopy(REFERENCE)
    if mode == "harmonic":
        request["harmonic_order"] = 4
    if point_set is not None:
        request["point_set"] = deepcopy(point_set)
    return request


@pytest.mark.parametrize(
    ("mode", "calculate", "planet_key", "required_keys"),
    [
        pytest.param(
            "progression",
            calculate_progressions,
            "progressed_planets",
            {
                "meta",
                "natal_planets",
                "progressed_planets",
                "natal_angles",
                "progressed_angles",
                "natal_houses",
                "progressed_houses",
                "progressed_to_natal_aspects",
                "progressed_to_progressed_aspects",
                "progressed_lunation",
                "warnings",
            },
            id="progression-default",
        ),
        pytest.param(
            "solar_arc",
            calculate_solar_arc,
            "solar_arc_planets",
            {
                "meta",
                "natal_planets",
                "solar_arc_planets",
                "solar_arc_angles",
                "solar_arc_houses",
                "solar_arc_to_natal_aspects",
                "arc_value",
                "warnings",
            },
            id="solar-arc-default",
        ),
        pytest.param(
            "harmonic",
            calculate_harmonic,
            "planets",
            {
                "meta",
                "planets",
                "angles",
                "houses",
                "houses_experimental",
                "aspects",
                "warnings",
                "harmonic_order",
            },
            id="harmonic-default",
        ),
    ],
)
def test_default_smoke_keeps_legacy_points_and_fields(
    mode: str,
    calculate: Any,
    planet_key: str,
    required_keys: set[str],
) -> None:
    result = calculate(_request(mode), [])

    assert required_keys.issubset(result)
    assert [row["body_id"] for row in result[planet_key]] == DEFAULT_BODY_IDS
    assert result["meta"]["method"]
    assert result["meta"]["effective_point_set"]["resolved_body_ids"] == DEFAULT_BODY_IDS
    assert result["meta"]["effective_point_set"]["angle_ids"] == [
        "ASC", "MC", "DSC", "IC",
    ]


def _fake_positions(
    _jd: float,
    specs: list[Any],
    _warnings: list[str],
    **_kwargs: Any,
) -> list[dict[str, Any]]:
    longitudes = {
        "SUN": 10.0,
        "CHIRON": 20.0,
        "AST:433": 30.0,
        "TRUE_NODE": 40.0,
        "SOUTH_TRUE_NODE": 220.0,
        "MEAN_NODE": 41.0,
        "SOUTH_MEAN_NODE": 221.0,
    }
    rows: list[dict[str, Any]] = []
    for index, spec in enumerate(specs):
        longitude = longitudes.get(spec.body_id, 60.0 + index)
        sign, degree_text = format_longitude(longitude)
        rows.append({
            "body_id": spec.body_id,
            "name": spec.name,
            "longitude": longitude,
            "latitude": 0.0,
            "declination": 0.0,
            "out_of_bounds": False,
            "speed": 1.0,
            "sign": sign,
            "degree_text": degree_text,
            "_ephemeris": "test",
        })
    return rows


@pytest.mark.parametrize(
    ("module", "calculate", "mode", "planet_key"),
    [
        (progression_backend, calculate_progressions, "progression", "natal_planets"),
        (solar_arc_backend, calculate_solar_arc, "solar_arc", "natal_planets"),
        (harmonic_backend, calculate_harmonic, "harmonic", "planets"),
    ],
)
def test_custom_chiron_and_asteroid_use_resolved_body_set(
    monkeypatch: pytest.MonkeyPatch,
    module: Any,
    calculate: Any,
    mode: str,
    planet_key: str,
) -> None:
    monkeypatch.setattr(module, "calculate_positions", _fake_positions)
    point_set = {
        "body_ids": ["SUN", "CHIRON"],
        "include_nodes": False,
        "custom_asteroids": [433],
        "angle_ids": ["ASC"],
    }

    result = calculate(_request(mode, point_set=point_set), [])
    expected_ids = ["SUN", "CHIRON", "AST:433"]

    assert [row["body_id"] for row in result[planet_key]] == expected_ids
    if mode == "solar_arc":
        assert [row["body_id"] for row in result["solar_arc_planets"]] == expected_ids
    effective = result["meta"]["effective_point_set"]
    assert effective["body_ids"] == ["SUN", "CHIRON"]
    assert effective["include_nodes"] is False
    assert effective["custom_asteroids"] == [433]
    assert effective["resolved_body_ids"] == expected_ids
    angle_key = {
        "progression": "natal_angles",
        "solar_arc": "solar_arc_angles",
        "harmonic": "angles",
    }[mode]
    assert [row["id"] for row in result[angle_key]] == ["ASC"]


@pytest.mark.parametrize(
    ("mode", "calculate", "angle_sections"),
    [
        ("progression", calculate_progressions, ("natal_angles", "progressed_angles")),
        ("solar_arc", calculate_solar_arc, ("solar_arc_angles",)),
        ("harmonic", calculate_harmonic, ("angles",)),
    ],
)
def test_vertex_and_equatorial_ascendant_follow_build_houses(
    mode: str,
    calculate: Any,
    angle_sections: tuple[str, ...],
) -> None:
    point_set = {
        "body_ids": ["SUN"],
        "include_nodes": False,
        "angle_ids": ["VERTEX", "EQUATORIAL_ASCENDANT"],
    }
    request = _request(mode, point_set=point_set)
    request["house_system"] = "placidus"

    result = calculate(request, [])

    assert result["meta"]["effective_point_set"]["angle_ids"] == [
        "VERTEX", "EQUATORIAL_ASCENDANT",
    ]
    for section in angle_sections:
        rows = result[section]
        assert [row["id"] for row in rows] == ["VERTEX", "EQUATORIAL_ASCENDANT"]
        assert all(math.isfinite(float(row["longitude"])) for row in rows)


@pytest.mark.parametrize(
    ("sun_longitude", "moon_longitude", "phase_name", "phase_angle", "separation"),
    [
        (0.0, 90.0, "上弦月", 90.0, 90.0),
        (0.0, 270.0, "下弦月", 270.0, 90.0),
        (10.0, 235.0, "亏凸月", 225.0, 135.0),
    ],
)
def test_progressed_lunation_keeps_directed_phase_and_legacy_fields(
    sun_longitude: float,
    moon_longitude: float,
    phase_name: str,
    phase_angle: float,
    separation: float,
) -> None:
    lunation = _calc_lunation(sun_longitude, moon_longitude)

    assert set(lunation) == {"sun_moon_separation", "phase_angle", "phase_name"}
    assert lunation["phase_name"] == phase_name
    assert lunation["phase_angle"] == phase_angle
    assert lunation["sun_moon_separation"] == separation
