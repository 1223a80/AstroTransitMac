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
    assert set(prog) >= {"secondary_naibod", "secondary_solar_arc_mc", "secondary_armc_361"}
    for pid, pack in prog.items():
        assert pack["rows"], f"{pid} must emit rows"
        bodies = {row["body_id"] for row in pack["rows"]}
        assert "ASC" in bodies and "MC" in bodies

    def _mc_lon(pid: str) -> float:
        row = next(x for x in prog[pid]["rows"] if x["body_id"] == "MC")
        return float(row["progressed_longitude"])

    mc_naibod = _mc_lon("secondary_naibod")
    mc_sa = _mc_lon("secondary_solar_arc_mc")
    mc_armc = _mc_lon("secondary_armc_361")
    # All three angle methods must pairwise diverge for nonzero age sample.
    assert abs(mc_naibod - mc_sa) > 1e-6
    assert abs(mc_naibod - mc_armc) > 1e-6
    assert abs(mc_sa - mc_armc) > 1e-6

    age = float(r["meta"]["age_years"])
    assert age > 0
    # Formula check: Naibod arc on MC = natal_MC + 0.98564733 * age
    natal_mc = next(x for x in prog["secondary_naibod"]["rows"] if x["body_id"] == "MC")
    natal = float(natal_mc["natal_longitude"])
    expected_naibod = (natal + 0.98564733 * age) % 360.0
    assert abs(((mc_naibod - expected_naibod + 180) % 360) - 180) < 1e-5
    expected_armc = (natal + age * (361.0 / 365.2422)) % 360.0
    assert abs(((mc_armc - expected_armc + 180) % 360) - 180) < 1e-5

    # Honest armc naming in description/assumptions
    armc_desc = prog["secondary_armc_361"]["description"].lower()
    assert "proxy" in armc_desc or "ecliptic" in armc_desc
    assert any("armc" in a.lower() or "proxy" in a.lower() for a in r["calculation_assumptions"])

    solar = {p["profile_id"]: p for p in r["solar_arc_profiles"]}
    assert set(solar) >= {"true_sun", "naibod_mean", "custom_rate"}
    arcs = {pid: float(pack["arc_deg"]) for pid, pack in solar.items()}
    assert abs(arcs["true_sun"] - arcs["naibod_mean"]) > 1e-9 or abs(arcs["naibod_mean"] - arcs["custom_rate"]) > 1e-9
    assert r["profile_arc_comparison"]
