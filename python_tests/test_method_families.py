from __future__ import annotations

import json
import math
import subprocess
import sys
from pathlib import Path

import pytest

from astro_backend_api import validate_required_fields
from astro_backend_method_families import calculate_method_families

ROOT = Path(__file__).resolve().parents[1]
TRANSIT_CALC = ROOT / "Sources" / "TransitStudio" / "Resources" / "backend" / "transit_calc.py"


def _req():
    return json.loads((ROOT / "Examples/sample-method-families-request.json").read_text())


def _custom_arc(result: dict) -> float:
    row = next(item for item in result["solar_arc_profiles"] if item["profile_id"] == "solar_arc_custom_key")
    return float(row["arc_deg"])


def _run_transit_calc(request: dict) -> dict:
    completed = subprocess.run(
        [sys.executable, str(TRANSIT_CALC)],
        input=json.dumps(request, allow_nan=True),
        text=True,
        capture_output=True,
        check=True,
        cwd=ROOT,
    )
    return json.loads(completed.stdout)


def test_api_accepts():
    assert validate_required_fields(_req()) is None


def test_calculate_defining_facts():
    r = calculate_method_families(_req(), [])
    assert r["meta"]["mode"] == "method_families"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)

    prog = {p["profile_id"]: p for p in r["progression_profiles"]}
    # Formal ARMC-rebuild profiles
    assert "secondary_armc_naibod" in prog
    assert "secondary_mc_from_true_solar_arc" in prog
    # Experimental proxy renamed
    assert "armc_361_ecliptic_proxy_experimental" in prog
    assert prog["armc_361_ecliptic_proxy_experimental"].get("experimental") is True

    for pid in ("secondary_armc_naibod", "secondary_mc_from_true_solar_arc", "armc_361_ecliptic_proxy_experimental"):
        pack = prog[pid]
        assert pack["rows"], f"{pid} must emit rows"
        bodies = {row["body_id"] for row in pack["rows"]}
        assert "ASC" in bodies and "MC" in bodies

    def _mc_lon(pid: str) -> float:
        row = next(x for x in prog[pid]["rows"] if x["body_id"] == "MC")
        return float(row["progressed_longitude"])

    def _asc_lon(pid: str) -> float:
        row = next(x for x in prog[pid]["rows"] if x["body_id"] == "ASC")
        return float(row["progressed_longitude"])

    mc_naibod = _mc_lon("secondary_armc_naibod")
    mc_sa = _mc_lon("secondary_mc_from_true_solar_arc")
    mc_armc = _mc_lon("armc_361_ecliptic_proxy_experimental")
    # All three angle methods must pairwise diverge for nonzero age sample.
    assert abs(mc_naibod - mc_sa) > 1e-6
    assert abs(mc_naibod - mc_armc) > 1e-6
    assert abs(mc_sa - mc_armc) > 1e-6

    age = float(r["meta"]["age_years"])
    assert age > 0

    # Full ARMC Naibod: ASC–MC separation need not equal natal (geometry changes with latitude).
    assert prog["secondary_armc_naibod"].get("asc_mc_separation_changed") is True or abs(
        _asc_lon("secondary_armc_naibod") - mc_naibod
    ) != abs(
        float(next(x for x in prog["secondary_armc_naibod"]["rows"] if x["body_id"] == "ASC")["natal_longitude"])
        - float(next(x for x in prog["secondary_armc_naibod"]["rows"] if x["body_id"] == "MC")["natal_longitude"])
    )

    # Experimental proxy: MC = natal + (361/365.2422)*age
    natal_mc = next(x for x in prog["armc_361_ecliptic_proxy_experimental"]["rows"] if x["body_id"] == "MC")
    natal = float(natal_mc["natal_longitude"])
    expected_armc = (natal + age * (361.0 / 365.2422)) % 360.0
    assert abs(((mc_armc - expected_armc + 180) % 360) - 180) < 1e-5

    armc_desc = prog["armc_361_ecliptic_proxy_experimental"]["description"].lower()
    assert "proxy" in armc_desc or "experimental" in armc_desc

    solar = {p["profile_id"]: p for p in r["solar_arc_profiles"]}
    assert "solar_arc_true_sun" in solar or "true_sun" in solar
    assert "solar_arc_naibod_mean" in solar or "naibod_mean" in solar
    # Legacy aliases retained
    assert "true_sun" in solar
    arcs = {pid: float(pack["arc_deg"]) for pid, pack in solar.items()}
    t = arcs.get("solar_arc_true_sun", arcs.get("true_sun"))
    n = arcs.get("solar_arc_naibod_mean", arcs.get("naibod_mean"))
    c = arcs.get("solar_arc_custom_key", arcs.get("custom_rate"))
    assert abs(t - n) > 1e-9 or abs(n - c) > 1e-9
    assert r["profile_arc_comparison"]


