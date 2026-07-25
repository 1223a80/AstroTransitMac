from __future__ import annotations

from astro_backend_api import validate_required_fields
from astro_backend_method_families import calculate_method_families


def _req():
    import json
    from pathlib import Path

    return json.loads(Path("Examples/sample-method-families-request.json").read_text())


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
