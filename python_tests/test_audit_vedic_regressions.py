from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

import pytest

from astro_backend_core import angular_separation, norm360, swe
from astro_backend_ephemeris import house_for_longitude
from astro_backend_jyotish import _calc_vimsottari_dasa, calculate_vedic
from astro_backend_jyotish_aux_points import calc_upagrahas
from astro_backend_jyotish_divisional import build_bhava_chart, build_moon_chart
from astro_backend_jyotish_relationships import calc_temporary_friendship
from astro_backend_jyotish_shadbala import calc_naisargika_bala
from astro_backend_jyotish_yoga import (
    yoga_bhadra,
    yoga_hans,
    yoga_malavya,
    yoga_rucaka,
    yoga_shasha,
)


pytestmark = [pytest.mark.requires_ephemeris]
EPHE_PATH = Path(__file__).resolve().parents[1] / "Sources" / "TransitStudio" / "Resources" / "ephemeris"


def _position(longitude: float, name: str = "test") -> dict:
    return {"longitude": longitude, "name": name, "degree_text": ""}


def test_moon_chart_keeps_physical_rasi_and_counts_houses_from_moon() -> None:
    chart = build_moon_chart(
        {
            "MOON": _position(280.0, "Moon"),
            "SUN": _position(10.0, "Sun"),
            "VENUS": _position(310.0, "Venus"),
        },
        asc_longitude=250.0,
    )

    assert chart["planets"]["MOON"]["rasi"] == 9
    assert chart["planets"]["MOON"]["rasi_name"] == "摩羯"
    assert chart["planets"]["MOON"]["house"] == 1
    assert chart["planets"]["SUN"]["rasi"] == 0
    assert chart["planets"]["SUN"]["house"] == 4
    assert chart["planets"]["ASC"]["rasi"] == 8
    assert chart["planets"]["ASC"]["house"] == 12


def test_bhava_chart_uses_real_cusps_and_angles() -> None:
    cusps = [norm360(350.0 + index * 30.0) for index in range(12)]
    angles = [
        {"id": "ASC", "name": "ASC", "longitude": 350.0, "house": 1},
        {"id": "MC", "name": "MC", "longitude": 80.0, "house": 4},
        {"id": "DSC", "name": "DSC", "longitude": 170.0, "house": 7},
        {"id": "IC", "name": "IC", "longitude": 260.0, "house": 10},
    ]
    chart = build_bhava_chart(
        {"SUN": _position(10.0), "MOON": _position(45.0)},
        asc_longitude=350.0,
        cusps=cusps,
        chart_angles=angles,
    )

    assert chart["planets"]["SUN"]["house"] == house_for_longitude(10.0, cusps) == 1
    assert chart["planets"]["MOON"]["house"] == house_for_longitude(45.0, cusps) == 2
    returned_angles = {row["id"]: row["longitude"] for row in chart["angles"]}
    assert returned_angles == {"ASC": 350.0, "MC": 80.0, "DSC": 170.0, "IC": 260.0}


def test_sun_based_upagrahas_are_distinct_and_follow_reference_formulas() -> None:
    sun = 5.9666666667
    rows = calc_upagrahas(sun, asc_longitude=59.7333, jd_ut=2451545.0)
    by_id = {row["id"]: row["longitude"] for row in rows}
    ids = ["dhuma", "vyatipaata", "parivesha", "indrachaapa", "upaketu"]

    assert len({by_id[item] for item in ids}) == 5
    assert angular_separation(by_id["dhuma"], norm360(sun + 133.3333333333)) < 1e-4
    assert angular_separation(by_id["parivesha"], norm360(by_id["vyatipaata"] + 180.0)) < 1e-4
    assert angular_separation(by_id["indrachaapa"], norm360(360.0 - by_id["parivesha"])) < 1e-4
    assert angular_separation(by_id["upaketu"], norm360(sun - 30.0)) < 1e-4


@pytest.mark.parametrize(
    ("other_longitude", "expected"),
    [
        (30.0, 0),   # 2nd place: temporary friend
        (90.0, 0),   # 4th place: temporary friend
        (120.0, 2),  # 5th place: temporary enemy
        (180.0, 2),  # 7th place: temporary enemy
        (270.0, 0),  # 10th place: temporary friend
    ],
)
def test_tatkalika_uses_relative_sign_place(other_longitude: float, expected: int) -> None:
    positions = {"SUN": _position(0.0), "MOON": _position(other_longitude)}
    assert calc_temporary_friendship("SUN", "MOON", positions) == expected


def test_panch_mahapurusha_requires_own_or_exaltation_sign() -> None:
    assert yoga_hans({"JUPITER": _position(240.0)}, 8) is not None
    assert yoga_hans({"JUPITER": _position(210.0)}, 7) is None

    assert yoga_malavya({"VENUS": _position(30.0)}, 1) is not None
    assert yoga_malavya({"VENUS": _position(300.0)}, 10) is None

    assert yoga_shasha({"SATURN": _position(180.0)}, 6) is not None
    assert yoga_shasha({"SATURN": _position(0.0)}, 0) is None

    assert yoga_rucaka({"MARS": _position(0.0)}, 0) is not None
    assert yoga_rucaka({"MARS": _position(210.0)}, 7) is not None

    assert yoga_bhadra({"MERCURY": _position(60.0)}, 2) is not None
    assert yoga_bhadra({"MERCURY": _position(150.0)}, 5) is not None


def test_naisargika_bala_uses_standard_planet_mapping() -> None:
    values = calc_naisargika_bala()
    assert values == {
        "SUN": 60.0,
        "MOON": 51.43,
        "MERCURY": 25.71,
        "VENUS": 42.86,
        "MARS": 17.14,
        "JUPITER": 34.29,
        "SATURN": 8.57,
    }


def test_vimshottari_balance_never_returns_twelve_months() -> None:
    birth = datetime(2000, 1, 1, tzinfo=timezone.utc)
    result = _calc_vimsottari_dasa(0.012, birth, birth)
    balance = result["dasha_balance"]
    assert 0 <= balance["months"] <= 11


def test_western_hemisphere_solar_day_stays_on_birth_local_date() -> None:
    swe.set_ephe_path(str(EPHE_PATH))
    moment = {
        "year": 2000,
        "month": 1,
        "day": 1,
        "hour": 12,
        "minute": 0,
        "timezone": "America/Los_Angeles",
    }
    result = calculate_vedic(
        {
            "mode": "vedic",
            "birth": {
                "moment": moment,
                "latitude": 34.0522,
                "longitude": -118.2437,
                "houseSystem": "whole_sign",
                "zodiac": "sidereal_lahiri",
            },
            "reference": moment,
            "full": False,
        },
        [],
    )

    assert result["solar_day"]["sunrise_local"].startswith("2000-01-01")
    assert result["solar_day"]["sunset_local"].startswith("2000-01-01")
