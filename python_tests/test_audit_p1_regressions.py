from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timedelta
from pathlib import Path

import pytest

import astro_backend_api
import astro_backend_primary_directions as primary_directions
from astro_backend_api import calculate_moment
from astro_backend_core import BODY_REGISTRY, angular_separation, moment_to_local_datetime, set_zodiac_mode, swe
from astro_backend_ephemeris import body_longitude_at, house_for_longitude
from astro_backend_fixed_stars import compute_star_positions
from astro_backend_scan import scan_window
from astro_backend_solar_arc import calculate_solar_arc


pytestmark = [pytest.mark.requires_ephemeris]

EPHE_PATH = Path(__file__).resolve().parents[1] / "Sources" / "TransitStudio" / "Resources" / "ephemeris"

MOMENT = {
    "year": 1990,
    "month": 1,
    "day": 1,
    "hour": 12,
    "minute": 0,
    "timezone": "Asia/Shanghai",
}

BIRTH = {
    "moment": MOMENT,
    "latitude": 31.2304,
    "longitude": 121.4737,
    "houseSystem": "whole_sign",
    "zodiac": "tropical",
    "boundsSystem": "egyptian",
    "triplicitySystem": "dorothean",
}

ASPECTS = [
    {"id": "conjunction", "name": "合相", "angle": 0, "orb": 6},
    {"id": "opposition", "name": "冲相", "angle": 180, "orb": 6},
    {"id": "square", "name": "刑相", "angle": 90, "orb": 6},
    {"id": "trine", "name": "拱相", "angle": 120, "orb": 6},
]


def _moment_request(zodiac: str, *, same_chart: bool) -> dict:
    birth = deepcopy(BIRTH)
    birth["zodiac"] = zodiac
    return {
        "mode": "moment",
        "natal": MOMENT,
        "transit": MOMENT,
        "birth": birth,
        "natalBodies": ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"],
        "transitBodies": ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"],
        "customAsteroids": [],
        "aspects": ASPECTS,
        "sameChart": same_chart,
    }


def test_moment_sidereal_applies_to_planets_and_houses(monkeypatch: pytest.MonkeyPatch) -> None:
    swe.set_ephe_path(str(EPHE_PATH))
    monkeypatch.setattr(astro_backend_api, "compute_star_positions", lambda *args, **kwargs: [])

    tropical = calculate_moment(_moment_request("tropical", same_chart=False), [])
    sidereal = calculate_moment(_moment_request("sidereal_lahiri", same_chart=False), [])

    tropical_sun = next(row for row in tropical["natal_positions"] if row["body_id"] == "SUN")
    sidereal_sun = next(row for row in sidereal["natal_positions"] if row["body_id"] == "SUN")
    sidereal_cusps = [row["cusp_longitude"] for row in sidereal["houses"]]

    assert 20.0 < angular_separation(tropical_sun["longitude"], sidereal_sun["longitude"]) < 27.0
    assert sidereal_sun["house"] == house_for_longitude(sidereal_sun["longitude"], sidereal_cusps)


def test_same_chart_removes_self_and_mirrored_aspects(monkeypatch: pytest.MonkeyPatch) -> None:
    swe.set_ephe_path(str(EPHE_PATH))
    monkeypatch.setattr(astro_backend_api, "compute_star_positions", lambda *args, **kwargs: [])

    result = calculate_moment(_moment_request("tropical", same_chart=True), [])

    pairs = [frozenset((row["transit_body_id"], row["natal_body_id"])) for row in result["aspects"]]
    assert all(row["transit_body_id"] != row["natal_body_id"] for row in result["aspects"])
    assert len(pairs) == len(set(pairs))
    declination_signatures = [
        (row["body1"], row["body2"], row["type"]) for row in result["declination_aspects"]
    ]
    assert len(declination_signatures) == len(set(declination_signatures))
    assert result["transit_star_conjunctions"] == []


