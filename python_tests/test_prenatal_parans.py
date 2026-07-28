from __future__ import annotations

from copy import deepcopy
from datetime import datetime
from pathlib import Path

import pytest

from astro_backend_api import validate_required_fields
from astro_backend_core import swe
from astro_backend_prenatal_parans import calculate_prenatal_parans

EPHE_PATH = Path(__file__).resolve().parents[1] / "Sources" / "TransitStudio" / "Resources" / "ephemeris"


def _req():
    import json

    return json.loads(Path("Examples/sample-prenatal-parans-request.json").read_text())


def test_api_accepts():
    assert validate_required_fields(_req()) is None


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("paran_event_orb_seconds", 0, "paran_event_orb_seconds"),
        ("paran_event_orb_seconds", 3601, "paran_event_orb_seconds"),
        ("paran_ra_orb_deg", -1, "paran_ra_orb_deg"),
        ("include_legacy_paran_proxy", "yes", "include_legacy_paran_proxy"),
    ],
)
def test_api_rejects_invalid_paran_config(field, value, message):
    request = _req()
    request[field] = value
    error = validate_required_fields(request)
    assert error is not None
    assert any(message in item for item in error.get("invalid", []))


def test_calculate_defining_facts():
    swe.set_ephe_path(str(EPHE_PATH))
    r = calculate_prenatal_parans(_req(), [])
    assert r["meta"]["mode"] == "prenatal_parans"
    assert r["meta"]["method"] == "prenatal_parans_v2"
    assert r["meta"]["schema_version"] == 2
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)

    packet = r["prenatal_packet"]
    syz = packet["prenatal_syzygy"]
    assert syz.get("syzygy_type") in {"new_moon", "full_moon"}
    assert syz.get("exact_jd") is not None or syz.get("jd") is not None
    assert "syzygy_chart" in packet, "syzygy_chart must be built from exact_jd"
    chart = packet["syzygy_chart"]
    assert chart.get("planets")
    assert chart.get("angles")
    assert chart.get("method_key") == "syzygy_chart_from_exact_jd"

    parans = r["fixed_star_parans"]
    assert isinstance(parans, list)
    assert len(parans) >= 1, f"expected true event pairs; warnings={r.get('warnings')}"
    assert r["meta"]["paran_count"] == len(parans)
    for p in parans:
        assert p.get("planet_id")
        assert p.get("star_name")
        assert p["planet_event_type"] in {
            "rising",
            "culminating",
            "setting",
            "lower_culminating",
        }
        assert p["star_event_type"] in {
            "rising",
            "culminating",
            "setting",
            "lower_culminating",
        }
        planet_utc = datetime.fromisoformat(p["planet_event_utc"].replace("Z", "+00:00"))
        star_utc = datetime.fromisoformat(p["star_event_utc"].replace("Z", "+00:00"))
        actual_delta = abs((planet_utc - star_utc).total_seconds())
        assert abs(actual_delta - p["event_delta_seconds"]) <= 0.002
        assert 0 <= p["event_delta_seconds"] <= 240
        assert p["planet_event_local"].endswith("+08:00")
        assert p["star_event_local"].endswith("+08:00")
        assert p["method_key"] == "swiss_rise_trans_event_pair_v2"
        assert p["method_trace"]["function"] == "swe.rise_trans"
        assert p["proxy"] is False
        assert p["full_paran"] is True

    legacy = r["legacy_fixed_star_parans"]
    assert len(legacy) >= 1
    assert r["meta"]["legacy_paran_count"] == len(legacy)
    for row in legacy:
        assert row["method_key"] == "fixed_star_ra_conjunction"
        assert row["method_key_legacy"] == "fixed_star_paran_ra_proxy_v1"
        assert row["event_delta_seconds"] is None
        assert row["proxy"] is True
        assert row["full_paran"] is False

    assert r["method_trace"]["function"] == "swe.rise_trans"
    assert r["method_trace"]["local_day_start"] == "1990-01-01T00:00:00+08:00"
    assert r["method_trace"]["local_day_end"] == "1990-01-02T00:00:00+08:00"
    assert r["migration"]["legacy_output"] == "legacy_fixed_star_parans"
    assert r["polar_degradation"]["active"] is False


def test_legacy_proxy_can_be_disabled_without_changing_true_event_rows():
    swe.set_ephe_path(str(EPHE_PATH))
    request = _req()
    request["include_legacy_paran_proxy"] = False
    result = calculate_prenatal_parans(request, [])
    assert result["fixed_star_parans"]
    assert result["legacy_fixed_star_parans"] == []
    assert result["meta"]["legacy_paran_count"] == 0
    assert result["effective_config"]["legacy_proxy_output"] == "disabled"


def test_polar_location_omits_unavailable_horizon_events_without_fabrication():
    swe.set_ephe_path(str(EPHE_PATH))
    request = deepcopy(_req())
    request["birth"]["latitude"] = 89.0
    request["birth"]["longitude"] = 15.0
    request["birth"]["moment"]["timezone"] = "Europe/Oslo"
    request["paran_event_orb_seconds"] = 3600
    result = calculate_prenatal_parans(request, [])

    assert result["polar_degradation"]["active"] is True
    assert result["polar_degradation"]["affected_object_count"] > 0
    assert result["event_diagnostics"]
    assert any(
        unavailable["reason"] == "circumpolar_event_unavailable"
        for row in result["event_diagnostics"]
        for unavailable in row["unavailable_events"]
    )
    assert result["fixed_star_parans"], "available meridian-event pairs should remain usable"
    assert {
        event_type
        for row in result["fixed_star_parans"]
        for event_type in (row["planet_event_type"], row["star_event_type"])
    } <= {"culminating", "lower_culminating"}
    assert any("Polar/circumpolar degradation" in warning for warning in result["warnings"])
