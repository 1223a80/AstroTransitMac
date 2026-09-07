"""Focused tests for mode=planetary_synodic (B10)."""

from __future__ import annotations

from astro_backend_api import validate_required_fields
from astro_backend_planetary_synodic import calculate_planetary_synodic


def _request() -> dict:
    return {
        "mode": "planetary_synodic",
        "start": {
            "year": 2024,
            "month": 1,
            "day": 1,
            "hour": 0,
            "minute": 0,
            "timezone": "Asia/Shanghai",
        },
        "end": {
            "year": 2025,
            "month": 12,
            "day": 31,
            "hour": 0,
            "minute": 0,
            "timezone": "Asia/Shanghai",
        },
        "display_timezone": "Asia/Shanghai",
        "pair": {"body_a": "MARS", "body_b": "JUPITER"},
        "phases": [
            {"id": "conjunction", "name": "合相", "angle": 0.0},
            {"id": "opposition", "name": "冲相", "angle": 180.0},
            {"id": "square", "name": "刑相", "angle": 90.0},
        ],
        "birth": {
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
        "target_point_set": {
            "body_ids": ["SUN", "MOON", "MARS"],
            "include_nodes": False,
            "node_mode": "true_node",
            "custom_asteroids": [],
            "angle_ids": [],
            "house_cusps": [],
            "lot_ids": [],
        },
        "contact_aspects": [
            {"id": "conjunction", "name": "合相", "angle": 0.0, "orb": 2.0},
        ],
        "zodiac": "tropical",
    }


def test_api_requires_pair() -> None:
    assert validate_required_fields(_request()) is None
    bad = _request()
    del bad["pair"]
    assert validate_required_fields(bad) is not None


def test_phase_events_refined() -> None:
    result = calculate_planetary_synodic(_request(), [])
    assert result["meta"]["method"] == "planetary_synodic_v1"
    assert result["events"]
    phases = {e["phase_id"] for e in result["events"]}
    assert "conjunction" in phases or "opposition" in phases
    for event in result["events"][:8]:
        assert event["exact_orb"] < 1e-3
        assert event["exact_utc"].endswith("Z")
        assert "+08:00" in event["exact_local"]
        assert "relative_speed" in event
        assert event["pass_index_in_window"] >= 1
    assert result["calculation_assumptions"]
    assert result["requested_config"]
    assert result["effective_config"]


def test_cycles_between_conjunctions() -> None:
    result = calculate_planetary_synodic(_request(), [])
    conjunctions = [e for e in result["events"] if e["phase_id"] == "conjunction"]
    if len(conjunctions) >= 2:
        assert result["cycles"]
        cycle = result["cycles"][0]
        assert cycle["start_utc"]
        assert cycle["end_utc"] is None or cycle["start_utc"] < cycle["end_utc"]


def test_natal_contacts_optional() -> None:
    result = calculate_planetary_synodic(_request(), [])
    # contacts may be empty depending on orbs; field must exist when birth given
    assert all("natal_contacts" in e for e in result["events"])


def test_emptyish_window() -> None:
    req = _request()
    req["end"] = {
        "year": 2024,
        "month": 1,
        "day": 5,
        "hour": 0,
        "minute": 0,
        "timezone": "Asia/Shanghai",
    }
    req["pair"] = {"body_a": "URANUS", "body_b": "NEPTUNE"}
    result = calculate_planetary_synodic(req, [])
    assert isinstance(result["events"], list)
    assert result["meta"]["event_count"] == len(result["events"])


def test_moon_saturn_fast_slow_pair_finds_all_conjunctions() -> None:
    # 60-day window: Moon orbits ~2.2 times, so there should be at least 2 Moon-Saturn conjunctions
    req = _request()
    req["pair"] = {"body_a": "MOON", "body_b": "SATURN"}
    req["phases"] = [{"id": "conjunction", "name": "合相", "angle": 0.0}]
    req["start"] = {"year": 2024, "month": 1, "day": 1, "hour": 0, "minute": 0, "timezone": "Asia/Shanghai"}
    req["end"] = {"year": 2024, "month": 3, "day": 1, "hour": 0, "minute": 0, "timezone": "Asia/Shanghai"}
    result = calculate_planetary_synodic(req, [])
    conjunctions = [e for e in result["events"] if e["phase_id"] == "conjunction"]
    assert len(conjunctions) >= 2


def test_synodic_step_selection_uses_faster_body(monkeypatch) -> None:
    import astro_backend_planetary_synodic as synodic_mod
    from astro_backend_modern_timing import _step_for
    step_moon = _step_for("transit", "MOON", [])
    step_saturn = _step_for("transit", "SATURN", [])
    assert step_moon < step_saturn

    # Direct production helper test
    production_step = synodic_mod._synodic_search_step("MOON", "SATURN", [])
    assert production_step == step_moon
    assert production_step < step_saturn

    # Verify that calculate_planetary_synodic actually passes the fast step to _find_roots
    captured_steps = []
    original_find_roots = synodic_mod._find_roots

    def spy_find_roots(func, start, end, step):
        captured_steps.append(step)
        return original_find_roots(func, start, end, step)

    monkeypatch.setattr(synodic_mod, "_find_roots", spy_find_roots)

    req = _request()
    req["pair"] = {"body_a": "MOON", "body_b": "SATURN"}
    req["phases"] = [{"id": "conjunction", "name": "合相", "angle": 0.0}]
    req["start"] = {"year": 2024, "month": 1, "day": 1, "hour": 0, "minute": 0, "timezone": "Asia/Shanghai"}
    req["end"] = {"year": 2024, "month": 1, "day": 5, "hour": 0, "minute": 0, "timezone": "Asia/Shanghai"}
    synodic_mod.calculate_planetary_synodic(req, [])

    assert len(captured_steps) > 0
    for s in captured_steps:
        assert s == step_moon
        assert s < step_saturn