def test_scan_uses_requested_sidereal_zodiac() -> None:
    swe.set_ephe_path(str(EPHE_PATH))
    start_dt = moment_to_local_datetime(MOMENT)
    set_zodiac_mode("sidereal_lahiri")
    sidereal_sun = body_longitude_at(
        start_dt + timedelta(minutes=30),
        BODY_REGISTRY["SUN"],
        [],
        set(),
        sidereal=True,
    )
    assert sidereal_sun is not None
    target_lon, _ = sidereal_sun

    base_request = {
        "mode": "scan",
        "scanKind": "aspect",
        "label": "sidereal regression",
        "start": MOMENT,
        "end": {**MOMENT, "hour": 13},
        "transitBodies": ["SUN"],
        "customAsteroids": [],
        "aspects": [{"id": "conjunction", "name": "合相", "angle": 0, "orb": 0}],
        "targetText": f"Sidereal Sun = {target_lon:.10f}",
        "moonFilter": "include",
    }

    tropical = scan_window({**base_request, "zodiac": "tropical"}, [])
    sidereal = scan_window({**base_request, "zodiac": "sidereal_lahiri"}, [])

    assert tropical["hits"] == []
    assert len(sidereal["hits"]) == 1
    assert sidereal["hits"][0]["orb"] < 1e-6


def test_solar_arc_positions_and_angles_use_returned_houses() -> None:
    swe.set_ephe_path(str(EPHE_PATH))
    result = calculate_solar_arc(
        {
            "mode": "solar_arc",
            "birth": BIRTH,
            "reference": {
                "year": 2026,
                "month": 6,
                "day": 2,
                "hour": 12,
                "minute": 0,
                "timezone": "Asia/Shanghai",
            },
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
            "patterns_enabled": True,
        },
        [],
    )
    cusps = [row["cusp_longitude"] for row in result["solar_arc_houses"]]

    for row in result["solar_arc_planets"] + result["solar_arc_angles"]:
        assert row["house"] == house_for_longitude(row["longitude"], cusps)
    returned_ids = {row["body_id"] for row in result["solar_arc_planets"]}
    assert {"TRUE_NODE", "SOUTH_TRUE_NODE"} <= returned_ids
    assert result["patterns"]


def test_primary_directions_treats_twelfth_house_sun_as_diurnal(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    cusps = [float(value) for value in range(0, 360, 30)]
    captured: list[bool] = []

    monkeypatch.setattr(
        primary_directions,
        "build_houses",
        lambda *args, **kwargs: (cusps, {"ASC": 0.0, "MC": 270.0}, "Whole Sign"),
    )
    monkeypatch.setattr(
        primary_directions,
        "calculate_positions",
        lambda *args, **kwargs: [{"body_id": "SUN", "longitude": 350.0}],
    )

    def capture_direction(*args, **kwargs):
        captured.append(args[8])
        return None

    monkeypatch.setattr(primary_directions, "_make_direction", capture_direction)

    primary_directions.calculate_primary_directions(
        2451545.0,
        datetime(2000, 1, 1),
        0.0,
        0.0,
        "whole_sign",
        False,
        [],
    )

    assert house_for_longitude(350.0, cusps) == 12
    assert captured
    assert all(captured)


def test_fixed_star_longitudes_follow_sidereal_mode() -> None:
    swe.set_ephe_path(str(EPHE_PATH))
    star = [{
        "name": "Spica",
        "swe_name": "Spica",
        "mag": 0.98,
        "nature": "金/火星",
        "orb": 1.0,
        "keyword": "test",
    }]

    set_zodiac_mode("tropical")
    tropical = compute_star_positions(2451545.0, stars=star)
    set_zodiac_mode("sidereal_lahiri")
    sidereal = compute_star_positions(2451545.0, stars=star, sidereal=True)

    assert len(tropical) == len(sidereal) == 1
    assert 20.0 < angular_separation(tropical[0]["longitude"], sidereal[0]["longitude"]) < 27.0
    assert tropical[0]["declination"] == sidereal[0]["declination"]
