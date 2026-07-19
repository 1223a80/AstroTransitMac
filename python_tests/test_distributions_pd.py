from __future__ import annotations

from astro_backend_api import validate_required_fields
from astro_backend_distributions_pd import calculate_distributions_pd
from astro_backend_primary_directions import NAIBOD_RATE


def _req():
    import json
    from pathlib import Path

    return json.loads(Path("Examples/sample-distributions-pd-request.json").read_text())


def test_api_accepts():
    assert validate_required_fields(_req()) is None


def test_calculate_defining_facts():
    r = calculate_distributions_pd(_req(), [])
    assert r["meta"]["mode"] == "distributions_pd"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)

    distributions = r.get("distributions") or r.get("distribution_packets") or []
    assert len(distributions) >= 1
    methods = {d.get("method_key") or d.get("bounds_system") for d in distributions}
    assert any("egyptian" in str(m) for m in methods) or any(
        d.get("bounds_system") == "egyptian" for d in distributions
    )
    multi = r.get("primary_directions_by_profile") or []
    assert len(multi) >= 1
    profile_ids = {row.get("method_profile") or row.get("method_key") for row in multi}
    assert len(profile_ids) >= 2
    assert "naibod_longitude_proxy" in profile_ids


def test_pd_profiles_diverge_using_arc_signed():
    r = calculate_distributions_pd(_req(), [])
    by_id: dict[str, dict[str, dict]] = {}
    for row in r["primary_directions_by_profile"]:
        by_id.setdefault(row["id"], {})[row["method_profile"]] = row

    assert by_id, "expected directions"
    checked = 0
    for did, profs in by_id.items():
        if set(profs) < {"naibod_longitude_proxy", "ptolemy_key_proxy", "converse_naibod_proxy"}:
            continue
        n = profs["naibod_longitude_proxy"]
        p = profs["ptolemy_key_proxy"]
        c = profs["converse_naibod_proxy"]
        arc = float(n["arc_signed"])
        # Ptolemy re-ages with 1°/year vs Naibod rate
        expected_naibod_age = abs(arc) / float(NAIBOD_RATE)
        expected_ptolemy_age = abs(arc) / 1.0
        assert abs(float(n["age_from_abs_arc"]) - expected_naibod_age) < 1e-3
        assert abs(float(p["age_from_abs_arc"]) - expected_ptolemy_age) < 1e-3
        if abs(arc) > 1e-6:
            assert abs(float(n["age_from_abs_arc"]) - float(p["age_from_abs_arc"])) > 1e-6
        # Converse negates arc
        assert abs(float(c["arc_signed"]) + float(n["arc_signed"])) < 1e-6
        assert c["direction_type"] != n["direction_type"] or abs(arc) < 1e-9
        checked += 1
        if checked >= 5:
            break
    assert checked >= 1
