from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

import pytest

import astro_backend_horary
from astro_backend_api import _closest_primary_directions, calculate_classical, validate_required_fields
from astro_backend_circumambulations import calculate_circumambulations
from astro_backend_classical import calculate_antiscia
from astro_backend_classical_dignity import (
    joy_status,
    motion_label,
    triplicity_ruler_details,
    triplicity_set,
)
from astro_backend_classical_lots import calculate_lots
from astro_backend_classical_medieval import profection_solar_return_synthesis
from astro_backend_core import completed_age, moment_to_local_datetime, parse_targets
from astro_backend_horary import make_aspect_event


def test_house_references_in_lots_use_actual_cusps(sample_planet_positions) -> None:
    cusps = [100.0, 128.0, 155.0, 184.0, 214.0, 244.0, 274.0, 310.0, 338.0, 8.0, 38.0, 68.0]
    positions = {key: dict(value) for key, value in sample_planet_positions.items()}
    positions["MOON"]["longitude"] = 135.0

    rows = calculate_lots({"ASC": 100.0}, positions, cusps, is_day=True, mc=8.0)
    death = next(row for row in rows if row["id"] == "death")

    assert death["longitude"] == 275.0


def test_contra_antiscia_reflects_across_aries_libra_axis() -> None:
    rows = calculate_antiscia(
        [{"id": "SUN", "name": "太阳", "longitude": 10.0}],
        {"MOON": {"longitude": 350.0}},
        0.1,
    )

    assert rows[0]["contra_longitude"] == 350.0
    assert rows[0]["natal_hits"] == [
        {"id": "SUN|contra|MOON", "hit_planet": "月亮", "via": "contra-antiscia", "orb": 0.0}
    ]


def test_moon_joy_is_third_house_not_eleventh() -> None:
    assert joy_status("MOON", 3)[0] == "喜乐"
    assert joy_status("MOON", 11)[0] == ""


def test_slow_saturn_is_not_stationary_until_near_zero_speed() -> None:
    assert motion_label("SATURN", 0.033)[0] == "顺行"
    assert motion_label("SATURN", 0.0005)[0] == "停滞"


def test_ptolemaic_water_triplicity_has_mars_as_day_and_night_ruler() -> None:
    assert triplicity_set(3, "ptolemaic") == ("MARS", "MARS", "")
    details = triplicity_ruler_details(
        3,
        "ptolemaic",
        {"MARS": {"longitude": 5.0, "house": 1, "speed": 0.5}},
    )
    assert [row["ruler_id"] for row in details] == ["MARS", "MARS"]
    assert all(row["ruler_id"] for row in details)


def test_horary_aspect_event_recomputes_exact_longitudes_and_houses(monkeypatch) -> None:
    exact_positions = {"MOON": (276.0, 13.0), "MERCURY": (36.0, 1.2)}

    def fake_body_longitude_at(_dt, spec, _warnings, _warning_keys, sidereal=False):
        return exact_positions[spec.body_id]

    monkeypatch.setattr(astro_backend_horary, "body_longitude_at", fake_body_longitude_at)
    event = make_aspect_event(
        datetime(2026, 7, 10, 12, 0),
        {"id": "MOON", "name": "月亮", "longitude": 250.0, "house": 8},
        {"id": "MERCURY", "name": "水星", "longitude": 10.0, "house": 1},
        "trine",
        [],
        set(),
        [float(index * 30) for index in range(12)],
    )

    assert event["moon_longitude"] == 276.0
    assert event["target_longitude"] == 36.0
    assert event["moon_house"] == 10
    assert event["target_house"] == 2


def test_completed_age_handles_february_29_anniversary_consistently() -> None:
    birth = datetime(2000, 2, 29, 12, 0)
    assert completed_age(birth, datetime(2023, 2, 28, 11, 59)) == 22
    assert completed_age(birth, datetime(2023, 2, 28, 12, 0)) == 23