def test_missing_options_keep_existing_defaults():
    request = _req()
    result = calculate_method_families(request, [])

    assert "solar_arc_rate_deg_per_year" not in request
    assert math.isclose(_custom_arc(result), float(result["meta"]["age_years"]), abs_tol=1e-5)
    assert "include_experimental_profiles" not in request
    assert result["requested_config"]["include_experimental_profiles"] is True
    assert "armc_361_ecliptic_proxy_experimental" in result["effective_config"]["progression_experimental"]


def test_zero_solar_arc_rate_is_not_replaced_by_one():
    request = _req()
    request["solar_arc_rate_deg_per_year"] = 0.0

    result = calculate_method_families(request, [])

    assert _custom_arc(result) == 0.0


@pytest.mark.parametrize("include_experimental", [True, False])
def test_experimental_profiles_follow_json_boolean(include_experimental: bool):
    request = _req()
    request["include_experimental_profiles"] = include_experimental

    result = calculate_method_families(request, [])

    profiles = result["effective_config"]["progression_experimental"]
    assert ("armc_361_ecliptic_proxy_experimental" in profiles) is include_experimental
    assert result["requested_config"]["include_experimental_profiles"] is include_experimental


@pytest.mark.parametrize(
    "rate",
    [True, False, math.nan, math.inf, -math.inf, "0", "not-a-number", None],
)
def test_api_rejects_invalid_solar_arc_rate(rate):
    request = _req()
    request["solar_arc_rate_deg_per_year"] = rate

    error = validate_required_fields(request)

    assert error is not None
    assert error["mode"] == "method_families"
    assert "solar_arc_rate_deg_per_year must be a finite number" in error["invalid"]


@pytest.mark.parametrize("include_experimental", ["false", "true", 0, 1, None])
def test_api_rejects_non_boolean_experimental_profile_option(include_experimental):
    request = _req()
    request["include_experimental_profiles"] = include_experimental

    error = validate_required_fields(request)

    assert error is not None
    assert error["mode"] == "method_families"
    assert "include_experimental_profiles must be a boolean" in error["invalid"]


def test_transit_calc_returns_structured_errors_for_invalid_options():
    request = _req()
    request["solar_arc_rate_deg_per_year"] = "0"
    request["include_experimental_profiles"] = "false"

    response = _run_transit_calc(request)

    assert response["mode"] == "method_families"
    assert isinstance(response["error"], str)
    assert response["invalid"] == [
        "solar_arc_rate_deg_per_year must be a finite number",
        "include_experimental_profiles must be a boolean",
    ]


def test_armc_naibod_not_ecliptic_plus_same_arc():
    """Formal Naibod must rebuild houses — ASC delta ≠ MC delta in general."""
    r = calculate_method_families(_req(), [])
    pack = next(p for p in r["progression_profiles"] if p["profile_id"] == "secondary_armc_naibod")
    asc = next(x for x in pack["rows"] if x["body_id"] == "ASC")
    mc = next(x for x in pack["rows"] if x["body_id"] == "MC")
    asc_delta = abs(((float(asc["progressed_longitude"]) - float(asc["natal_longitude"]) + 180) % 360) - 180)
    mc_delta = abs(((float(mc["progressed_longitude"]) - float(mc["natal_longitude"]) + 180) % 360) - 180)
    # If they were simple +same arc, deltas would match within floating error.
    assert abs(asc_delta - mc_delta) > 1e-4 or pack.get("asc_mc_separation_changed") is True
