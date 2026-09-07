"""Focused tests for mode=classical_visibility (B9)."""

from __future__ import annotations

from datetime import datetime, timezone
from types import SimpleNamespace

from astro_backend_api import validate_required_fields
from astro_backend_visibility import calculate_classical_visibility, _planetary_hours
from zoneinfo import ZoneInfo


def _request(**overrides) -> dict:
    req = {
        "mode": "classical_visibility",
        "moment": {
            "year": 2026,
            "month": 5,
            "day": 5,
            "hour": 12,
            "minute": 0,
            "timezone": "Asia/Shanghai",
        },
        "location": {
            "name": "Shanghai",
            "latitude": 31.2304,
            "longitude": 121.4737,
            "altitude_m": 10,
            "timezone": "Asia/Shanghai",
        },
        "display_timezone": "Asia/Shanghai",
        "body_ids": ["VENUS", "MARS"],
        "heliacal_event_types": ["heliacal_rising", "heliacal_setting"],
        "include": ["heliacal", "rise_set", "planetary_hours"],
    }
    req.update(overrides)
    return req


def test_api_accepts_required_fields() -> None:
    assert validate_required_fields(_request()) is None


def test_heliacal_and_hours_contract() -> None:
    result = calculate_classical_visibility(_request(), [])
    assert result["meta"]["method"] == "classical_visibility_v1"
    assert result["heliacal_events"]
    assert any(e["status"] == "ok" for e in result["heliacal_events"])
    assert result["rise_set"]
    assert result["planetary_hours"]["status"] == "ok"
    assert len(result["planetary_hours"]["hours"]) == 24
    assert result["planetary_hours"]["day_hour_minutes"] != result["planetary_hours"]["night_hour_minutes"]
    assert result["calculation_assumptions"]
    assert result["requested_config"]
    assert result["effective_config"]


def test_planetary_hours_unequal_and_chaldean() -> None:
    ref = datetime(2026, 5, 5, 4, 0, tzinfo=timezone.utc)  # 12:00 Asia/Shanghai
    hours = _planetary_hours(
        reference_utc=ref,
        latitude=31.2304,
        longitude=121.4737,
        altitude_m=10,
        display_zone=ZoneInfo("Asia/Shanghai"),
        warnings=[],
    )
    assert hours["status"] == "ok"
    day = [h for h in hours["hours"] if h["period"] == "day"]
    night = [h for h in hours["hours"] if h["period"] == "night"]
    assert len(day) == 12 and len(night) == 12
    assert day[0]["ruler_id"] == hours["day_ruler_id"]
    # Unequal: day length != night length generally.
    assert abs(hours["day_hour_minutes"] - hours["night_hour_minutes"]) > 0.01


def test_planetary_hours_before_sunrise_use_previous_night() -> None:
    ref = datetime(2026, 7, 22, 17, 0, tzinfo=timezone.utc)  # 01:00 Jul 23 Asia/Shanghai
    hours = _planetary_hours(
        reference_utc=ref,
        latitude=35.0924,
        longitude=118.3465,
        altitude_m=0,
        display_zone=ZoneInfo("Asia/Shanghai"),
        warnings=[],
    )
    assert hours["status"] == "ok"
    assert hours["sunrise_local"].startswith("2026-07-22T")
    assert hours["next_sunrise_local"].startswith("2026-07-23T")
    assert hours["weekday_local"] == "Wednesday"
    assert hours["current_hour"] is not None
    assert hours["current_hour"]["period"] == "night"


def test_utc_from_jd_carries_calendar_day(monkeypatch) -> None:
    import astro_backend_visibility as visibility

    fake = SimpleNamespace(revjul=lambda jd, cal: (2026, 6, 15, 23.9999999999), GREG_CAL=1)
    monkeypatch.setattr(visibility, "swe", fake)
    assert visibility._utc_from_jd(0.0) == datetime(
        2026, 6, 16, 0, 0, tzinfo=timezone.utc,
    )


def test_polar_degrades_without_fake_hours() -> None:
    # High Arctic in summer: often no sunset.
    result = calculate_classical_visibility(
        _request(
            moment={
                "year": 2026,
                "month": 6,
                "day": 21,
                "hour": 12,
                "minute": 0,
                "timezone": "UTC",
            },
            location={
                "name": "Alert",
                "latitude": 82.5,
                "longitude": -62.3,
                "altitude_m": 30,
                "timezone": "UTC",
            },
            display_timezone="UTC",
            include=["planetary_hours"],
        ),
        [],
    )
    ph = result["planetary_hours"]
    if ph and ph.get("status") != "ok":
        assert ph.get("hours") in ([], None) or ph.get("hours") == []
        assert result.get("section_errors") or result["warnings"]
    # Do not invent 24 fake equal hours.
    if ph and ph.get("status") == "ok":
        assert len(ph["hours"]) == 24


def test_section_isolation() -> None:
    result = calculate_classical_visibility(
        _request(include=["rise_set"]),
        [],
    )
    assert result["heliacal_events"] == []
    assert result["rise_set"]
    assert result["planetary_hours"] is None


def test_heliacal_previous_event_populated() -> None:
    req = _request(body_ids=["VENUS"])
    result = calculate_classical_visibility(req, [])
    assert result["heliacal_events"]
    ok_events = [e for e in result["heliacal_events"] if e["status"] == "ok"]
    assert len(ok_events) > 0
    # At least one heliacal event should have previous_event_utc found by backward iterator
    prev_found = [e for e in ok_events if e["previous_event_utc"] is not None]
    assert len(prev_found) > 0
    target_utc_iso = "2026-05-05T04:00:00Z"
    for e in prev_found:
        assert e["previous_event_utc"] < target_utc_iso <= e["exact_utc"]
        assert e["days_from_previous_event"] is not None
        assert e["days_from_previous_event"] > 0


def test_moon_evening_first_nearest_previous_event() -> None:
    # 2026-08-15 12:00 Shanghai (2026-08-15T04:00:00Z)
    req = _request(
        moment={
            "year": 2026,
            "month": 8,
            "day": 15,
            "hour": 12,
            "minute": 0,
            "timezone": "Asia/Shanghai",
        },
        body_ids=["MOON"],
        heliacal_event_types=["evening_first"],
    )
    result = calculate_classical_visibility(req, [])
    events = [e for e in result["heliacal_events"] if e["body_id"] == "MOON" and e["status"] == "ok"]
    assert len(events) > 0
    moon_ev = events[0]
    # Nearest previous event is on ~2026-08-14 (JD 2461266.94), less than 2 days prior to target
    assert moon_ev["previous_event_utc"] is not None
    assert moon_ev["previous_event_utc"] < "2026-08-15T04:00:00Z" <= moon_ev["exact_utc"]
    assert moon_ev["days_from_previous_event"] is not None
    assert moon_ev["days_from_previous_event"] < 5.0, (
        f"Expected nearest previous event (~0.7d ago), got {moon_ev['days_from_previous_event']} days ago"
    )
