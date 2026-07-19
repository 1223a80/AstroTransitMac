from __future__ import annotations

import pytest

from astro_backend_api import validate_required_fields
from astro_backend_mundane_electional import calculate_mundane_electional


def _req():
    import json
    from pathlib import Path

    return json.loads(Path("Examples/sample-mundane-electional-request.json").read_text())


def test_api_accepts():
    assert validate_required_fields(_req()) is None


def test_calculate_defining_facts():
    r = calculate_mundane_electional(_req(), [])
    assert r["meta"]["mode"] == "mundane_electional"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)

    ingresses = r["mundane_ingresses"]
    candidates = r["electional_candidates"]
    assert isinstance(ingresses, list)
    assert isinstance(candidates, list)
    assert len(ingresses) + len(candidates) >= 1
    for ing in ingresses[:4]:
        assert ing.get("ingress") in {"aries", "cancer", "libra", "capricorn"}
        assert ing.get("exact_utc")
        assert ing.get("method_key") == "sun_sign_ingress_bisection"
    for c in candidates[:3]:
        assert "evidence" in c or "planets" in c or "planetary_hour" in c or "moon_longitude" in c
        assert "rank" not in c
        assert "lucky_score" not in c


def test_rejects_empty_location_and_invalid_timezone():
    base = _req()
    with pytest.raises(ValueError, match="latitude|longitude"):
        calculate_mundane_electional({**base, "location": {}}, [])
    with pytest.raises(ValueError, match="latitude|longitude"):
        calculate_mundane_electional({**base, "location": {"name": "x"}}, [])
    bad_tz = {
        **base,
        "display_timezone": "Not/ARealZone",
        "location": {
            "latitude": 31.2,
            "longitude": 121.4,
            "timezone": "Not/ARealZone",
        },
    }
    with pytest.raises(ValueError, match="时区|timezone|未知"):
        calculate_mundane_electional(bad_tz, [])


def test_rejects_non_positive_scan_step_hours():
    base = _req()
    err = validate_required_fields({**base, "scan_step_hours": -1})
    assert err is not None
    assert "scan_step_hours" in str(err)
    with pytest.raises(ValueError, match="scan_step_hours"):
        calculate_mundane_electional({**base, "scan_step_hours": -1}, [])
    with pytest.raises(ValueError, match="scan_step_hours"):
        calculate_mundane_electional({**base, "scan_step_hours": 0}, [])


def test_api_rejects_string_body_ids_and_missing_birth_moment_for_method_families():
    bad_body = {
        "mode": "method_families",
        "birth": {
            "moment": {
                "year": 1990,
                "month": 1,
                "day": 1,
                "hour": 12,
                "minute": 0,
                "timezone": "Asia/Shanghai",
            },
            "latitude": 31.2,
            "longitude": 121.4,
        },
        "reference": {
            "year": 2026,
            "month": 1,
            "day": 1,
            "hour": 12,
            "minute": 0,
            "timezone": "Asia/Shanghai",
        },
        "body_ids": "SUN",
    }
    err = validate_required_fields(bad_body)
    assert err is not None
    assert "body_ids" in str(err)

    missing_moment = {
        "mode": "method_families",
        "birth": {"latitude": 31.2, "longitude": 121.4},
        "reference": bad_body["reference"],
    }
    err2 = validate_required_fields(missing_moment)
    assert err2 is not None
    assert "birth.moment" in str(err2)