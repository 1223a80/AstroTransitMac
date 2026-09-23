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


def test_sample_aries_asc_uses_corrected_egyptian_bound_edge():
    result = calculate_distributions_pd(_req(), [])
    asc = next(
        row for row in result["distributions"]
        if row["significator"] == "ASC" and row["bounds_system"] == "egyptian"
    )
    assert abs(asc["significator_longitude"] - 17.616017304) < 1e-9
    assert asc["packet"]["current_ruler_id"] == "MERCURY"
    current = next(period for period in asc["packet"]["periods"] if period["current_period"])
    assert current["period_ruler_id"] == "MERCURY"
    assert current["start_degree"] == 17.616
    assert current["end_degree"] == 20


def test_pd_profiles_diverge_using_arc_signed():
    r = calculate_distributions_pd({**_req(), "include_test_pd_profiles": True}, [])
    by_id: dict[str, dict[str, dict]] = {}
    for row in r["primary_directions_by_profile"]:
        by_id.setdefault(row["id"], {})[row["method_profile"]] = row
    for row in r.get("primary_directions_test_profiles") or []:
        by_id.setdefault(row["id"], {})[row["method_profile"]] = row

    assert by_id, "expected directions"
    formal = {row.get("method_profile") for row in r["primary_directions_by_profile"]}
    assert "naibod_longitude_proxy" in formal
    assert "one_degree_per_year_proxy" in formal
    assert "ptolemy_key_proxy" not in formal
    assert "sign_reversal_test_naibod" not in formal  # test-only, not formal

    checked = 0
    for _did, profs in by_id.items():
        if "naibod_longitude_proxy" not in profs or "one_degree_per_year_proxy" not in profs:
            continue
        n = profs["naibod_longitude_proxy"]
        p = profs["one_degree_per_year_proxy"]
        arc = float(n["arc_signed"])
        expected_naibod_age = abs(arc) / float(NAIBOD_RATE)
        expected_one_deg_age = abs(arc) / 1.0
        assert abs(float(n["age_from_abs_arc"]) - expected_naibod_age) < 1e-3
        assert abs(float(p["age_from_abs_arc"]) - expected_one_deg_age) < 1e-3
        if abs(arc) > 1e-6:
            assert abs(float(n["age_from_abs_arc"]) - float(p["age_from_abs_arc"])) > 1e-6
        if "sign_reversal_test_naibod" in profs:
            c = profs["sign_reversal_test_naibod"]
            assert abs(float(c["arc_signed"]) + float(n["arc_signed"])) < 1e-6
            assert c.get("exclude_from_concordance") is True
            assert c.get("test_profile") is True
        # Event dates always after birth even for converse arcs
        assert n.get("symbolic_date_from_signed_arc") is None
        checked += 1
        if checked >= 5:
            break
    assert checked >= 1
