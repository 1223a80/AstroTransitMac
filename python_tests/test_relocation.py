"""Focused tests for mode=relocation invariants."""

from __future__ import annotations

import copy
import math

import pytest

from astro_backend_api import validate_required_fields
from astro_backend_relocation import METHOD, calculate_relocation


def _base_request(**overrides):
    request = {
        "mode": "relocation",
        "birth": {
            "name": "Shanghai birth",
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
        "relocation": {
            "name": "London",
            "latitude": 51.5074,
            "longitude": -0.1278,
            "timezone": "Europe/London",
        },
        "house_system": "placidus",
        "zodiac": "tropical",
        "node_mode": "true_node",
        "point_set": {
            "body_ids": ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"],
            "include_nodes": False,
            "custom_asteroids": [],
            "angle_ids": ["ASC", "MC", "DSC", "IC"],
            "house_cusps": [],
            "lot_ids": [],
        },
        "aspects": [],
    }
    request.update(overrides)
    return request


def test_shared_planet_longitudes_and_method():
    warnings: list[str] = []
    result = calculate_relocation(_base_request(), warnings)
    assert result["meta"]["method"] == METHOD
    natal = {row["body_id"]: row["longitude"] for row in result["natal_chart"]["planets"]}
    relocated = {row["body_id"]: row["longitude"] for row in result["relocated_chart"]["planets"]}
    assert set(natal) == set(relocated)
    for body_id, lon in natal.items():
        assert abs(lon - relocated[body_id]) < 1e-9


def test_birth_jd_stable_when_relocation_timezone_changes():
    warnings: list[str] = []
    a = calculate_relocation(_base_request(), warnings)
    request_b = _base_request()
    request_b["relocation"]["timezone"] = "America/New_York"
    b = calculate_relocation(request_b, [])
    assert a["meta"]["birth_jd"] == b["meta"]["birth_jd"]
    assert a["meta"]["birth_utc"] == b["meta"]["birth_utc"]
    natal_a = {row["body_id"]: row["longitude"] for row in a["natal_chart"]["planets"]}
    natal_b = {row["body_id"]: row["longitude"] for row in b["natal_chart"]["planets"]}
    for body_id in natal_a:
        assert abs(natal_a[body_id] - natal_b[body_id]) < 1e-9


def test_same_place_house_assignment_stable():
    request = _base_request()
    request["relocation"] = {
        "name": "Same as birth",
        "latitude": 31.2304,
        "longitude": 121.4737,
        "timezone": "Asia/Shanghai",
    }
    result = calculate_relocation(request, [])
    for row in result["planet_house_changes"]:
        assert row["natal_house"] == row["relocated_house"]
        assert row["changed"] is False


def test_antimeridian_changes_houses_not_planets():
    request = _base_request()
    request["relocation"] = {
        "name": "Near antimeridian",
        "latitude": 0.0,
        "longitude": 179.5,
        "timezone": "Pacific/Kiritimati",
    }
    result = calculate_relocation(request, [])
    natal = {row["body_id"]: row["longitude"] for row in result["natal_chart"]["planets"]}
    relocated = {row["body_id"]: row["longitude"] for row in result["relocated_chart"]["planets"]}
    for body_id, lon in natal.items():
        assert abs(lon - relocated[body_id]) < 1e-9
    # Angles should differ from birth place for a far relocation.
    natal_asc = next(a for a in result["natal_chart"]["angles"] if a["id"] == "ASC")
    reloc_asc = next(a for a in result["relocated_chart"]["angles"] if a["id"] == "ASC")
    assert abs(natal_asc["longitude"] - reloc_asc["longitude"]) > 1.0


def test_house_change_rows_recomputable():
    result = calculate_relocation(_base_request(), [])
    natal_houses = {row["body_id"]: row["house"] for row in result["natal_chart"]["planets"]}
    reloc_houses = {row["body_id"]: row["house"] for row in result["relocated_chart"]["planets"]}
    for row in result["planet_house_changes"]:
        assert row["natal_house"] == natal_houses[row["body_id"]]
        assert row["relocated_house"] == reloc_houses[row["body_id"]]
        assert row["changed"] == (row["natal_house"] != row["relocated_house"])


def test_point_set_reduction_shrinks_planets():
    full = calculate_relocation(_base_request(), [])
    reduced_req = _base_request()
    reduced_req["point_set"] = {
        "body_ids": ["SUN", "MOON"],
        "include_nodes": False,
        "custom_asteroids": [],
        "angle_ids": ["ASC", "MC"],
        "house_cusps": [],
        "lot_ids": [],
    }
    reduced = calculate_relocation(reduced_req, [])
    assert len(reduced["natal_chart"]["planets"]) < len(full["natal_chart"]["planets"])
    assert {p["body_id"] for p in reduced["natal_chart"]["planets"]} == {"SUN", "MOON"}
    assert {a["id"] for a in reduced["relocated_chart"]["angles"]} <= {"ASC", "MC"}


def test_high_latitude_fallback_is_auditable():
    request = _base_request()
    request["house_system"] = "placidus"
    request["relocation"] = {
        "name": "Alert",
        "latitude": 82.5,
        "longitude": -62.3,
        "timezone": "America/Toronto",
    }
    warnings: list[str] = []
    result = calculate_relocation(request, warnings)
    # Either Placidus succeeds or effective method is exposed — never silent.
    assert result["meta"]["house_system_requested"] == "placidus"
    effective = result["meta"]["house_system_effective_relocated"]
    assert effective in {"placidus", "whole_sign"}
    if effective == "whole_sign":
        assert any("Whole Sign" in w or "relocated" in w.lower() for w in result["warnings"] + warnings)


def test_validation_requires_relocation_fields():
    err = validate_required_fields({"mode": "relocation", "birth": {"latitude": 1, "longitude": 2}})
    assert err is not None
    assert "relocation" in str(err).lower() or "missing" in str(err).lower()


def test_relocation_local_accepts_gmt_offset_label():
    """Relocation display timezone should accept Swift-style GMT±N, not only IANA."""
    request = _base_request()
    request["relocation"]["timezone"] = "GMT+0"
    result = calculate_relocation(request, [])
    # Birth 1990-01-01 12:00 Asia/Shanghai = 04:00 UTC; GMT+0 local is 04:00.
    assert "04:00" in result["meta"]["relocation_local"] or result["meta"]["relocation_local"].startswith(
        "1990-01-01T04:00"
    )
    assert "+00:00" in result["meta"]["relocation_local"] or result["meta"]["relocation_local"].endswith("Z")
