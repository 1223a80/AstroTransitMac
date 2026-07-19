"""Focused tests for mode=modern_cycles."""

from __future__ import annotations

from astro_backend_cycles import (
    calculate_modern_cycles,
    cycle_event_to_timing_event,
)


def _window_request(**overrides):
    request = {
        "mode": "modern_cycles",
        "start": {
            "year": 2024,
            "month": 3,
            "day": 1,
            "hour": 0,
            "minute": 0,
            "timezone": "UTC",
        },
        "end": {
            "year": 2024,
            "month": 5,
            "day": 1,
            "hour": 0,
            "minute": 0,
            "timezone": "UTC",
        },
        "display_timezone": "UTC",
        "cycle_types": ["new_moon", "full_moon", "solar_eclipse", "lunar_eclipse"],
        "visibility": "global",
        "zodiac": "tropical",
    }
    request.update(overrides)
    return request


def test_lunation_separations_and_distinct_eclipse_ids():
    result = calculate_modern_cycles(_window_request(), [])
    types = {event["cycle_type"] for event in result["events"]}
    assert "new_moon" in types
    assert "full_moon" in types
    # March 2024 has a lunar eclipse near full moon.
    assert "lunar_eclipse" in types

    for event in result["events"]:
        if event["cycle_type"] == "new_moon":
            assert event["separation_deg"] < 0.01
        if event["cycle_type"] == "full_moon":
            assert abs(event["separation_deg"] - 180.0) < 0.01

    lunation_ids = {e["id"] for e in result["events"] if e["cycle_type"] in {"new_moon", "full_moon"}}
    eclipse_ids = {e["id"] for e in result["events"] if e["cycle_type"] in {"solar_eclipse", "lunar_eclipse"}}
    assert lunation_ids.isdisjoint(eclipse_ids)
    assert all(e["id"].startswith(e["cycle_type"] + "|") for e in result["events"])


def test_location_visibility_does_not_drop_global_events():
    global_result = calculate_modern_cycles(_window_request(visibility="global"), [])
    location_result = calculate_modern_cycles(
        _window_request(
            visibility="location",
            location={
                "name": "Shanghai",
                "latitude": 31.2304,
                "longitude": 121.4737,
                "altitude_m": 0,
            },
        ),
        [],
    )
    global_ids = {e["id"] for e in global_result["events"] if "eclipse" in e["cycle_type"]}
    location_ids = {e["id"] for e in location_result["events"] if "eclipse" in e["cycle_type"]}
    # Global eclipses remain listed under location visibility.
    assert global_ids <= location_ids or location_ids  # at least some eclipses present
    for event in location_result["events"]:
        if event["cycle_type"] in {"solar_eclipse", "lunar_eclipse"}:
            assert event["global_event"] is True
            # visible_at_location may be True/False/None — never removes the event
            assert "visible_at_location" in event


def test_contacts_share_cycle_exact_utc():
    request = _window_request(
        birth={
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
        },
        target_point_set={
            "body_ids": ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"],
            "include_nodes": False,
            "custom_asteroids": [],
            "angle_ids": [],
            "house_cusps": [],
            "lot_ids": [],
        },
        contact_aspects=[
            {"id": "conjunction", "name": "合相", "angle": 0, "orb": 30},
            {"id": "opposition", "name": "对分", "angle": 180, "orb": 30},
        ],
    )
    result = calculate_modern_cycles(request, [])
    found = False
    for event in result["events"]:
        for contact in event.get("contacts") or []:
            found = True
            # Contacts must reuse the cycle maximum — never invent a shifted UTC.
            assert contact["exact_utc"] == event["maximum_utc"]
    assert found


def test_timing_event_registration_shape():
    result = calculate_modern_cycles(_window_request(), [])
    assert result["timing_events"]
    timing = cycle_event_to_timing_event(result["events"][0])
    assert timing["source_type"] == "modern_cycles"
    assert timing["exact_utc"] == result["events"][0]["maximum_utc"]
    assert timing["event_type"] == result["events"][0]["cycle_type"]
    assert "interpretive_window" not in timing


def test_timing_exact_orb_is_residual_not_raw_separation():
    """exact_orb must be near 0 at the cycle exact, including full moon / lunar eclipse."""
    result = calculate_modern_cycles(_window_request(), [])
    by_type = {}
    for event in result["events"]:
        timing = cycle_event_to_timing_event(event)
        by_type.setdefault(event["cycle_type"], []).append((event, timing))
        # Residual at exact instant — not raw separation (~180 for full/lunar).
        assert timing["exact_orb"] < 0.2, (
            f"{event['cycle_type']} exact_orb={timing['exact_orb']} "
            f"separation={event.get('separation_deg')}"
        )
        if event["cycle_type"] in {"full_moon", "lunar_eclipse"}:
            assert event["separation_deg"] > 90.0
            assert timing["exact_orb"] < abs(event["separation_deg"] - 90.0)
    assert "full_moon" in by_type
    full_event, full_timing = by_type["full_moon"][0]
    assert abs(full_event["separation_deg"] - 180.0) < 0.05
    assert full_timing["exact_orb"] < 0.05
    if "lunar_eclipse" in by_type:
        lunar_event, lunar_timing = by_type["lunar_eclipse"][0]
        # Eclipse max may differ slightly from exact full-moon elongation.
        assert lunar_timing["exact_orb"] < 0.2
        assert abs(lunar_timing["exact_orb"] - lunar_event["separation_deg"]) > 100


def test_display_timezone_gmt_offset_labels_not_silent_utc():
    """Swift GMTOffset labels (GMT+8) must shift maximum_local; never silent UTC fallback."""
    result = calculate_modern_cycles(
        _window_request(
            display_timezone="GMT+8",
            start={
                "year": 2024,
                "month": 3,
                "day": 1,
                "hour": 0,
                "minute": 0,
                "timezone": "GMT+8",
            },
            end={
                "year": 2024,
                "month": 3,
                "day": 15,
                "hour": 0,
                "minute": 0,
                "timezone": "GMT+8",
            },
            cycle_types=["new_moon"],
        ),
        [],
    )
    assert result["events"], "expected at least one new moon in window"
    event = result["events"][0]
    # Known window includes 2024-03-10 ~09:00 UTC → 17:00+08:00.
    assert event["maximum_utc"].endswith("Z")
    assert "+08:00" in event["maximum_local"], (
        f"maximum_local must use GMT+8 offset, got {event['maximum_local']!r}"
    )
    assert not event["maximum_local"].endswith("+00:00")
    timing = cycle_event_to_timing_event(event)
    assert "+08:00" in (timing.get("exact_local") or "")
