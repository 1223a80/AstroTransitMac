from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

import pytest


def sample_request() -> dict[str, Any]:
    return {
        "mode": "horary",
        "chart": {
            "moment": {
                "year": 2026,
                "month": 5,
                "day": 5,
                "hour": 15,
                "minute": 30,
                "timezone": "Asia/Shanghai",
            },
            "latitude": 31.2304,
            "longitude": 121.4737,
            "houseSystem": "regiomontanus",
            "zodiac": "tropical",
            "boundsSystem": "egyptian",
            "triplicitySystem": "dorothean",
        },
        "questionText": "我最近能找到新工作吗？",
        "placeName": "上海",
        "aspectOrb": 3.5,
    }


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("year", True),
        ("month", 13),
        ("hour", 24),
        ("minute", 60),
        ("timezone", "Mars/Olympus"),
    ],
)
def test_horary_moment_values_are_validated(field: str, value: Any) -> None:
    from astro_backend_api import validate_required_fields

    request = sample_request()
    request["chart"]["moment"][field] = value

    error = validate_required_fields(request)

    assert error is not None
    assert any("chart.moment" in item for item in error["invalid"])


def test_horary_dst_gap_is_reported_by_validation() -> None:
    from astro_backend_api import validate_required_fields

    request = sample_request()
    request["chart"]["moment"] = {
        "year": 2024,
        "month": 3,
        "day": 10,
        "hour": 2,
        "minute": 30,
        "timezone": "America/New_York",
    }

    error = validate_required_fields(request)

    assert error is not None
    assert any("本地时间不存在" in item for item in error["invalid"])


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("houseSystem", "invented_houses"),
        ("zodiac", "invented_zodiac"),
        ("boundsSystem", "invented_bounds"),
        ("triplicitySystem", "invented_triplicity"),
    ],
)
def test_horary_option_ids_are_validated(field: str, value: str) -> None:
    from astro_backend_api import validate_required_fields

    request = sample_request()
    request["chart"][field] = value

    error = validate_required_fields(request)

    assert error is not None
    assert any(f"chart.{field}" in item for item in error["invalid"])


@pytest.mark.requires_ephemeris
def test_unknown_matter_emits_visible_warning() -> None:
    from astro_backend_horary import calculate_horary

    request = sample_request()
    request["questionText"] = "xxx"

    result = calculate_horary(request, [])

    assert any("Matter" in warning and "未评估" in warning for warning in result["warnings"])


def _event(exact: datetime | None, applying: str = "入相") -> dict[str, Any]:
    return {
        "applying": applying,
        "exact": exact,
        "exact_time": exact.strftime("%Y-%m-%d %H:%M") if exact else None,
    }


def test_translation_chooses_earliest_applying_event() -> None:
    from astro_backend_horary import _detect_translation

    chart_dt = datetime(2026, 1, 1)
    candidates = [
        {"role": "Querent", "planet_id": "MARS"},
        {"role": "Matter / Outcome", "planet_id": "VENUS"},
        {"role": "Moon", "planet_id": "MOON"},
    ]
    planets = [
        {"id": "MARS", "name": "火星", "speed": 0.5},
        {"id": "VENUS", "name": "金星", "speed": 0.8},
        {"id": "MOON", "name": "月亮", "speed": 13.0},
        {"id": "MERCURY", "name": "水星", "speed": 1.2},
    ]
    facts = {
        ("MARS", "MOON"): _event(None, "离相"),
        ("MOON", "VENUS"): _event(chart_dt + timedelta(days=8)),
        ("MARS", "MERCURY"): _event(None, "离相"),
        ("MERCURY", "VENUS"): _event(chart_dt + timedelta(days=3)),
    }

    result = _detect_translation(
        candidates, [], {"voc": False}, planets, chart_dt, [], 8.0, False, facts,
    )

    assert result["translator"] == "水星"
    assert result["exact_time"] == "2026-01-04 00:00"


def test_collection_chooses_earliest_completion() -> None:
    from astro_backend_horary import _detect_collection

    chart_dt = datetime(2026, 1, 1)
    candidates = [
        {"role": "Querent", "planet_id": "MARS"},
        {"role": "Matter / Outcome", "planet_id": "VENUS"},
    ]
    planets = [
        {"id": "MARS", "name": "火星", "speed": 1.0},
        {"id": "VENUS", "name": "金星", "speed": 0.8},
        {"id": "SATURN", "name": "土星", "speed": 0.03},
        {"id": "JUPITER", "name": "木星", "speed": 0.05},
    ]
    facts = {
        ("MARS", "VENUS"): _event(chart_dt + timedelta(days=10)),
        ("MARS", "SATURN"): _event(chart_dt + timedelta(days=5)),
        ("SATURN", "VENUS"): _event(chart_dt + timedelta(days=8)),
        ("JUPITER", "MARS"): _event(chart_dt + timedelta(days=3)),
        ("JUPITER", "VENUS"): _event(chart_dt + timedelta(days=4)),
    }

    result = _detect_collection(
        candidates, [], planets, chart_dt, [], 8.0, False, facts,
    )

    assert result["collector"] == "木星"
    assert result["exact_time"] == "2026-01-05 00:00"