def test_circumambulation_resets_bound_start_at_each_sign() -> None:
    result = calculate_circumambulations(
        25.0,
        datetime(2000, 1, 1),
        "egyptian",
        max_age=20,
    )
    taurus = next(row for row in result["boundaries"] if row["sign"] == "金牛")
    assert taurus["start_degree"] == 0
    assert taurus["start_degree"] < taurus["end_degree"]


def test_solar_return_synthesis_uses_actual_mc_and_ruler_houses() -> None:
    result = profection_solar_return_synthesis(
        {"profected_asc_longitude": 10.0, "lordId": "MARS", "lord": "火星"},
        {
            "angles": [{"id": "ASC", "longitude": 10.0}, {"id": "MC", "longitude": 100.0}],
            "planets": [
                {"id": "MARS", "name": "火星", "house": 8, "sign": "天蝎", "score": 7},
                {"id": "MOON", "name": "月亮", "house": 4, "sign": "巨蟹", "score": 7},
            ],
        },
        10.0,
        [],
        True,
    )

    assert result["sr_highlights"]["asc_ruler"] == "火星"
    assert result["sr_highlights"]["asc_ruler_house"] == 8
    assert result["sr_highlights"]["mc_ruler"] == "月亮"
    assert result["sr_highlights"]["mc_ruler_house"] == 4


def test_primary_direction_summary_chooses_rows_nearest_reference_age() -> None:
    rows = [
        {"age_from_abs_arc": 2.0},
        {"age_from_abs_arc": 40.2},
        {"age_from_abs_arc": 39.8},
        {"age_from_abs_arc": 80.0},
    ]
    nearest = [row["age_from_abs_arc"] for row in _closest_primary_directions(rows, 40.0)]
    assert set(nearest[:2]) == {39.8, 40.2}
    assert nearest[2] == 2.0


def test_classical_metadata_reports_actual_house_and_ayanamsha_labels() -> None:
    sample_path = Path(__file__).resolve().parents[1] / "Examples" / "sample-classical-request.json"
    request = json.loads(sample_path.read_text(encoding="utf-8"))
    request["birth"]["houseSystem"] = "placidus"
    request["birth"]["zodiac"] = "sidereal_raman"

    result = calculate_classical(request, [])

    assert result["meta"]["zodiac"] == "Raman Sidereal"
    assert result["meta"]["house_system_note"] == "宫头与角点均为 Swiss Ephemeris 实际计算值"


def test_four_valid_targets_may_intentionally_share_one_sign() -> None:
    targets = parse_targets("\n".join([
        "Point A = Aries 1°",
        "Point B = Aries 7°",
        "Point C = Aries 14°",
        "Point D = Aries 28°",
    ]))
    assert [target.longitude for target in targets] == [1.0, 7.0, 14.0, 28.0]


def test_unknown_backend_mode_is_rejected_explicitly() -> None:
    error = validate_required_fields({"mode": "momnet", "natal": {}, "transit": {}})
    assert error == {"error": "不支持的 mode：momnet", "mode": "momnet"}


def test_iana_timezone_rejects_dst_gap_and_requires_fold_for_overlap() -> None:
    base = {"year": 2024, "month": 3, "day": 10, "hour": 2, "minute": 30, "timezone": "America/New_York"}
    with pytest.raises(ValueError, match="本地时间不存在"):
        moment_to_local_datetime(base)

    overlap = {**base, "month": 11, "day": 3, "hour": 1}
    with pytest.raises(ValueError, match="fold=0"):
        moment_to_local_datetime(overlap)
    first = moment_to_local_datetime({**overlap, "fold": 0})
    second = moment_to_local_datetime({**overlap, "fold": 1})
    assert first.utcoffset() != second.utcoffset()


def test_fixed_offset_timezone_preserves_quarter_hour_precision() -> None:
    moment = moment_to_local_datetime({
        "year": 2026, "month": 7, "day": 10, "hour": 12, "minute": 0,
        "timezone": "GMT+5:45",
    })
    assert moment.utcoffset().total_seconds() == 20_700
