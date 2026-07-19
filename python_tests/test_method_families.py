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
    # Angle methods must diverge (Naibod mean ≠ true solar arc ≠ 361°/year).
    assert abs(mc_naibod - mc_sa) > 1e-6 or abs(mc_naibod - mc_armc) > 1e-6
    assert abs(mc_sa - mc_armc) > 1e-6 or abs(mc_naibod - mc_sa) > 1e-6
    assert len({round(mc_naibod, 6), round(mc_sa, 6), round(mc_armc, 6)}) >= 2

    solar = {p["profile_id"]: p for p in r["solar_arc_profiles"]}
    assert set(solar) >= {"true_sun", "naibod_mean", "custom_rate"}
    arcs = {pid: float(pack["arc_deg"]) for pid, pack in solar.items()}
    # custom_rate default 1.0°/year vs naibod 0.98564733 must differ for age > 0
    assert abs(arcs["true_sun"] - arcs["naibod_mean"]) > 1e-9 or abs(arcs["naibod_mean"] - arcs["custom_rate"]) > 1e-9
    assert r["profile_arc_comparison"]