def test_prohibition_chooses_first_intervening_event() -> None:
    from astro_backend_horary import _detect_prohibition

    chart_dt = datetime(2026, 1, 1)
    candidates = [
        {"role": "Querent", "planet_id": "MARS"},
        {"role": "Matter / Outcome", "planet_id": "VENUS"},
    ]
    planets = [
        {"id": "MARS", "name": "火星", "speed": 1.0},
        {"id": "VENUS", "name": "金星", "speed": 0.8},
        {"id": "SATURN", "name": "土星", "speed": 0.03},
        {"id": "JUPITER", "name": "木星", "speed": 0.05},
    ]
    facts = {
        ("MARS", "VENUS"): _event(chart_dt + timedelta(days=10)),
        ("MARS", "SATURN"): _event(chart_dt + timedelta(days=8)),
        ("JUPITER", "MARS"): _event(chart_dt + timedelta(days=3)),
    }

    result = _detect_prohibition(
        candidates, [], [], {"voc": False}, planets, chart_dt, [], 8.0, False, facts,
    )

    assert result["prohibitor"] == "木星"
    assert result["exact_time"] == "2026-01-04 00:00"


def test_frustration_chooses_first_intervening_event() -> None:
    from astro_backend_horary import _detect_frustration

    chart_dt = datetime(2026, 1, 1)
    candidates = [
        {"role": "Querent", "planet_id": "MARS"},
        {"role": "Matter / Outcome", "planet_id": "JUPITER"},
    ]
    planets = [
        {"id": "MARS", "name": "火星", "speed": 1.0},
        {"id": "JUPITER", "name": "木星", "speed": 0.1},
        {"id": "SATURN", "name": "土星", "speed": 0.03},
        {"id": "MERCURY", "name": "水星", "speed": 0.05},
    ]
    facts = {
        ("JUPITER", "MARS"): _event(chart_dt + timedelta(days=10)),
        ("JUPITER", "SATURN"): _event(chart_dt + timedelta(days=8)),
        ("JUPITER", "MERCURY"): _event(chart_dt + timedelta(days=3)),
    }

    result = _detect_frustration(
        candidates, [], [], {"voc": False}, planets, chart_dt, [], 8.0, False, facts,
    )

    assert result["frustrating_planet"] == "水星"
    assert result["exact_time"] == "2026-01-04 00:00"


def test_advanced_dedup_keeps_distinct_same_minute_events(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import astro_backend_horary as horary

    chart_dt = datetime(2026, 1, 1, 12, 0)
    common = {
        "status": "detected",
        "planets": ["火星", "金星", "土星"],
        "exact_time": "2026-01-01 12:00",
        "_event_exact": chart_dt,
    }

    monkeypatch.setattr(horary, "build_advanced_aspect_events", lambda *args: {})
    monkeypatch.setattr(
        horary,
        "_detect_translation",
        lambda *args: {
            "id": "translation",
            "type": "Translation of Light",
            "status": "not detected",
            "details": "",
            "planets": [],
            "exact_time": None,
        },
    )
    monkeypatch.setattr(
        horary,
        "_detect_collection",
        lambda *args: {
            "id": "collection",
            "type": "Collection of Light",
            "status": "not detected",
            "details": "",
            "planets": [],
            "exact_time": None,
        },
    )
    monkeypatch.setattr(
        horary,
        "_detect_prohibition",
        lambda *args: {
            **common,
            "id": "prohibition",
            "type": "Prohibition",
            "details": "",
            "prohibitor": "土星",
            "_event_key": ("MARS", "SATURN"),
        },
    )
    monkeypatch.setattr(
        horary,
        "_detect_frustration",
        lambda *args: {
            **common,
            "id": "frustration",
            "type": "Frustration",
            "details": "",
            "frustrating_planet": "土星",
            "_event_key": ("SATURN", "VENUS"),
        },
    )

    result = horary.advanced_candidates(
        [], [], [], {"voc": False}, [], chart_dt, [], 8.0,
    )

    prohibition = next(row for row in result if row["id"] == "prohibition")
    frustration = next(row for row in result if row["id"] == "frustration")
    assert prohibition["status"] == "detected"
    assert frustration["status"] == "detected"
    assert all(not key.startswith("_") for row in result for key in row)
